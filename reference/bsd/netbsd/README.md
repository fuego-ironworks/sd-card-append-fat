# NetBSD msdosfs

Upstream:
- https://github.com/NetBSD/src
- `sys/fs/msdosfs/`

Read first:
- `msdosfs_fat.c`
- `msdosfs_denode.c`
- `msdosfs_vfsops.c`
- `msdosfs_vnops.c`
- `msdosfs_rename.c`

NetBSD is useful because the directory still cleanly separates FAT-chain manipulation from vnode/VFS behavior.

Appendfat comparison:

```text
cluster allocator
    vs
logical file mapping
    vs
directory metadata update
```

Keep those three concerns separable in our driver so an append arena can change allocation policy without inventing a new on-disk format.