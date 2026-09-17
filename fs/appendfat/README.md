# appendfat

This directory contains the production append-oriented FAT derivative.

The source baseline comes from the exact Linux commit recorded in `UPSTREAM.md`. Stock Linux `fs/fat` remains separate and untouched.

## Current status

1. **Exact upstream import — complete.** The original `fs/fat` files were imported byte-for-byte and verified against the pinned Git blob inventory.
2. **Independent identity — compile-validated.** The derivative now has its own `APPENDFAT_*` configuration namespace, `appendfat_core` / `appendfat` / `appendmsdos` build identities, `appendfat` / `appendmsdos` filesystem registrations, and namespaced externally visible implementation symbols. Stock FAT and appendfat were configured together and both linked-object families compiled from the same pinned Linux tree. Their only remaining shared linked-object globals were generic module-loader wrappers (`init_module`, `cleanup_module`, and compiler-generated companions).
3. **Mount equivalence — not yet accepted.** Full module postprocessing/loading, mounting the same ordinary FAT image through stock VFAT and appendfat, `fsck.fat`, and stock remount remain future gates.
4. **Append allocation — not started.** No append-arena allocation semantics belong in the identity stage.
5. **Crash/power-loss and removable-media acceptance — not started.**
6. **Exact Android/vendor/device reconciliation — not started.**

The identity transform is intentionally mechanical: it changes configuration, module/filesystem names, and externally visible symbol names, not FAT parsing, allocation, mapping, directory, writeback, or on-disk rules.

Do not collapse these stages. In particular, an upstream Linux compile is not a successful mount, and neither is Android/vendor-kernel or physical-SD-card evidence.
