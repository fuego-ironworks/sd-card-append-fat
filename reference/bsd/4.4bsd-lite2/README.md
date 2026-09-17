# 4.4BSD-Lite2 / early msdosfs

This is one of the best small references for the allocator we care about.

Source mirror:
- https://github.com/sergev/4.4BSD-Lite2
- look under `sys/msdosfs/`

Read first:
- `msdosfs_fat.c`
- `fat.h`
- `msdosfs_vfsops.c`
- `msdosfs_vnops.c`

The FAT file identifies the original implementation as October 1992 and exposes unusually direct operations including:
- `chainalloc`
- `chainlength`
- `fatchain`
- `fatblock`
- `updatefats`

Appendfat example:

```text
allocate_contiguous(start, count)
    verify count free clusters from start
    write next-cluster links for the run
    terminate final cluster with EOF
    update every FAT copy
```

Study this before the modern Linux allocator: it exposes the on-disk operation with much less surrounding machinery.

Do not copy source until the exact file-level license notices are retained and reviewed.