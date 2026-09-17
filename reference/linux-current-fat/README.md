# Current Linux FAT

Upstream:
- https://github.com/torvalds/linux/tree/master/fs/fat

Read first:
- `fatent.c` — FAT entry operations and cluster allocation/freeing.
- `inode.c` — block mapping and inode/superblock logic.
- `file.c` — file operations and synchronization.
- `cache.c` — FAT chain mapping cache.
- `dir.c` — directory machinery.
- `Kconfig`, `Makefile` — build/registration boundary.

Functions around `fat_alloc_clusters()` and chain attachment are the closest production-Linux starting point for an append-specific allocator.

Appendfat rule:

```text
stock fs/fat stays untouched
fs/appendfat begins as a behaviorally identical copy
first accepted change = independent registration and mount
second accepted change = controlled arena allocation
```

Do not let unrelated modern FAT cleanup leak into the first appendfat changes.