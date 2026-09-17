# Linux 0.99 MSDOS/FAT

Historical source:
- tag `v0.99-pl11` in the archived early Linux history
- https://kernel.googlesource.com/pub/scm/linux/kernel/git/nico/archive/+/v0.99-pl11/fs/msdos/

Read first:
- `fat.c`
- `inode.c`
- `file.c`
- `misc.c`
- `include/linux/msdos_fs.h`

This is valuable because the FAT implementation is small enough to read nearly end-to-end. `fat.c` contains direct FAT-entry access and chain freeing without the modern layers of abstraction.

Appendfat exercise:

```text
read old fat_access(cluster)
read old file growth path
write down every sector that changes when one cluster is appended
then compare with a preallocated arena, where those FAT writes vanish
```

The goal is conceptual compression, not copying obsolete kernel APIs.