# Apache NuttX FAT

Upstream:
- https://github.com/apache/nuttx
- `fs/fat/`

Read first:
- `fs_fat32.h` — on-disk constants and in-memory FAT state.
- the `fs_fat32*.c` implementation files — mount, directory, cluster, read/write, and utility paths.

Why it matters: NuttX is a small POSIX-like embedded OS with its own FAT implementation rather than merely wrapping Linux FAT.

Appendfat comparison:

```text
Linux FAT       NuttX FAT       FatFs
allocator       allocator       allocator
mapping         mapping         mapping
sync            sync            sync
```

Where three independent implementations agree, treat that behavior as strong evidence for an on-disk FAT invariant. Where they differ, identify the kernel/API policy causing the difference.