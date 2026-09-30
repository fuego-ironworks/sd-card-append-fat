#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf '%s\n' "usage: $0 /path/to/linux" >&2
    exit 2
fi

repo=$(git rev-parse --show-toplevel)
linux_tree=$1

. "$repo/tests/qemu-common.sh"

appendfat_require_commands busybox cc cpio fsck.fat mkfs.fat qemu-system-x86_64 timeout truncate
appendfat_prepare_linux "$repo" "$linux_tree" builtin

work=$(mktemp -d "${TMPDIR:-/tmp}/appendfat-reserve-ahead.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

normal_image=$work/normal.img
near_full_image=$work/near-full.img
root=$work/initramfs
initramfs=$work/initramfs.cpio.gz
qemu_log=$work/qemu.log
helper=$work/appendfat-fixture

truncate -s 64M "$normal_image"
truncate -s 16M "$near_full_image"
mkfs.fat -F 32 -s 1 -n AFAHEAD "$normal_image"
mkfs.fat -F 16 -s 1 -n AFFULL "$near_full_image"

cc -O2 -static -Wall -Wextra -Werror \
    "$repo/tests/fallocate-keep-size.c" \
    -o "$helper"

mkdir -p "$root/bin" "$root/proc" "$root/sys" "$root/dev" "$root/mnt"
cp "$(command -v busybox)" "$root/bin/busybox"
for applet in sh mount umount mkdir sync poweroff rm
do
    ln -s busybox "$root/bin/$applet"
done
cp "$helper" "$root/bin/appendfat-fixture"
cp "$repo/tests/qemu-reserve-ahead-init" "$root/init"
chmod +x "$root/init" "$root/bin/appendfat-fixture"

appendfat_make_initramfs "$root" "$initramfs"

set +e
timeout 240s qemu-system-x86_64 \
    -machine accel=tcg \
    -m 512M \
    -smp 2 \
    -nographic \
    -no-reboot \
    -kernel "$linux_tree/arch/x86/boot/bzImage" \
    -initrd "$initramfs" \
    -append 'console=ttyS0 rdinit=/init panic=-1' \
    -drive "file=$normal_image,format=raw,if=virtio" \
    -drive "file=$near_full_image,format=raw,if=virtio" \
    > "$qemu_log" 2>&1
qemu_status=$?
set -e

cat "$qemu_log"
grep -F APPENDFAT_QEMU_RESERVE_AHEAD_PASS "$qemu_log"

if [ "$qemu_status" -ne 0 ] && [ "$qemu_status" -ne 124 ]; then
    printf '%s\n' "qemu exited unexpectedly: $qemu_status" >&2
    exit "$qemu_status"
fi

fsck.fat -n -v "$normal_image"
fsck.fat -n -v "$near_full_image"
printf '%s\n' 'appendfat automatic reserve-ahead fixture passed'
