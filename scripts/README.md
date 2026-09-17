# Scripts

`import-linux-fat.sh` materializes the exact pinned Linux `fs/fat` baseline into `fs/appendfat/` and verifies every imported file by Git blob ID.

`verify-import-manifest.sh` checks that the blob inventory in `fs/appendfat/UPSTREAM.md` and the importer agree.

These scripts establish provenance only. They do not rename symbols, register an `appendfat` filesystem, change FAT allocation behavior, or provide Android/device acceptance evidence.
