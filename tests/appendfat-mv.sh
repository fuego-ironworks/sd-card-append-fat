#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

binary="$work/appendfat_mv"
faults="$work/appendfat-mv-faults.so"

fail()
{
    printf 'FAIL  %s\n' "$*" >&2
    exit 1
}

pass()
{
    printf 'PASS  %s\n' "$*"
}

expect_fail()
{
    if "$@"; then
        fail "command unexpectedly succeeded: $*"
    fi
}

expect_status()
{
    expected=$1
    shift
    set +e
    "$@"
    status=$?
    set -e
    test "$status" -eq "$expected" ||
        fail "expected status $expected, got $status: $*"
}

assert_no_temporary()
{
    destination=$1
    directory=$(dirname "$destination")
    base=$(basename "$destination")

    if find "$directory" -maxdepth 1 -name "$base.appendfat_mv.tmp.*" -print -quit |
       grep -q .; then
        fail "temporary destination leaked beside $destination"
    fi
}

build()
{
    ${CC:-cc} \
        -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror \
        "$root/tools/appendfat_mv.c" \
        -o "$binary"

    ${CC:-cc} \
        -std=c11 -O2 -Wall -Wextra -Werror -fPIC -shared \
        "$root/tests/appendfat-mv-faults.c" \
        -ldl \
        -o "$faults"
}

build
pass "strict build"

expect_status 2 "$binary"
expect_status 2 "$binary" --not-an-option source destination
pass "argument validation"

mkdir "$work/rename"
printf 'rename path\n' > "$work/rename/source"
cp "$work/rename/source" "$work/rename/expected"
before=$(stat -c '%d:%i' "$work/rename/source")
"$binary" "$work/rename/source" "$work/rename/destination"
after=$(stat -c '%d:%i' "$work/rename/destination")
test "$before" = "$after" || fail "same-filesystem rename changed inode"
cmp "$work/rename/expected" "$work/rename/destination"
test ! -e "$work/rename/source"
pass "same-filesystem rename fast path"

printf 'same file\n' > "$work/same-file"
"$binary" "$work/same-file" "$work/same-file"
printf 'same file\n' > "$work/same-expected"
cmp "$work/same-expected" "$work/same-file"
pass "source and destination are the same file"

mkdir "$work/no-clobber"
printf 'new source\n' > "$work/no-clobber/source"
printf 'old destination\n' > "$work/no-clobber/destination"
cp "$work/no-clobber/source" "$work/no-clobber/source-expected"
cp "$work/no-clobber/destination" "$work/no-clobber/destination-expected"
expect_fail "$binary" "$work/no-clobber/source" "$work/no-clobber/destination"
cmp "$work/no-clobber/source-expected" "$work/no-clobber/source"
cmp "$work/no-clobber/destination-expected" "$work/no-clobber/destination"
pass "same-filesystem move refuses to clobber an existing destination"

printf 'replacement source\n' > "$work/no-clobber/replace-source"
printf 'replacement old\n' > "$work/no-clobber/replace-destination"
"$binary" --replace "$work/no-clobber/replace-source" "$work/no-clobber/replace-destination"
printf 'replacement source\n' > "$work/no-clobber/replace-expected"
cmp "$work/no-clobber/replace-expected" "$work/no-clobber/replace-destination"
test ! -e "$work/no-clobber/replace-source"
pass "explicit --replace permits same-filesystem replacement"

mkdir "$work/dash"
(
    cd "$work/dash"
    printf 'dash name\n' > ./-source
    "$binary" -- ./-source ./-destination
    printf 'dash name\n' > expected
    cmp expected ./-destination
    test ! -e ./-source
)
pass "-- permits path names beginning with a dash"

mkdir "$work/sizes"
for size in 0 1 262143 262144 262145 1048593
do
    source="$work/sizes/source-$size"
    destination="$work/sizes/destination-$size"
    expected="$work/sizes/expected-$size"

    if test "$size" -eq 0; then
        : > "$source"
    else
        dd if=/dev/urandom of="$source" bs=1 count="$size" status=none
    fi
    cp "$source" "$expected"

    "$binary" --force-copy "$source" "$destination"
    cmp "$expected" "$destination"
    test ! -e "$source"
    assert_no_temporary "$destination"
done
pass "reserved copy sizes around the 256 KiB buffer boundary"

mkdir "$work/directory-target"
printf 'directory destination\n' > "$work/directory-source"
"$binary" --force-copy "$work/directory-source" "$work/directory-target"
printf 'directory destination\n' > "$work/directory-expected"
cmp "$work/directory-expected" "$work/directory-target/directory-source"
test ! -e "$work/directory-source"
pass "existing destination directory uses source basename"

printf 'metadata\n' > "$work/metadata-source"
chmod 0640 "$work/metadata-source"
touch -d '@946684800' "$work/metadata-source"
"$binary" --force-copy "$work/metadata-source" "$work/metadata-destination"
test "$(stat -c '%a' "$work/metadata-destination")" = 640 ||
    fail "destination mode was not preserved"
test "$(stat -c '%Y' "$work/metadata-destination")" = 946684800 ||
    fail "destination modification time was not preserved"
pass "mode and modification time preservation"

printf 'important target\n' > "$work/symlink-target"
ln -s "$work/symlink-target" "$work/symlink-source"
expect_fail "$binary" --force-copy "$work/symlink-source" "$work/symlink-destination"
printf 'important target\n' > "$work/symlink-expected"
cmp "$work/symlink-expected" "$work/symlink-target"
test -L "$work/symlink-source"
test ! -e "$work/symlink-destination"
pass "cross-filesystem-style path refuses a symbolic-link source"

