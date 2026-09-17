# eCos

Source mirrors:
- https://github.com/ecos-rtos/ecos
- FAT package under `packages/fs/fat/`
- generic file-I/O layer under `packages/io/fileio/`

What to study:
- FAT12/16 implementation and later FAT support;
- plug-in filesystem interface;
- separation between filesystem operations and disk-device I/O;
- the RAM filesystem as a deliberately readable example of registering a filesystem.

Useful appendfat lesson:

```text
filesystem policy should depend on a narrow block interface
not on SD-card-controller details
```

That boundary lets the same append logic run against a disk image, QEMU block device, USB reader, or physical SD card.