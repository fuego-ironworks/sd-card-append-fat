# Reference corpus

Comparative source material for `sd-card-append-fat`. This is not production `appendfat` code.

Each populated folder identifies what to read, why it matters, and a small appendfat-specific exercise. Upstream source is not copied blindly: preserve exact provenance, version/tag/commit, and license before vendoring anything.

## Recommended reading order

1. `bsd/4.4bsd-lite2/` — small 1992 `msdosfs` FAT allocator: understand the actual FAT-chain mutation first.
2. `linux-0.99/` — very small early Linux MSDOS/FAT implementation.
3. `fatfs-elm-chan/` — compact embedded FAT over a narrow block-device interface.
4. `linux-current-fat/` — production Linux allocation, mapping, cache, locking, and VFS behavior.
5. `android-3/` — current Android/Linux 6.6 integration and FAT-specific KUnit material.
6. `dosfstools/` — `mkfs.fat` and `fsck.fat`, used as external on-disk validity oracles.
7. `egos-2000/` and `xv6/` — tiny systems for disk/filesystem layering and crash reasoning.

## FAT and production-kernel lineage

- `android-1/` — Android common Linux 4.9-era FAT reference.
- `android-2/` — Android common Linux 4.19-era FAT reference.
- `android-3/` — Android 15 / Linux 6.6 FAT reference.
- `linux-0.99/` — early Linux MSDOS/FAT implementation.
- `linux-current-fat/` — current Linux FAT implementation.
- `dosfstools/` — userspace FAT formatter/checker.
- `bsd/4.4bsd-lite2/` — early BSD `msdosfs` allocator.
- `bsd/freebsd/`, `bsd/netbsd/`, `bsd/openbsd/` — independently maintained BSD descendants.

## Teaching operating systems

- `egos-2000/` — Earth and Grass Operating System; ~2,000-line teaching OS with an explicit disk interface and filesystem layer.
- `unix-v6-lions/` — Unix V6 source lineage and Lions commentary references.
- `jos/` — MIT 6.828 teaching OS preceding xv6.
- `xv6/` — small Unix-like filesystem, buffer cache, log, and disk path.
- `minix/` — explicit VFS/filesystem/device-service boundaries.
- `xinu/` — exceptionally small device/kernel interfaces; older editions also have a small local filesystem.
- `pintos/`, `nachos/`, `os161/` — readable allocation, block-mapping, simulated-disk, and filesystem-checking examples.

## Embedded and small systems

- `fatfs-elm-chan/` — compact FAT implementation widely used with SD cards.
- `nuttx/` — independent embedded FAT implementation.
- `zephyr/` — VFS/FatFs integration and removable-media block boundary.
- `ecos/` — plug-in filesystem and block-I/O boundary.
- `freertos/` — FreeRTOS+FAT/storage integration patterns.
- `ucos-ii/` — small deterministic kernel/port/configuration structure; historical licensing varies by edition.
- `geos/` — provisional "geo" match; tiny Commodore GEOS KERNAL with filesystem and disk-driver separation.
- `skyos/` — historical independent OS with FAT12/16/32 support and an OpenBFS-derived SkyFS.

## Real-time architecture reference

- `mars-tu-wien/` — MARS (Maintainable Real-Time System), strong candidate for the remembered Vienna system. Useful for deterministic scheduling/checkpoint ideas, not FAT source code.

## Identification ledgers

- `unresolved-earth-sky/` records why EGOS-2000 and SkyOS are the current Earth/Sky candidates.
- `unresolved-vienna/` records why MARS is the current Vienna candidate.

Keep these ledgers even after identification so the original clues and uncertainty are preserved.

## Production boundary

The intended production work remains separate:

```text
fs/fat/          # untouched stock Linux FAT
fs/appendfat/    # independently registered derivative
```

A reference becomes production input only through a deliberate, reviewable change with provenance and license recorded.