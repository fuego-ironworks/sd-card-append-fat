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
appendfat_prepare_linux "$repo" "$linux_tree" module

work=$(mktemp -d "${TMPDIR:-/tmp}/appendfat-modules.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

fat_image=$work/fat.img
root=$work/initramfs
initramfs=$work/initramfs.cpio.gz
qemu_log=$work/qemu.log

truncate -s 64M "$fat_image"
mkfs.fat -F 32 -n APPMOD "$fat_image"

mkdir -p "$root/bin" "$root/proc" "$root/sys" "$root/dev" "$root/mnt" "$root/modules"
cp "$(command -v busybox)" "$root/bin/busybox"
for applet in sh mount umount mkdir cat sync poweroff grep insmod rmmod
do
    ln -s busybox "$root/bin/$applet"
done
cp "$repo/tests/qemu-module-load-init" "$root/init"
chmod +x "$root/init"

for module in appendfat_core appendfat appendmsdos
do
    module_path=$(find "$linux_tree/fs/appendfat" -name "$module.ko" -print | head -n 1)
    if [ -z "$module_path" ]; then
        printf '%s\n' "missing built module: $module.ko" >&2
        exit 1
    fi
    cp "$module_path" "$root/modules/$module.ko"
done

appendfat_make_initramfs "$root" "$initramfs"

set +e
timeout 120s qemu-system-x86_64 \
    -machine accel=tcg \
    -m 512M \
    -smp 2 \
    -nographic \
    -no-reboot \
    -kernel "$linux_tree/arch/x86/boot/bzImage" \
    -initrd "$initramfs" \
    -append 'console=ttyS0 rdinit=/init panic=-1' \
    -drive "file=$fat_image,format=raw,if=virtio" \
    > "$qemu_log" 2>&1
qemu_status=$?
set -e

cat "$qemu_log"
grep -F APPENDFAT_QEMU_MODULE_LOAD_PASS "$qemu_log"

if [ "$qemu_status" -ne 0 ] && [ "$qemu_status" -ne 124 ]; then
    printf '%s\n' "qemu exited unexpectedly: $qemu_status" >&2
    exit "$qemu_status"
fi

fsck.fat -n -v "$fat_image"
printf '%s\n' 'appendfat QEMU load/unload/reload module acceptance passed'
