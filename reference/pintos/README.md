# Pintos

Teaching OS used in Stanford-derived operating-systems courses.

Typical source tree:
- `src/filesys/filesys.c` — filesystem-level operations.
- `src/filesys/inode.c` — file-to-sector mapping.
- `src/filesys/free-map.c` — free-space allocator.
- `src/devices/block.c` — block-device abstraction.

Why it matters: the free-space allocator and inode mapping are deliberately simple enough to modify in coursework.

Appendfat exercise:

```text
replace allocate-one-block-on-growth
with reserve-large-run-on-arena-creation
then make append map only inside the reservation
```

Use a canonical course distribution when pinning source; student forks often contain assignment solutions and should not become provenance.