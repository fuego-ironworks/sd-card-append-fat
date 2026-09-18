#!/bin/sh
set -eu

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    printf '%s\n' \
        "usage: $0 /path/to/android-kernel EXPECTED_SHA CONFIG_TARGET [ARCH]" >&2
    exit 2
fi

repo=$(git rev-parse --show-toplevel)
kernel_tree=$1
expected_sha=$2
config_target=$3
arch=${4:-arm64}

case "$expected_sha" in
    ''|HEAD|main|master)
        printf '%s\n' 'EXPECTED_SHA must be an exact commit SHA' >&2
        exit 2
        ;;
esac

actual_sha=$(git -C "$kernel_tree" rev-parse HEAD)
if [ "$actual_sha" != "$expected_sha" ]; then
    printf '%s\n' 'refusing unreviewed Android/vendor kernel base' >&2
    printf '%s\n' "expected: $expected_sha" >&2
    printf '%s\n' "actual:   $actual_sha" >&2
    exit 1
fi

for path in fs/Kconfig fs/Makefile fs/fat scripts/config
do
    if [ ! -e "$kernel_tree/$path" ]; then
        printf '%s\n' "kernel tree lacks required Kbuild path: $path" >&2
        exit 1
    fi
done

if [ -e "$kernel_tree/fs/appendfat" ]; then
    printf '%s\n' "refusing to overwrite existing $kernel_tree/fs/appendfat" >&2
    exit 1
fi

cp -a "$repo/fs/appendfat" "$kernel_tree/fs/appendfat"

if ! grep -F 'source "fs/appendfat/Kconfig"' "$kernel_tree/fs/Kconfig" >/dev/null; then
    sed -i '/source "fs\/fat\/Kconfig"/a source "fs/appendfat/Kconfig"' \
        "$kernel_tree/fs/Kconfig"
fi
if ! grep -F 'obj-$(CONFIG_APPENDFAT_FS)' "$kernel_tree/fs/Makefile" >/dev/null; then
    sed -i '/obj-$(CONFIG_FAT_FS).*fat\//a obj-$(CONFIG_APPENDFAT_FS)\t+= appendfat/' \
        "$kernel_tree/fs/Makefile"
fi

make_args="ARCH=$arch"
if [ "${LLVM:-1}" = 1 ]; then
    make_args="$make_args LLVM=1"
fi

# shellcheck disable=SC2086
make -C "$kernel_tree" $make_args "$config_target"

config="$kernel_tree/scripts/config"
"$config" --file "$kernel_tree/.config" --enable MODULES
"$config" --file "$kernel_tree/.config" --module APPENDFAT_VFAT_FS
"$config" --file "$kernel_tree/.config" --module APPENDFAT_MSDOS_FS
"$config" --file "$kernel_tree/.config" --disable APPENDFAT_KUNIT_TEST

# shellcheck disable=SC2086
make -C "$kernel_tree" $make_args olddefconfig
# shellcheck disable=SC2086
make -C "$kernel_tree" $make_args -j2 M=fs/appendfat modules

for module in appendfat_core appendfat appendmsdos
do
    if ! find "$kernel_tree/fs/appendfat" -name "$module.ko" -print -quit |
        grep . >/dev/null; then
        printf '%s\n' "missing Android/vendor compatibility module: $module.ko" >&2
        exit 1
    fi
done

origin=$(git -C "$kernel_tree" remote get-url origin 2>/dev/null || printf '%s' unknown)
printf '%s\n' "ANDROID_KERNEL_COMPAT_PASS repo=$origin sha=$actual_sha arch=$arch config=$config_target"
printf '%s\n' 'This is source/build evidence only; it is not a vendor boot or physical-device receipt.'
