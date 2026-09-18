# `appendfat_mv`

`tools/appendfat_mv.c` is a deliberately small `mv`-style program for moving a regular file onto a filesystem that supports Linux `FALLOC_FL_KEEP_SIZE`.

For a same-filesystem move it calls `rename()` and does not rewrite the file. For a cross-filesystem move it:

1. creates a temporary file beside the final destination;
2. calls `fallocate(FALLOC_FL_KEEP_SIZE, 0, source_size)` before copying data;
3. verifies that the reservation did not increase logical file size;
4. copies exactly the snapshotted source length through the already allocated destination;
5. checks that the open source did not change size or modification time during the copy;
6. `fsync()`s the destination;
7. renames the temporary file over the final destination; and
8. removes the source only after the destination has been installed.

If keep-size fallocate is unsupported or returns `ENOSPC`, the move fails before data copy and leaves the source untouched. This is intentional: silently falling back to ordinary incremental allocation would defeat the purpose of the tool.

## Android ARMv7 / Thumb-2 build

On the target 32-bit Android/Termux phone, build natively with:

```sh
clang \
    -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror \
    -mthumb -march=armv7-a -fPIE -pie \
    tools/appendfat_mv.c -o appendfat_mv
```

The source defines `_FILE_OFFSET_BITS=64`, so the allocation and copy length are not limited to 2 GiB by the 32-bit userspace ABI. The `fallocate()` libc wrapper is used rather than issuing the ARM syscall directly, leaving bionic to handle the ARM EABI argument convention for the 64-bit offset and length.

Example, moving from internal Termux storage to the SD card:

```sh
./appendfat_mv \
    ~/takeout/archive.zip \
    ~/storage/external-1/archive.zip
```

An existing destination directory is also accepted:

```sh
./appendfat_mv ~/takeout/archive.zip ~/storage/external-1/
```

`--force-copy` bypasses the same-filesystem `rename()` fast path. It exists mainly for testing the reservation/copy path:

```sh
./appendfat_mv --force-copy source destination
```

## Current physical-phone result

The stock removable-storage path on the target phone does not currently satisfy
the reservation precondition: the 2026-09-18 physical probe returned
`EOPNOTSUPP` for `FALLOC_FL_KEEP_SIZE` through the Termux/Android FUSE view.
That is an expected fail-closed case for this utility, not appendfat evidence.

See [the retained phone probe](phone-keep-size-probe-2026-09-18.md). The same
probe must be repeated against an actual physical appendfat mount before this
tool is considered usable for the target SD-card path.

## Evidence boundary

`FALLOC_FL_KEEP_SIZE` reserves filesystem allocation beyond logical EOF. On FAT this can allocate the file's FAT cluster chain before the data copy, so later writes can consume already linked clusters rather than extending the chain one cluster at a time.

It does **not** specify physical NAND placement inside the SD card, and it does not prove that the allocated FAT clusters are contiguous. The SD controller's flash-translation layer remains outside this interface.

On Android, an SD-card path exposed through `/dev/fuse` must also pass keep-size fallocate through successfully. If the existing `fallocate --keep-size` probe succeeds on that path, `appendfat_mv` exercises the same kernel interface; otherwise this program will fail closed and report the error.

Cross-filesystem mode currently supports regular files only. It is not a complete replacement for GNU `mv`: directory trees, symlinks, xattrs, ACLs, ownership, and interactive overwrite policy are intentionally outside this first tool.
