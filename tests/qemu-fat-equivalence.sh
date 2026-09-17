#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf '%s\n' "usage: $0 /path/to/linux" >&2
    exit 2
fi

repo=$(git rev-parse --show-toplevel)
linux_tree=$1
pinned=238650ef6c7c7cca08e032527329424c9fbd70e5

actual=$(git -C "$linux_tree" rev-parse HEAD)
if [ "$actual" != "$pinned" ]; then
    printf '%s\n' "refusing unreviewed Linux base" >&2
    printf '%s\n' "expected: $pinned" >&2
    printf '%s\n' "actual:   $actual" >&2
    exit 1
fi

for command in busybox cpio fsck.fat mkfs.fat qemu-system-x86_64 timeout truncate
do
    command -v "$command" >/dev/null 2>&1 || {
        printf '%s\n' "missing required command: $command" >&2
        exit 1
    }
done

sh "$repo/scripts/install-appendfat-into-linux.sh" "$linux_tree"

make -C "$linux_tree" defconfig
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable FAT_FS
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable VFAT_FS
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable MSDOS_FS
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable APPENDFAT_VFAT_FS
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable APPENDFAT_MSDOS_FS
"$linux_tree/scripts/config" --file "$linux_tree/.config" --disable FAT_KUNIT_TEST
"$linux_tree/scripts/config" --file "$linux_tree/.config" --disable APPENDFAT_KUNIT_TEST
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable BLK_DEV_INITRD
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable DEVTMPFS
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable DEVTMPFS_MOUNT
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable VIRTIO
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable VIRTIO_PCI
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable VIRTIO_BLK
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable SERIAL_8250
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable SERIAL_8250_CONSOLE
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable NLS_CODEPAGE_437
"$linux_tree/scripts/config" --file "$linux_tree/.config" --enable NLS_ISO8859_1
make -C "$linux_tree" olddefconfig

grep '^CONFIG_FAT_FS=y$' "$linux_tree/.config"
grep '^CONFIG_VFAT_FS=y$' "$linux_tree/.config"
grep '^CONFIG_MSDOS_FS=y$' "$linux_tree/.config"
grep '^CONFIG_APPENDFAT_FS=y$' "$linux_tree/.config"
grep '^CONFIG_APPENDFAT_VFAT_FS=y$' "$linux_tree/.config"
grep '^CONFIG_APPENDFAT_MSDOS_FS=y$' "$linux_tree/.config"
grep '^CONFIG_VIRTIO_BLK=y$' "$linux_tree/.config"

make -C "$linux_tree" -j2 bzImage

work=$(mktemp -d "${TMPDIR:-/tmp}/appendfat-qemu.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

fat_image=$work/fat.img
root=$work/initramfs
initramfs=$work/initramfs.cpio.gz
qemu_log=$work/qemu.log

truncate -s 64M "$fat_image"
mkfs.fat -F 32 -n APPENDFAT "$fat_image"

mkdir -p "$root/bin" "$root/proc" "$root/sys" "$root/dev" "$root/mnt"
cp "$(command -v busybox)" "$root/bin/busybox"
for applet in sh mount umount mkdir cat sync poweroff grep ls
do
    ln -s busybox "$root/bin/$applet"
done
cp "$repo/tests/qemu-fat-equivalence-init" "$root/init"
chmod +x "$root/init"

(
    cd "$root"
    find . -print0 | cpio --null -ov --format=newc | gzip -9
) > "$initramfs"

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
grep -F APPENDFAT_QEMU_EQUIVALENCE_PASS "$qemu_log"

if [ "$qemu_status" -ne 0 ] && [ "$qemu_status" -ne 124 ]; then
    printf '%s\n' "qemu exited unexpectedly: $qemu_status" >&2
    exit "$qemu_status"
fi

fsck.fat -n -v "$fat_image"
printf '%s\n' 'appendfat QEMU FAT image equivalence passed'
