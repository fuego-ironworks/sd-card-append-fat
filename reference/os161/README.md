# OS/161

Canonical teaching source:
- https://github.com/ops-class/os161

Read first:
- `kern/vfs/` — filesystem-independent VFS layer.
- `kern/fs/sfs/` — Simple File System implementation.
- SFS block allocation/free-map and inode code.
- the `sfsck` checker in the companion userland/tools tree when using the matching distribution.

OS/161 is useful because the teaching filesystem is larger than xv6's but still small enough to trace from VFS operation through allocation and block I/O.

Appendfat exercise:

```text
create deterministic disk image
inject failure after sector write N
reopen image
run filesystem checker
classify which ordering failures corrupt allocation metadata
```

Use this for crash-testing structure and filesystem/VFS separation, not for FAT semantics.