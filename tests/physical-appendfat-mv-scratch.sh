#!/bin/sh
set -eu

if test -t 1; then
    cyan='\033[1;36m'
    yellow='\033[1;33m'
    green='\033[1;32m'
    red='\033[1;31m'
    reset='\033[0m'
else
    cyan=''
    yellow=''
    green=''
    red=''
    reset=''
fi

heading()
{
    printf '%b== %s ==%b\n' "$cyan" "$*" "$reset"
}

action()
{
    printf '%bACTION%b  %s\n' "$yellow" "$reset" "$*"
}

pass()
{
    printf '%bPASS%b  %s\n' "$green" "$reset" "$*"
}

fail()
{
    printf '%bFAIL%b  %s\n' "$red" "$reset" "$*" >&2
    exit 1
}

test "$#" -eq 2 || fail "usage: $0 APPENDFAT_MV_BINARY SD_ROOT"
test "${APPENDFAT_MV_PHYSICAL_SCRATCH:-}" = YES ||
    fail "set APPENDFAT_MV_PHYSICAL_SCRATCH=YES to authorize scratch-only writes"

binary=$1
requested=$2

test -x "$binary" || fail "mover is not executable: $binary"
test -d "$requested" || fail "SD_ROOT is not an existing directory: $requested"

root=$(readlink -f "$requested" 2>/dev/null || true)
test -n "$root" || fail "could not resolve SD_ROOT"
test "$root" != / || fail "refusing filesystem root"
test -d "$root" || fail "resolved SD_ROOT is not a directory"

available_kb=$(df -Pk "$root" | awk 'NR==2 {print $4}')
case "$available_kb" in
    ''|*[!0-9]*) fail "could not read available storage" ;;
esac
test "$available_kb" -gt 8192 ||
    fail "less than 8 MiB is available; refusing scratch write test"

heading "safety boundary"
printf 'sd_root=%s\n' "$root"
printf 'available_kb=%s\n' "$available_kb"
printf 'policy=no pre-existing path may be replaced or deleted\n'
printf 'policy=no recursive deletion\n'
printf 'policy=all SD writes stay inside one newly created scratch directory\n'

n=0
while :
do
    scratch="$root/.appendfat-mv-scratch-$$-$n"
    if mkdir "$scratch" 2>/dev/null; then
        break
    fi
    n=$((n + 1))
    test "$n" -lt 100 || fail "could not create a unique scratch directory"
done

token="appendfat-mv-owned-$$-$n"
marker="$scratch/.appendfat-mv-owned"
printf '%s\n' "$token" > "$marker"

source_file=$(mktemp "${TMPDIR:-$HOME}/appendfat-mv-source.XXXXXX")
stderr_file=$(mktemp "${TMPDIR:-$HOME}/appendfat-mv-stderr.XXXXXX")

cleanup()
{
    status=$?

    rm -f "$source_file" "$stderr_file"

    if test -d "$scratch" && test -f "$marker" &&
       test "$(cat "$marker" 2>/dev/null || true)" = "$token"; then
        rm -f             "$scratch/rename-source"             "$scratch/rename-destination"             "$scratch/reserved-destination"             "$marker"

        if rmdir "$scratch" 2>/dev/null; then
            :
        else
            printf '%bNOTE%b  scratch directory was not empty; left in place: %s\n'                 "$yellow" "$reset" "$scratch" >&2
        fi
    else
        printf '%bNOTE%b  ownership marker missing or changed; no SD cleanup attempted: %s\n'             "$yellow" "$reset" "$scratch" >&2
    fi

    exit "$status"
}
trap cleanup EXIT HUP INT TERM

heading "same-filesystem no-clobber"
printf 'source sentinel\n' > "$scratch/rename-source"
printf 'destination sentinel\n' > "$scratch/rename-destination"
source_hash=$(sha256sum "$scratch/rename-source" | awk '{print $1}')
destination_hash=$(sha256sum "$scratch/rename-destination" | awk '{print $1}')

action "attempt a move onto an existing scratch destination; failure is required"
if "$binary" "$scratch/rename-source" "$scratch/rename-destination" 2>"$stderr_file"; then
    fail "existing scratch destination was overwritten"
fi

test "$(sha256sum "$scratch/rename-source" | awk '{print $1}')" = "$source_hash" ||
    fail "source scratch file changed"
test "$(sha256sum "$scratch/rename-destination" | awk '{print $1}')" = "$destination_hash" ||
    fail "existing destination scratch file changed"
pass "existing destination remained byte-for-byte unchanged"

rm -f "$scratch/rename-source" "$scratch/rename-destination"

heading "reservation-before-copy"
dd if=/dev/urandom of="$source_file" bs=65536 count=16 status=none
expected_hash=$(sha256sum "$source_file" | awk '{print $1}')

action "move one 1 MiB disposable internal file into the scratch directory"
if "$binary" --force-copy "$source_file" "$scratch/reserved-destination" 2>"$stderr_file"; then
    test ! -e "$source_file" || fail "source still exists after reported success"
    test -f "$scratch/reserved-destination" || fail "destination missing after success"
    test "$(sha256sum "$scratch/reserved-destination" | awk '{print $1}')" = "$expected_hash" ||
        fail "destination hash differs from source hash"
    rm -f "$scratch/reserved-destination"
    pass "reservation-before-copy path succeeded inside isolated scratch space"
else
    test -f "$source_file" || fail "failed move removed its source"
    test "$(sha256sum "$source_file" | awk '{print $1}')" = "$expected_hash" ||
        fail "failed move changed its source"
    test ! -e "$scratch/reserved-destination" ||
        fail "failed move published a final destination"

    if grep -q 'Operation not supported' "$stderr_file"; then
        pass "Operation not supported (EOPNOTSUPP) failed closed; source stayed intact"
    else
        printf 'stderr follows:\n'
        cat "$stderr_file"
        pass "move failed closed for another reason; source stayed intact"
    fi
fi

heading "scratch ownership check"
test "$(cat "$marker")" = "$token" || fail "scratch ownership marker changed"
unexpected=$(find "$scratch" -mindepth 1 -maxdepth 1 ! -name '.appendfat-mv-owned' -print -quit)
test -z "$unexpected" ||
    fail "unexpected scratch content was left untouched for inspection: $unexpected"
pass "physical test touched only disposable files under $scratch and left no unexpected scratch content"
