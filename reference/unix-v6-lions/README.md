# Unix V6 / Lions

This is a teaching reference for small-kernel filesystem structure, not FAT.

Primary historical material:
- Unix Sixth Edition source as preserved by TUHS.
- John Lions, *A Commentary on the Sixth Edition UNIX Operating System*.

Filesystem files worth reading in a V6 source tree:
- `alloc.c` — block/inode allocation.
- `bio.c` — buffer/block I/O.
- `rdwri.c` — read/write path.
- `sys2.c` — file-related system calls.

Appendfat lesson:

```text
keep allocation policy small enough that one person can trace:
request → allocate/map → buffer → device
```

Do not vendor Lions commentary or historical Unix source here unless redistribution rights for the exact material are established.