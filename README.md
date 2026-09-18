# sd-card-append-fat

Experimental append-oriented FAT filesystem work for removable SD-card storage.

The production design will remain separate from stock Linux/Android FAT code. Historical and comparative implementations belong under `reference/` and are source material only unless explicitly promoted.

A userspace `mv`-style experiment that reserves the destination with `FALLOC_FL_KEEP_SIZE` before a cross-filesystem copy is documented in [`docs/appendfat-mv.md`](docs/appendfat-mv.md).
