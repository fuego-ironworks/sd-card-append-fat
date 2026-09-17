#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf '%s\n' "usage: $0 /path/to/prepared-linux" >&2
    exit 2
fi

repo=$(git rev-parse --show-toplevel)
linux_tree=$1
pinned=238650ef6c7c7cca08e032527329424c9fbd70e5

actual=$(git -C "$linux_tree" rev-parse HEAD)
if [ "$actual" != "$pinned" ]; then
    printf '%s\n' "refusing unreviewed Linux base" >&2
    exit 1
fi

test -x "$linux_tree/arch/x86/boot/bzImage" || {
    printf '%s\n' 'prepared bzImage missing; run qemu-fat-equivalence.sh first' >&2
    exit 1
}

for command in busybox cpio fsck.fat mkfs.fat musl-gcc qemu-system-x86_64 timeout truncate
do
    command -v "$command" >/dev/null 2>&1 || {
        printf '%s\n' "missing required command: $command" >&2
        exit 1
    }
done

work=$(mktemp -d "${TMPDIR:-/tmp}/appendfat-keep-size.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

helper=$work/fallocate_keep_size
fat_image=$work/fat.img

musl-gcc -static -O2 -Wall -Wextra -Werror \
    "$repo/tests/fallocate-keep-size.c" -o "$helper"

truncate -s 64M "$fat_image"
mkfs.fat -F 32 -n APPRESERVE "$fat_image"

build_initramfs()
{
    init_source=$1
    phase=$2
    root=$work/root-$phase
    archive=$work/initramfs-$phase.cpio.gz

    mkdir -p "$root/bin" "$root/proc" "$root/sys" "$root/dev" "$root/mnt"
    cp "$(command -v busybox)" "$root/bin/busybox"
    cp "$helper" "$root/bin/fallocate_keep_size"
    for applet in sh mount umount mkdir cat sync poweroff grep ls
    do
        ln -s busybox "$root/bin/$applet"
    done
    cp "$repo/tests/$init_source" "$root/init"
    chmod +x "$root/init"

    (
        cd "$root"
        find . -print0 | cpio --null -ov --format=newc | gzip -9
    ) > "$archive"

    printf '%s\n' "$archive"
}

run_phase()
{
    archive=$1
    sentinel=$2
    phase=$3
    qemu_log=$work/qemu-$phase.log

    set +e
    timeout 120s qemu-system-x86_64 \
        -machine accel=tcg \
        -m 512M \
        -smp 2 \
        -nographic \
        -no-reboot \
        -kernel "$linux_tree/arch/x86/boot/bzImage" \
        -initrd "$archive" \
        -append 'console=ttyS0 rdinit=/init panic=-1' \
        -drive "file=$fat_image,format=raw,if=virtio" \
        > "$qemu_log" 2>&1
    qemu_status=$?
    set -e

    cat "$qemu_log"
    grep -F "$sentinel" "$qemu_log"

    if [ "$qemu_status" -ne 0 ] && [ "$qemu_status" -ne 124 ]; then
        printf '%s\n' "qemu phase $phase exited unexpectedly: $qemu_status" >&2
        exit "$qemu_status"
    fi
}

reserve_initramfs=$(build_initramfs qemu-fallocate-reserve-init reserve)
run_phase "$reserve_initramfs" APPENDFAT_KEEP_SIZE_RESERVE_PASS reserve

echo '== fsck after unused reservations =='
fsck.fat -n -v "$fat_image"

consume_initramfs=$(build_initramfs qemu-fallocate-consume-init consume)
run_phase "$consume_initramfs" APPENDFAT_KEEP_SIZE_CONSUME_PASS consume

echo '== fsck after consuming part of the reservations =='
fsck.fat -n -v "$fat_image"

printf '%s\n' 'appendfat keep-size reservation characterization passed'
