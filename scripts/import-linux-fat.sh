#!/bin/sh
set -eu

upstream=https://github.com/torvalds/linux.git
commit=238650ef6c7c7cca08e032527329424c9fbd70e5
source_path=fs/fat
destination=fs/appendfat

temporary=${TMPDIR:-/tmp}/appendfat-linux-fat.$$
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

mkdir -p "$temporary/repository" "$destination"
git -C "$temporary/repository" init -q
git -C "$temporary/repository" fetch -q --depth=1 "$upstream" "$commit"

copy_and_check()
{
    file=$1
    expected=$2

    git -C "$temporary/repository" cat-file blob "$commit:$source_path/$file" > "$destination/$file"
    actual=$(git hash-object "$destination/$file")

    if [ "$actual" != "$expected" ]; then
        printf '%s\n' "blob mismatch: $file" >&2
        printf '%s\n' "expected: $expected" >&2
        printf '%s\n' "actual:   $actual" >&2
        exit 1
    fi

    printf '%s  %s\n' "$actual" "$destination/$file"
}

copy_and_check .kunitconfig 0a6971dbeccb000be7dcd424c09a89496df57de3
copy_and_check Kconfig 25fae1c83725bc9293c26e9191690241d77b1295
copy_and_check Makefile 2b034112690d8a176b84f259a98f868028336540
copy_and_check cache.c 1b87354e24ba3a519082934ca48e277c3405d09b
copy_and_check dir.c 35bdb62944a2eb9eaa91e562a2da245929887d7f
copy_and_check fat.h 61338413d9f3e404d6dc1ca1915f706913dbb6d4
copy_and_check fat_test.c 9583ce66dca3cdc1f783577c35bbd7676cb9bf2f
copy_and_check fatent.c f0801d99dd62aefee4f573cfda332e7201235c32
copy_and_check file.c 1c835ca5f21a51a10b35522b609092c8ba873ce6
copy_and_check inode.c f775a004cae1e2f7eec2b7977c8e11ea1652dfc2
copy_and_check misc.c e79762cf19754d19096b5a8d8b2f8b7ae6a31995
copy_and_check namei_msdos.c d46d1a3851f25f75b4f9e88c2376894731e5def5
copy_and_check namei_vfat.c da3e89c0b16ac8fd076d7f70eec50c682f043812
copy_and_check nfs.c 6e1b371711edd5aacb5a81092e32361bb255e86a

printf '%s\n' "verified exact Linux FAT baseline $commit"
