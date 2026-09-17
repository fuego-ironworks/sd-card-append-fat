# Android reference 2 — Linux 4.19 era

Purpose: a later pre-GKI Android kernel line, useful for comparing long-lived Android FAT behavior with the older 4.9 implementation.

Example upstream line:
- Android common `android-4.19-stable`
- example exact merge commit: `2d76dea417beb11b47beb4933a41f184bec6966a`
- https://android.googlesource.com/kernel/common/+/2d76dea417beb11b47beb4933a41f184bec6966a/fs/fat/

Read first:
- `fs/fat/fatent.c`
- `fs/fat/inode.c`
- `fs/fat/file.c`
- `fs/fat/cache.c`
- `fs/fat/dir.c`

Comparison exercise:

```text
4.9 allocation path
        ↓ compare
4.19 allocation path
        ↓ isolate
changes required for correctness / writeback / locking
        ↓
changes that appendfat can avoid by preallocation
```

Keep Android-specific evidence separate from generic Linux FAT behavior. Pin exact source before copying.