mkdir "$work/directory-source"
expect_fail "$binary" --force-copy "$work/directory-source" "$work/directory-copy"
test -d "$work/directory-source"
test ! -e "$work/directory-copy"
pass "cross-filesystem-style path refuses a directory source"

printf 'missing parent\n' > "$work/missing-parent-source"
expect_fail "$binary" --force-copy "$work/missing-parent-source" "$work/no-such-parent/destination"
test -f "$work/missing-parent-source"
pass "missing destination parent leaves source untouched"

printf 'new protected source\n' > "$work/protected-source"
printf 'old protected destination\n' > "$work/protected-destination"
cp "$work/protected-source" "$work/protected-source-expected"
cp "$work/protected-destination" "$work/protected-destination-expected"
expect_fail "$binary" --force-copy "$work/protected-source" "$work/protected-destination"
cmp "$work/protected-source-expected" "$work/protected-source"
cmp "$work/protected-destination-expected" "$work/protected-destination"
assert_no_temporary "$work/protected-destination"
pass "forced copy still refuses to clobber an existing destination"

printf 'explicit replacement\n' > "$work/force-replace-source"
printf 'old explicit replacement\n' > "$work/force-replace-destination"
"$binary" --force-copy --replace \
    "$work/force-replace-source" "$work/force-replace-destination"
printf 'explicit replacement\n' > "$work/force-replace-expected"
cmp "$work/force-replace-expected" "$work/force-replace-destination"
test ! -e "$work/force-replace-source"
pass "forced copy replaces only with explicit --replace"

fault_case()
{
    mode=$1
    errno_name=$2
    source="$work/fault-$mode-source"
    destination="$work/fault-$mode-destination"

    printf 'fault case %s\n' "$mode" > "$source"
    cp "$source" "$source.expected"

    expect_fail env \
        APPENDFAT_MV_FAULT="$mode" \
        APPENDFAT_MV_SOURCE="$source" \
        LD_PRELOAD="$faults" \
        "$binary" --force-copy "$source" "$destination"

    cmp "$source.expected" "$source"
    test ! -e "$destination"
    assert_no_temporary "$destination"
    pass "$errno_name leaves the source untouched and cleans the temporary file"
}

fault_case fallocate_eopnotsupp "Operation not supported (EOPNOTSUPP)"
fault_case fallocate_enospc "No space left on device (ENOSPC)"
fault_case fsync_eio "destination sync failure"
fault_case install_eio "destination install failure"

printf 'interrupted allocation\n' > "$work/eintr-source"
cp "$work/eintr-source" "$work/eintr-expected"
env \
    APPENDFAT_MV_FAULT=fallocate_eintr_once \
    LD_PRELOAD="$faults" \
    "$binary" --force-copy "$work/eintr-source" "$work/eintr-destination"
cmp "$work/eintr-expected" "$work/eintr-destination"
test ! -e "$work/eintr-source"
pass "Interrupted system call (EINTR) during reservation is retried"

printf 'unlink failure\n' > "$work/unlink-source"
cp "$work/unlink-source" "$work/unlink-expected"
expect_fail env \
    APPENDFAT_MV_FAULT=source_unlink_eio \
    APPENDFAT_MV_SOURCE="$work/unlink-source" \
    LD_PRELOAD="$faults" \
    "$binary" --force-copy "$work/unlink-source" "$work/unlink-destination"
cmp "$work/unlink-expected" "$work/unlink-source"
cmp "$work/unlink-expected" "$work/unlink-destination"
pass "source unlink failure leaves both complete copies"

dd if=/dev/urandom of="$work/race-source" bs=1M count=2 status=none
cp "$work/race-source" "$work/race-expected"
race_marker="$work/race-marker"
env \
    APPENDFAT_MV_FAULT=pause_before_install \
    APPENDFAT_MV_MARKER="$race_marker" \
    LD_PRELOAD="$faults" \
    "$binary" --force-copy "$work/race-source" "$work/race-destination" \
    >"$work/race.stdout" 2>"$work/race.stderr" &
race_pid=$!

i=0
while test ! -e "$race_marker" && test "$i" -lt 200
do
    sleep 0.01
    i=$((i + 1))
done
test -e "$race_marker" || fail "race test did not reach install boundary"
printf 'appeared during move\n' > "$work/race-destination"
if wait "$race_pid"; then
    fail "race-safe no-clobber test unexpectedly succeeded"
fi
cmp "$work/race-expected" "$work/race-source"
printf 'appeared during move\n' > "$work/race-destination-expected"
cmp "$work/race-destination-expected" "$work/race-destination"
assert_no_temporary "$work/race-destination"
pass "destination created during copy is not overwritten"

dd if=/dev/urandom of="$work/mutate-source" bs=1M count=2 status=none
mutate_marker="$work/mutate-marker"
env \
    APPENDFAT_MV_FAULT=pause_source_read \
    APPENDFAT_MV_MARKER="$mutate_marker" \
    APPENDFAT_MV_SOURCE="$work/mutate-source" \
    LD_PRELOAD="$faults" \
    "$binary" --force-copy "$work/mutate-source" "$work/mutate-destination" \
    >"$work/mutate.stdout" 2>"$work/mutate.stderr" &
mutate_pid=$!

i=0
while test ! -e "$mutate_marker" && test "$i" -lt 200
do
    sleep 0.01
    i=$((i + 1))
done
test -e "$mutate_marker" || fail "mutation test did not reach source read"
printf 'source changed\n' >> "$work/mutate-source"
if wait "$mutate_pid"; then
    fail "source mutation test unexpectedly succeeded"
fi
test -f "$work/mutate-source"
test ! -e "$work/mutate-destination"
assert_no_temporary "$work/mutate-destination"
pass "source growth during copy prevents publication and deletion"

printf 'appendfat_mv host and fault-injection tests: PASS\n'
