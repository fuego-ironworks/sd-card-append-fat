#!/bin/sh
set -eu

manifest=fs/appendfat/UPSTREAM.md
importer=scripts/import-linux-fat.sh

files='.kunitconfig Kconfig Makefile cache.c dir.c fat.h fat_test.c fatent.c file.c inode.c misc.c namei_msdos.c namei_vfat.c nfs.c'

for file in $files
do
    manifest_line=$(grep -F "| \`$file\` |" "$manifest")
    expected=$(printf '%s\n' "$manifest_line" | sed -n 's/.*`\([0-9a-f][0-9a-f]*\)`.*/\1/p')

    if [ -z "$expected" ]; then
        printf '%s\n' "missing manifest hash: $file" >&2
        exit 1
    fi

    if ! grep -F "copy_and_check $file $expected" "$importer" >/dev/null
    then
        printf '%s\n' "importer/manifest mismatch: $file" >&2
        exit 1
    fi
done

printf '%s\n' 'importer and manifest agree'
