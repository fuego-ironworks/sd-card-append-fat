# MINIX 3

Upstream:
- https://github.com/Stichting-MINIX-Research-Foundation/minix

Read around:
- `minix/fs/mfs/` — MINIX filesystem implementation.
- `minix/servers/vfs/` — VFS server and filesystem-facing interface.
- block-device drivers beneath the filesystem server.

Why it matters: MINIX makes the filesystem/VFS/device boundaries explicit because major operating-system services run as separate components.

Appendfat exercise:

```text
append policy
    ↓ narrow request interface
FAT implementation
    ↓ block requests
SD/block device
```

Even though Linux keeps these pieces in one kernel address space, preserving similarly narrow conceptual interfaces should make appendfat easier to test and port.