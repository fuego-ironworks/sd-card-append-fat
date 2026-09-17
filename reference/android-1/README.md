# Android reference 1 — Linux 4.9 era

Purpose: an older Android-common FAT implementation close to the ARMv7 / early Android Go period.

Example upstream snapshot:
- Android common `android-4.9`
- example exact commit: `a80a7ab5f7c3a9b8ab78696282faf38be9349ee7`
- https://android.googlesource.com/kernel/common/+/a80a7ab5f7c3a9b8ab78696282faf38be9349ee7/fs/fat/

Read first:
- `fs/fat/fatent.c` — FAT entry access, free-cluster search, allocation/freeing.
- `fs/fat/inode.c` — logical-file-block to cluster/block mapping and file growth.
- `fs/fat/file.c` — write/truncate/sync behavior.
- `fs/fat/Kconfig`, `fs/fat/Makefile` — how the driver is selected and built.

Appendfat example to derive, not copied source:

```text
reserve_arena(cluster_count)
    find a free run
    link the whole run once
    remember first cluster and allocated length

append(offset, bytes)
    map offset into the already allocated chain
    write data sectors only
    avoid FAT-chain growth on the steady-state path
```

This snapshot is a reference only. Pin the exact source and license before importing code.