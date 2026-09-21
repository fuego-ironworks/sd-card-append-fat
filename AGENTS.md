# Repository working rules

## Production boundary

- Keep stock Linux/Android `fs/fat` untouched.
- Production derivative work belongs under `fs/appendfat/`.
- `reference/` is comparative source material, not production input by default.
- Do not copy code from `reference/` into production without exact provenance, version, and license review.

## Baseline discipline

- Preserve an exact, byte-identical upstream FAT baseline before semantic changes.
- Record the upstream repository, exact commit, file inventory, and blob hashes.
- Preserve upstream copyright and SPDX notices verbatim.
- Keep source import, identity/namespace changes, and append-allocation changes in separate reviewable commits or pull requests.

## Evidence boundaries

- Upstream Linux evidence is not Android-device evidence.
- Android common-kernel evidence is not vendor-kernel or physical-device evidence.
- A successful build is not a successful mount.
- A successful host/emulator mount is not physical SD-card acceptance.
- `fsck.fat` success is an on-disk consistency check, not proof of crash safety.

## First production gates

1. Exact source import matches the pinned blob inventory.
2. `appendfat` has an independent build/module/filesystem identity and can coexist with stock FAT.
3. An ordinary FAT image mounts through both stock FAT and appendfat without append-specific semantic changes.
4. The image remains accepted by `fsck.fat` and remounts through stock FAT.
5. Only then change allocation policy for the append arena.


## Physical removable-media safety

- Assume an SD card or other removable medium can contain unique, irreplaceable data.
- Do not format, repartition, run destructive repair, truncate, replace, rename, or delete a pre-existing user path merely to obtain acceptance evidence.
- Physical write tests must be explicitly armed and confined to a newly created scratch directory whose ownership is recorded and verified before cleanup.
- Do not use recursive deletion in physical-media acceptance scripts. Remove only exact test paths created by that run; if unexpected contents appear, stop cleanup and leave the scratch directory for inspection.
- User-facing movers and test tools should fail closed around existing destinations by default. Any replacement behavior must require an explicit option or separately explicit user intent.
- Keep read-only inventory/preflight evidence separate from write acceptance.
- For whole-card Android/Termux acceptance, require an explicitly identified removable-volume root such as `/storage/<volume-id>` or a verified symlink to it. Do not silently treat `~/storage/external-*` as the card root; Termux may map it to app-private `Android/data` storage.
