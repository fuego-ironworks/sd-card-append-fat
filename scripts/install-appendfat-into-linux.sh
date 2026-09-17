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

if [ -e "$linux_tree/fs/appendfat" ]; then
    printf '%s\n' "refusing to overwrite existing $linux_tree/fs/appendfat" >&2
    exit 1
fi

cp -a "$repo/fs/appendfat" "$linux_tree/fs/appendfat"

if ! grep -F 'source "fs/appendfat/Kconfig"' "$linux_tree/fs/Kconfig" >/dev/null; then
    sed -i '/source "fs\/fat\/Kconfig"/a source "fs/appendfat/Kconfig"' "$linux_tree/fs/Kconfig"
fi

if ! grep -F 'obj-$(CONFIG_APPENDFAT_FS)' "$linux_tree/fs/Makefile" >/dev/null; then
    sed -i '/obj-$(CONFIG_FAT_FS).*fat\//a obj-$(CONFIG_APPENDFAT_FS)\t+= appendfat/' "$linux_tree/fs/Makefile"
fi

grep -F 'source "fs/appendfat/Kconfig"' "$linux_tree/fs/Kconfig" >/dev/null
grep -F 'obj-$(CONFIG_APPENDFAT_FS)' "$linux_tree/fs/Makefile" >/dev/null

printf '%s\n' "installed appendfat beside stock FAT in pinned Linux $pinned"
