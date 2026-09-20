#!/bin/sh
set -eu

if test -t 1; then
    cyan='\033[1;36m'
    green='\033[1;32m'
    red='\033[1;31m'
    reset='\033[0m'
else
    cyan=''
    green=''
    red=''
    reset=''
fi

heading()
{
    printf '%b== %s ==%b\n' "$cyan" "$*" "$reset"
}

fail()
{
    printf '%bFAIL%b  %s\n' "$red" "$reset" "$*" >&2
    exit 1
}

pass()
{
    printf '%bPASS%b  %s\n' "$green" "$reset" "$*"
}

test "$#" -eq 1 || fail "usage: $0 SD_ROOT"

requested=$1
test -d "$requested" || fail "SD_ROOT is not an existing directory: $requested"

root=$(readlink -f "$requested" 2>/dev/null || true)
test -n "$root" || fail "could not resolve SD_ROOT: $requested"
test -d "$root" || fail "resolved SD_ROOT is not a directory: $root"

heading "resolved storage path"
printf 'requested=%s\n' "$requested"
printf 'resolved=%s\n' "$root"
ls -ld "$root"

heading "filesystem capacity"
df -h "$root"
df -Pk "$root"

heading "filesystem identity"
if stat -f -c 'filesystem_type=%T block_size=%S blocks=%b free_blocks=%f available_blocks=%a' "$root" 2>/dev/null; then
    :
else
    stat "$root" || true
fi

heading "mount evidence"
mount | grep -F " $root " || mount | grep -F "$root" || true

heading "top-level inventory"
count=$(find "$root" -mindepth 1 -maxdepth 1 -print 2>/dev/null | wc -l | tr -d ' ')
printf 'top_level_entries=%s\n' "$count"

pass "preflight completed; script issued no create, write, truncate, rename, or delete operation"
