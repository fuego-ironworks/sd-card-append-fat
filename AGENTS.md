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
