#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    printf '%s\n' "usage: $0 /dev/BLOCK_DEVICE RECEIPT_DIRECTORY" >&2
    exit 2
fi

device=$1
receipt_dir=$2

if [ "$(id -u)" -ne 0 ]; then
    printf '%s\n' 'physical SD acceptance requires root mount privileges' >&2
    exit 1
fi

if [ "${APPENDFAT_PHYSICAL_ACCEPT_WRITES:-}" != "$device" ]; then
    printf '%s\n' 'refusing physical-media writes without an exact-device confirmation' >&2
    printf '%s\n' "rerun with APPENDFAT_PHYSICAL_ACCEPT_WRITES=$device" >&2
    exit 2
fi

if [ ! -b "$device" ]; then
    printf '%s\n' "not a block device: $device" >&2
    exit 1
fi

if mount | grep -F "$device on " >/dev/null 2>&1; then
    printf '%s\n' "device is already mounted: $device" >&2
    exit 1
fi

grep -w vfat /proc/filesystems >/dev/null
grep -w appendfat /proc/filesystems >/dev/null

for command in fsck.fat mount umount sha256sum
do
    command -v "$command" >/dev/null 2>&1 || {
        printf '%s\n' "missing required command: $command" >&2
        exit 1
    }
done

mkdir -p "$receipt_dir"
receipt=$receipt_dir/physical-sd-round-trip.txt
mount_root=$(mktemp -d "${TMPDIR:-/tmp}/appendfat-physical.XXXXXX")
test_name="APPENDFAT-TEST-$$"
test_dir=$mount_root/$test_name
mounted=no

cleanup()
{
    if [ "$mounted" = yes ]; then
        umount "$mount_root" 2>/dev/null || true
    fi
    rmdir "$mount_root" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

{
    printf 'APPENDFAT_PHYSICAL_SD_ROUND_TRIP 1\n'
    printf 'device=%s\n' "$device"
    printf 'date_utc='
    date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
    printf 'uname='
    uname -a
    if command -v lsblk >/dev/null 2>&1; then
        printf '%s\n' '--- device identity ---'
        lsblk -ndo NAME,SIZE,RO,RM,TYPE,FSTYPE,MODEL,SERIAL,TRAN,LOG-SEC,PHY-SEC "$device" 2>/dev/null || true
    fi

    mount -t vfat "$device" "$mount_root"
    mounted=yes
    mkdir "$test_dir"
    printf 'stock-physical\n' > "$test_dir/Long Physical Name.txt"
    sync
    sha256sum "$test_dir/Long Physical Name.txt"
    umount "$mount_root"
    mounted=no

    mount -t appendfat "$device" "$mount_root"
    mounted=yes
    grep -qx 'stock-physical' "$test_dir/Long Physical Name.txt"
    printf 'appendfat-physical\n' >> "$test_dir/Long Physical Name.txt"
    printf 'created-by-appendfat\n' > "$test_dir/Created By Appendfat.txt"
    sync
    sha256sum "$test_dir/Long Physical Name.txt" "$test_dir/Created By Appendfat.txt"
    umount "$mount_root"
    mounted=no

    mount -t vfat "$device" "$mount_root"
    mounted=yes
    grep -qx 'stock-physical' "$test_dir/Long Physical Name.txt"
    grep -qx 'appendfat-physical' "$test_dir/Long Physical Name.txt"
    grep -qx 'created-by-appendfat' "$test_dir/Created By Appendfat.txt"
    sha256sum "$test_dir/Long Physical Name.txt" "$test_dir/Created By Appendfat.txt"
    rm -rf "$test_dir"
    sync
    umount "$mount_root"
    mounted=no

    fsck.fat -n -v "$device"

    if [ -r "/sys/class/block/$(basename "$device")/stat" ]; then
        printf '%s\n' '--- block statistics after test ---'
        cat "/sys/class/block/$(basename "$device")/stat"
    fi

    printf '%s\n' 'APPENDFAT_PHYSICAL_SD_ROUND_TRIP_PASS'
    printf '%s\n' 'Claim boundary: real block-device path and mount round trip only.'
    printf '%s\n' 'No claim is made about undocumented controller or flash-translation internals.'
} > "$receipt" 2>&1

cat "$receipt"
printf '%s\n' "receipt=$receipt"
