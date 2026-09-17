# Android reference 3 — Android 15 / Linux 6.6

Purpose: modern Android-kernel integration, tests, locking, and build structure.

Pinned example:
- tag `android15-6.6-2025-03_r21`
- FAT tree `718e4fdd8871dc22f1bdba975bf5e2e7f75a8615`
- https://android.googlesource.com/kernel/common/+/refs/tags/android15-6.6-2025-03_r21/fs/fat/

Read first:
- `fatent.c` — allocation/FAT-entry machinery.
- `inode.c`, `file.c`, `cache.c`, `dir.c` — normal data path.
- `fat_test.c`, `.kunitconfig` — modern FAT-specific test hooks.
- `Kconfig`, `Makefile` — model for adding a separately registered `appendfat` driver.

Appendfat integration exercise:

```text
copy fs/fat -> fs/appendfat
rename config/module/filesystem identity
mount an ordinary FAT32 image as appendfat
prove stock fat still mounts the same image
only then change allocation semantics
```

This is not evidence for the user's exact phone kernel; that requires the device/vendor kernel source.