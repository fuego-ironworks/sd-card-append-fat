#!/bin/sh
set -eu

out=${1:-android-device-facts.txt}

{
    printf 'APPENDFAT_ANDROID_DEVICE_FACTS 1\n'
    printf 'date_utc='
    date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true
    printf 'uname='
    uname -a
    printf 'kernel_release='
    uname -r
    printf 'machine='
    uname -m

    if command -v getprop >/dev/null 2>&1; then
        for property in \
            ro.build.fingerprint \
            ro.product.manufacturer \
            ro.product.model \
            ro.product.device \
            ro.build.version.release \
            ro.build.version.sdk
        do
            printf '%s=' "$property"
            getprop "$property"
        done
    fi

    printf '%s\n' '--- /proc/filesystems ---'
    cat /proc/filesystems

    printf '%s\n' '--- mounts containing fat, sd, mmc, or media ---'
    mount | grep -Ei 'fat|sd|mmc|media' || true

    printf '%s\n' '--- block devices ---'
    if command -v lsblk >/dev/null 2>&1; then
        lsblk -o NAME,MAJ:MIN,SIZE,RO,RM,TYPE,FSTYPE,MOUNTPOINTS,MODEL,TRAN 2>/dev/null || lsblk
    else
        find /sys/class/block -maxdepth 1 -mindepth 1 -type l -print 2>/dev/null || true
    fi

    if grep -w appendfat /proc/filesystems >/dev/null 2>&1; then
        printf '%s\n' 'appendfat_registered=yes'
    else
        printf '%s\n' 'appendfat_registered=no'
    fi
} > "$out"

cat "$out"
printf '%s\n' "receipt=$out"
