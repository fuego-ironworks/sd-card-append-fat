#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

${CC:-cc} \
    -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror \
    "$root/tools/appendfat_mv.c" \
    -o "$work/appendfat_mv"

printf 'reserved copy path\n' > "$work/source"
cp "$work/source" "$work/expected"
"$work/appendfat_mv" --force-copy "$work/source" "$work/destination"
cmp "$work/expected" "$work/destination"
test ! -e "$work/source"

printf 'rename path\n' > "$work/rename-source"
before=$(stat -c '%i' "$work/rename-source")
"$work/appendfat_mv" "$work/rename-source" "$work/rename-destination"
after=$(stat -c '%i' "$work/rename-destination")
test "$before" = "$after"

mkdir "$work/directory"
printf 'directory destination\n' > "$work/directory-source"
"$work/appendfat_mv" --force-copy "$work/directory-source" "$work/directory"
printf 'directory destination\n' > "$work/directory-expected"
cmp "$work/directory-expected" "$work/directory/directory-source"

printf 'replacement\n' > "$work/replacement-source"
printf 'old destination\n' > "$work/replacement-destination"
"$work/appendfat_mv" --force-copy \
    "$work/replacement-source" "$work/replacement-destination"
printf 'replacement\n' > "$work/replacement-expected"
cmp "$work/replacement-expected" "$work/replacement-destination"
test ! -e "$work/replacement-source"

printf 'appendfat_mv host tests: PASS\n'
