# EGOS-2000 — Earth and Grass Operating System

Upstream:
- https://github.com/yhzhang0128/egos-2000

This is almost certainly the remembered "Earth" teaching system. Its stated goal is an educational operating system whose complete implementation can be read; the project keeps the core at about 2,000 lines of code.

Architecture:
- `earth/` — hardware-specific tty, disk, timer, and memory interfaces.
- `grass/` — hardware-independent process/system-call layer.
- `apps/` — filesystem, shell, commands, and system services.
- `library/` — filesystem/inode exercises and shared interfaces.

Read first:
- the disk methods exposed by `struct earth` in `library/egos.h`;
- `apps/system/sys_file.c` — filesystem server talking directly to the Earth disk interface;
- `library/file/` — deliberately small teaching filesystem implementations.

This is unusually relevant to appendfat because the hardware/disk boundary and filesystem logic are both exposed in a tiny system.

Appendfat experiment:

```text
Earth disk interface
      ↓
FAT32 image adapter
      ↓
reserve contiguous arena
      ↓
append records
      ↓
reopen and validate image
```

Keep EGOS code as a teaching/reference source. Do not silently transpose its toy-filesystem assumptions into production FAT semantics.