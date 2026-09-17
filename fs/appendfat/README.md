# appendfat

This directory is reserved for the production append-oriented FAT derivative.

The first source baseline comes from the exact Linux commit recorded in `UPSTREAM.md`. Importing that source does not by itself create a usable independent filesystem: the unmodified Linux FAT code still has the original symbols, modules, configuration names, and filesystem registrations.

Work in this directory proceeds in strict stages:

1. exact upstream import;
2. independent namespace/build/module/filesystem identity with no intended FAT semantic change;
3. ordinary FAT-image equivalence checks against stock FAT;
4. append-arena allocation experiments;
5. crash/power-loss and removable-media acceptance;
6. reconciliation into the exact Android/vendor kernel used by the target device.

Do not collapse these stages into one change. In particular, do not treat an upstream Linux build or host mount as Android or physical-SD-card acceptance.
