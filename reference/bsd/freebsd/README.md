# FreeBSD msdosfs

Upstream:
- https://github.com/freebsd/freebsd-src
- `sys/fs/msdosfs/`

Read first:
- `msdosfs_fat.c` — FAT chains and allocation.
- `msdosfs_denode.c` — file-node lifecycle.
- `msdosfs_vfsops.c` — mount/unmount.
- `msdosfs_vnops.c` — vnode operations.
- `fat.h`, `msdosfsmount.h` — compact data structures and FAT operations.

Why compare it: FreeBSD preserves the 1992 `msdosfs` lineage while showing decades of production-kernel hardening.

Example question for appendfat:

```text
Which old allocator operations remain recognizable?
Which extra synchronization/cache rules are correctness requirements?
Which metadata writes disappear once an arena is preallocated?
```

Use current FreeBSD for interfaces; use the 4.4BSD folder for conceptual simplicity.