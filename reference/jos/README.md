# JOS

MIT 6.828 teaching source lineage:
- https://github.com/mit-pdos/6.828-lab

Read the filesystem lab pieces around:
- `fs/fs.c` — file/block allocation and metadata.
- `fs/bc.c` — disk block cache mapped into virtual memory.
- IDE/block-device code in the kernel.

JOS is especially useful for one idea: make cached disk blocks directly visible through a simple memory mapping so filesystem code stays small.

Appendfat question:

```text
Can the testing implementation expose the FAT image as a simple mapped/block array,
so allocator correctness can be tested independently of Linux VFS?
```

Use JOS for implementation clarity and test architecture, not FAT semantics.