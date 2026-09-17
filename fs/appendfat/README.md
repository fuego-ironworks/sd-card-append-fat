# appendfat

This directory contains the production append-oriented FAT derivative.

The source baseline comes from the exact Linux commit recorded in `UPSTREAM.md`. Stock Linux `fs/fat` remains separate and untouched.

## Current status

1. **Exact upstream import — complete.** The original `fs/fat` files were imported byte-for-byte and verified against the pinned Git blob inventory.
2. **Independent identity — compile-validated.** The derivative has its own `APPENDFAT_*` configuration namespace, `appendfat_core` / `appendfat` / `appendmsdos` build identities, `appendfat` / `appendmsdos` filesystem registrations, and namespaced externally visible implementation symbols. Stock FAT and appendfat were configured together and both linked-object families compiled from the same pinned Linux tree. Their only remaining shared linked-object globals were generic module-loader wrappers (`init_module`, `cleanup_module`, and compiler-generated companions).
3. **Pinned-Linux QEMU FAT32 image equivalence — accepted for the fixture.** One kernel with stock `vfat` and built-in `appendfat` mounted the same fresh 64 MiB FAT32 image in the sequence stock `vfat` → `appendfat` → stock `vfat`. Long filenames, directories, existing file data, appended file data, and newly created data survived the round trip, and the resulting image completed host `fsck.fat -n -v` successfully. The durable fixture is documented in `../../docs/qemu-fat-equivalence.md`.
4. **Loadable-module acceptance — not yet accepted.** The QEMU gate builds the two filesystem families into the same kernel; separate `.ko` postprocessing, loading, unloading, and coexistence remain a distinct gate if the module path is needed.
5. **Append allocation — not started.** No append-arena allocation semantics have been introduced.
6. **Crash/power-loss and removable-media acceptance — not started.**
7. **Exact Android/vendor/device reconciliation — not started.**

The identity transform is intentionally mechanical: it changes configuration, module/filesystem names, and externally visible symbol names, not FAT parsing, allocation, mapping, directory, writeback, or on-disk rules.

Do not collapse these stages. Pinned-Linux QEMU evidence is not Android/vendor-kernel evidence and is not physical-SD-card evidence. A successful `fsck.fat` check on the tested image is not proof of crash safety.
