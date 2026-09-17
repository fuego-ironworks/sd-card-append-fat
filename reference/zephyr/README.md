# Zephyr

Upstream:
- https://github.com/zephyrproject-rtos/zephyr
- `subsys/fs/fat_fs.c`
- FatFs module: https://github.com/zephyrproject-rtos/fatfs

What to study:
- how a generic filesystem interface wraps Elm-Chan FatFs;
- filesystem registration;
- mount/unmount;
- removable-media disk I/O;
- explicit `sync` behavior;
- SDHC buffer alignment and block-device boundaries.

Zephyr's wrapper is a useful miniature analogue of what we want from Linux:

```text
generic VFS calls
      ↓
appendfat filesystem identity
      ↓
append-specific allocation policy
      ↓
ordinary block device / SD card
```

Do not copy Zephyr's API shape into Linux; use it to keep the layering understandable.