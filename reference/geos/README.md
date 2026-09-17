# GEOS

Provisional match for the remembered "geo" operating system.

Best readable source corpus:
- https://github.com/mist64/geos
- reverse-engineered GEOS 2.0 KERNAL source for Commodore 64/128.

Read first:
- `kernal/filesys.s` — filesystem API implementation.
- `drv/` — disk/storage drivers.
- e.g. `drv/drv1541.s` — explicit block/directory operations for a Commodore disk drive.

The reconstructed KERNAL is only about 20 KB of binary code but includes a storage-driver interface and filesystem API. It is therefore valuable as an extreme small-system reference even though its disk format is not FAT and its 6502 environment is very different from Android/Linux.

Appendfat lesson:

```text
filesystem semantics
       ↓
small disk-driver interface
       ↓
device-specific storage operations
```

A second, much larger branch of the name is PC/GEOS; source exists at https://github.com/bluewaysw/pcgeos. Keep that distinct from Commodore GEOS if it becomes relevant.

The identification remains provisional until the intended "geo" system is confirmed.