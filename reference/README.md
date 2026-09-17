# Reference corpus

This tree is comparative source material for `sd-card-append-fat`. It is not production `appendfat` code.

## Rules

- Preserve upstream provenance, version/tag/commit, and license before copying source.
- Do not silently mix reference code into the production driver.
- Prefer small, readable implementations that expose allocation, block mapping, directory updates, crash behavior, and mount/registration mechanics.
- For Android snapshots, record the exact Android/kernel branch and commit before importing code.
- Unresolved spoken names stay explicitly unresolved until identified.

## FAT and production-kernel lineage

- `android-1/`, `android-2/`, `android-3/` — three Android/Linux FAT snapshots; exact versions still to select.
- `linux-0.99/` — early Linux MSDOS/FAT implementation.
- `linux-current-fat/` — current Linux FAT implementation for modern VFS/kernel integration.
- `dosfstools/` — userspace FAT construction/checking implementation.
- `bsd/` — historical and current BSD implementations, with separate subfolders for 4.4BSD-Lite2, FreeBSD, NetBSD, and OpenBSD.

## Teaching operating systems

- `unix-v6-lions/` — Unix V6 source lineage and John Lions commentary references.
- `jos/` — MIT 6.828 exokernel teaching system that preceded xv6.
- `xv6/` — MIT teaching Unix, currently used in RISC-V form.
- `minix/`, `xinu/`, `pintos/`, `nachos/`, `os161/` — additional small teaching systems worth comparing for filesystem/block-layer clarity.

MIT's own course history explicitly describes the progression from Unix V6 with Lions, through JOS, to xv6:
https://ocw.mit.edu/courses/6-828-operating-system-engineering-fall-2012/pages/study-materials/

## Embedded and small systems

- `ucos-ii/` — µC/OS-II / MicroC/OS-II. Historical source has licensing restrictions; do not vendor code until the exact version/license is checked.
- `fatfs-elm-chan/` — Elm-Chan FatFs, particularly relevant because it is a compact FAT implementation used in embedded systems.
- `zephyr/` — Zephyr's filesystem/VFS integration and its FatFs adapter.
- `ecos/`, `nuttx/`, `freertos/` — embedded OS reference points.
- `geos/` — GEOS candidate for the spoken "geo" reference; keep provisional until confirmed.

Zephyr's FAT support identifies Elm-Chan FatFs as the implementation behind its FAT filesystem option:
https://github.com/zephyrproject-rtos/zephyr/blob/main/subsys/fs/Kconfig.fatfs

## Unresolved names

- `unresolved-earth-sky/` — placeholder for the spoken "Earth and sky" reference.
- `unresolved-vienna/` — placeholder for the operating system remembered as having been developed in Vienna.

These names are intentionally not guessed into a different project.
