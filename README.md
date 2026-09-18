# sd-card-append-fat

Experimental append-oriented FAT filesystem work for removable SD-card storage.

The production design will remain separate from stock Linux/Android FAT code. Historical and comparative implementations belong under `reference/` and are source material only unless explicitly promoted.

Userspace experiments are kept separate from kernel appendfat semantics:

- [fallocate-aware `mv` experiment](docs/appendfat-mv.md), which requires `FALLOC_FL_KEEP_SIZE`;
- [pre-zeroed fixed-size append arena](docs/prezeroed-userspace-arena.md) for storage paths where keep-size fallocate is unavailable.

Design comparison:

- [comparison of `appendfat_mv` with the userspace, kernel, FatFs, and raw-storage alternatives](docs/appendfat-mv-alternatives.md).
