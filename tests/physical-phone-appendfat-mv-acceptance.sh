#!/usr/bin/env bash
set -u

fail()
{
    printf '\033[1;31mFAIL\033[0m  %s\n' "$*" >&2
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
test -n "$root" || fail "could not resolve SD_ROOT: $requested"

case "$root" in
    /storage/*) ;;
    *) fail "SD_ROOT must resolve to an Android removable-storage root under /storage: $root" ;;
esac

volume=${root#/storage/}
case "$volume" in
    ''|*/*|emulated|self)
        fail "SD_ROOT must be the removable-volume root itself, not a nested or emulated path: $root"
        ;;
esac

mountpoint=$(df -Pk "$root" | awk 'NR==2 {print $6}')
test "$mountpoint" = "$root" ||
    fail "SD_ROOT resolves below filesystem mountpoint $mountpoint; use the whole-card root: $root"

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
commit=$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unknown)

receipt_dir=${APPENDFAT_RECEIPT_DIR:-"$HOME/.local/share/fuego-ironworks/sd-card-append-fat/receipts"}
mkdir -p "$receipt_dir"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
receipt="$receipt_dir/physical-phone-appendfat-mv-$stamp.txt"

run_acceptance()
{
    printf '\033[1;36m== physical phone card-root acceptance ==\033[0m\n'
    printf 'repo=%s\n' "$repo_root"
    printf 'commit=%s\n' "$commit"
    printf 'requested_sd_root=%s\n' "$requested"
    printf 'resolved_sd_root=%s\n' "$root"
    printf 'mountpoint=%s\n' "$mountpoint"
    printf 'receipt=%s\n' "$receipt"
    printf 'date_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    uname -a
    if command -v getprop >/dev/null 2>&1; then
        printf 'ro.product.cpu.abi=%s\n' "$(getprop ro.product.cpu.abi)"
        printf 'ro.build.fingerprint=%s\n' "$(getprop ro.build.fingerprint)"
    fi
    sha256sum "$repo_root/tools/appendfat_mv.c" "$binary"

    printf '\n\033[1;36m== read-only preflight ==\033[0m\n'
    APPENDFAT_COLOR=always         sh "$script_dir/physical-sd-readonly-preflight.sh" "$root" || return $?

    printf '\n\033[1;36m== armed scratch acceptance ==\033[0m\n'
    APPENDFAT_COLOR=always APPENDFAT_MV_PHYSICAL_SCRATCH=YES         sh "$script_dir/physical-appendfat-mv-scratch.sh" "$binary" "$root" || return $?

    printf '\n\033[1;32mAPPENDFAT_MV_PHYSICAL_ACCEPTANCE_COMPLETE\033[0m\n'
    printf 'receipt=%s\n' "$receipt"
}

set +e
run_acceptance 2>&1 |
    tee >(sed $'s/\033\\[[0-9;]*m//g' > "$receipt")
status=${PIPESTATUS[0]}
set -e

exit "$status"
