# dosfstools

Upstream:
- https://github.com/dosfstools/dosfstools

Read first:
- `src/mkfs.fat.c` — construct FAT12/16/32 volumes from scratch.
- `src/fsck.fat.c` and supporting FAT code — validate and repair on-disk structures.

Why it matters: kernel drivers tell us how Linux operates a mounted volume; dosfstools tells us what a valid FAT volume actually looks like from userspace.

Acceptance use:

```text
make image with mkfs.fat
mount with stock vfat
mount with appendfat
run append arena test
unmount
run fsck.fat
mount again with stock vfat
```

`fsck.fat` should become an external oracle for every generated corruption/power-loss fixture.