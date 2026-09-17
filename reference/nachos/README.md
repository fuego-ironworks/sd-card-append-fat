# Nachos

Instructional OS originally developed for teaching operating-system internals.

Files to locate in a canonical Nachos distribution:
- `filesys/filesys.cc` — filesystem operations.
- `filesys/filehdr.cc` — file header / block mapping.
- bitmap/free-space code.
- `machine/disk.cc` or equivalent simulated-disk layer.

Why it matters: Nachos makes the filesystem run over an intentionally simple simulated disk, which is useful inspiration for our image-based oracle tests.

Appendfat test pattern:

```text
memory/disk image
→ deterministic sector fault injection
→ append operation
→ reopen image
→ verify last complete record and FAT validity
```

Pin a specific teaching distribution before copying anything; Nachos has many divergent course forks.