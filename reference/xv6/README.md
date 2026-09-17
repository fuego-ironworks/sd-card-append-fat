# xv6

MIT PDOS source:
- https://github.com/mit-pdos/xv6-riscv

Read first:
- `kernel/fs.c` — inode and block mapping.
- `kernel/bio.c` — buffer cache.
- `kernel/log.c` — write-ahead log and crash recovery.
- `kernel/virtio_disk.c` — block device boundary.
- `mkfs/mkfs.c` — image construction.

xv6 does not implement FAT. It is here because the entire path from `write()` to durable disk blocks is small enough to understand.

Appendfat exercise:

```text
record write
→ block mapping
→ dirty buffer
→ ordering / commit point
→ disk
```

Use xv6 to reason about crash boundaries, not as a FAT source.