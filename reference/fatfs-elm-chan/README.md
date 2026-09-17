# Elm-Chan FatFs

Canonical project:
- http://elm-chan.org/fsw/ff/
- Zephyr-maintained module mirror: https://github.com/zephyrproject-rtos/fatfs

Read first:
- `ff.c`
- `ff.h`
- `diskio.h` and the platform disk-I/O shim.

Particularly relevant internal ideas:
- read/update a FAT entry;
- create or extend a cluster chain;
- move the filesystem window/cache;
- pre-expand a file (`f_expand` in configurations that provide it);
- sync explicitly.

Appendfat exercise:

```text
preallocate N clusters once
hold a logical used_length separately
append data without extending the FAT chain
commit used_length only at a chosen checkpoint
```

FatFs is probably the cleanest compact implementation to compare with the 1992 BSD allocator because it speaks directly to a block-device interface and is widely used on SD cards.