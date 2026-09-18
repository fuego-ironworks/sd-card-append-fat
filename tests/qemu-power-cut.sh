#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf '%s\n' "usage: $0 /path/to/linux" >&2
    exit 2
fi

repo=$(git rev-parse --show-toplevel)
linux_tree=$1

. "$repo/tests/qemu-common.sh"

appendfat_require_commands busybox cpio fsck.fat mkfs.fat qemu-system-x86_64 timeout truncate
appendfat_prepare_linux "$repo" "$linux_tree" builtin

work=$(mktemp -d "${TMPDIR:-/tmp}/appendfat-power-cut.XXXXXX")
qemu_pid=
cleanup()
{
    if [ -n "$qemu_pid" ] && kill -0 "$qemu_pid" 2>/dev/null; then
        kill -KILL "$qemu_pid" 2>/dev/null || true
        wait "$qemu_pid" 2>/dev/null || true
    fi
    rm -rf "$work"
}
trap cleanup EXIT HUP INT TERM

fat_image=$work/fat.img
root=$work/initramfs
write_initramfs=$work/write-initramfs.cpio.gz
verify_initramfs=$work/verify-initramfs.cpio.gz
write_log=$work/write.log
verify_log=$work/verify.log
post_cut_fsck=$work/post-cut-fsck.log
recovery_fsck=$work/recovery-fsck.log

truncate -s 64M "$fat_image"
mkfs.fat -F 32 -n AFCUT "$fat_image"

make_root()
{
    rm -rf "$root"
    mkdir -p "$root/bin" "$root/proc" "$root/sys" "$root/dev" "$root/mnt"
    cp "$(command -v busybox)" "$root/bin/busybox"
    for applet in sh mount umount mkdir cat sync poweroff grep sleep
    do
        ln -s busybox "$root/bin/$applet"
    done
}

make_root
cp "$repo/tests/qemu-power-cut-write-init" "$root/init"
chmod +x "$root/init"
appendfat_make_initramfs "$root" "$write_initramfs"

qemu-system-x86_64 \
    -machine accel=tcg \
    -m 512M \
    -smp 2 \
    -nographic \
    -no-reboot \
    -kernel "$linux_tree/arch/x86/boot/bzImage" \
    -initrd "$write_initramfs" \
    -append 'console=ttyS0 rdinit=/init panic=-1' \
    -drive "file=$fat_image,format=raw,if=virtio,cache=none" \
    > "$write_log" 2>&1 &
qemu_pid=$!

cut_ready=no
cut_wait=0
while [ "$cut_wait" -lt 120 ]
do
    if grep -F APPENDFAT_QEMU_POWER_CUT_READY "$write_log" >/dev/null 2>&1; then
        cut_ready=yes
        break
    fi
    if ! kill -0 "$qemu_pid" 2>/dev/null; then
        break
    fi
    sleep 1
    cut_wait=$((cut_wait + 1))
done

cat "$write_log"

if [ "$cut_ready" != yes ]; then
    printf '%s\n' 'guest never reached the power-cut marker' >&2
    exit 1
fi

kill -KILL "$qemu_pid"
wait "$qemu_pid" 2>/dev/null || true
qemu_pid=

set +e
fsck.fat -n -v "$fat_image" > "$post_cut_fsck" 2>&1
post_cut_fsck_status=$?
set -e

cat "$post_cut_fsck"
case "$post_cut_fsck_status" in
    0|1)
        ;;
    *)
        printf '%s\n' "post-cut fsck failed unexpectedly: $post_cut_fsck_status" >&2
        exit "$post_cut_fsck_status"
        ;;
esac

grep -F 'Dirty bit is set.' "$post_cut_fsck" >/dev/null
grep -F 'Leaving filesystem unchanged.' "$post_cut_fsck" >/dev/null

make_root
cp "$repo/tests/qemu-power-cut-verify-init" "$root/init"
chmod +x "$root/init"
appendfat_make_initramfs "$root" "$verify_initramfs"

set +e
timeout 120s qemu-system-x86_64 \
    -machine accel=tcg \
    -m 512M \
    -smp 2 \
    -nographic \
    -no-reboot \
    -kernel "$linux_tree/arch/x86/boot/bzImage" \
    -initrd "$verify_initramfs" \
    -append 'console=ttyS0 rdinit=/init panic=-1' \
    -drive "file=$fat_image,format=raw,if=virtio,cache=none" \
    > "$verify_log" 2>&1
verify_status=$?
set -e

cat "$verify_log"
grep -F APPENDFAT_QEMU_POWER_CUT_VERIFY_PASS "$verify_log"

if [ "$verify_status" -ne 0 ] && [ "$verify_status" -ne 124 ]; then
    printf '%s\n' "verification qemu exited unexpectedly: $verify_status" >&2
    exit "$verify_status"
fi

# The stock-vfat recovery boot proves the synced data is readable and survives a
# clean unmount. Do not assume that mount/unmount also normalizes every
# crash-state marker left by the abrupt termination: make filesystem repair an
# explicit, separately visible recovery step, then require a clean read-only
# check.
set +e
fsck.fat -a -v "$fat_image" > "$recovery_fsck" 2>&1
recovery_fsck_status=$?
set -e

cat "$recovery_fsck"
case "$recovery_fsck_status" in
    0|1)
        ;;
    *)
        printf '%s\n' "recovery fsck failed unexpectedly: $recovery_fsck_status" >&2
        exit "$recovery_fsck_status"
        ;;
esac

fsck.fat -n -v "$fat_image"

printf '%s\n' 'appendfat synced-write abrupt-power-cut boundary passed'
