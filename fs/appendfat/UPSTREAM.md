# appendfat upstream baseline

`fs/appendfat` begins from an exact copy of Linux `fs/fat` before any append-specific behavior is introduced.

## Pinned source

- repository: `https://github.com/torvalds/linux.git`
- commit: `238650ef6c7c7cca08e032527329424c9fbd70e5`
- upstream path: `fs/fat/`
- pinned on: 2026-09-17

This is an upstream Linux baseline. It is **not** evidence that this commit matches any particular Android or vendor kernel. Android integration must be reconciled against the exact target kernel separately.

## Exact blob inventory

The first import must reproduce these Git blob IDs exactly:

| file | upstream blob |
| --- | --- |
| `.kunitconfig` | `0a6971dbeccb000be7dcd424c09a89496df57de3` |
| `Kconfig` | `25fae1c83725bc9293c26e9191690241d77b1295` |
| `Makefile` | `2b034112690d8a176b84f259a98f868028336540` |
| `cache.c` | `1b87354e24ba3a519082934ca48e277c3405d09b` |
| `dir.c` | `35bdb62944a2eb9eaa91e562a2da245929887d7f` |
| `fat.h` | `61338413d9f3e404d6dc1ca1915f706913dbb6d4` |
| `fat_test.c` | `9583ce66dca3cdc1f783577c35bbd7676cb9bf2f` |
| `fatent.c` | `f0801d99dd62aefee4f573cfda332e7201235c32` |
| `file.c` | `1c835ca5f21a51a10b35522b609092c8ba873ce6` |
| `inode.c` | `f775a004cae1e2f7eec2b7977c8e11ea1652dfc2` |
| `misc.c` | `e79762cf19754d19096b5a8d8b2f8b7ae6a31995` |
| `namei_msdos.c` | `d46d1a3851f25f75b4f9e88c2376894731e5def5` |
| `namei_vfat.c` | `da3e89c0b16ac8fd076d7f70eec50c682f043812` |
| `nfs.c` | `6e1b371711edd5aacb5a81092e32361bb255e86a` |

Run `scripts/import-linux-fat.sh` to materialize and verify the copy.

## License and provenance boundary

The imported files are Linux kernel source and retain their upstream copyright notices and SPDX identifiers verbatim. Do not strip or rewrite those notices during import or later renaming.

Do not mix source from BSD, embedded, teaching, historical, Android, or other `reference/` entries into this directory without a separate provenance/license review and an explicit change explaining why it is production input.

## Change order

1. Import the pinned upstream files byte-for-byte.
2. Verify every blob against the inventory above.
3. In a separate commit, give the derivative an independent build/module/filesystem identity while leaving FAT behavior unchanged.
4. Build it inside a matching Linux tree.
5. Mount an ordinary FAT image with stock FAT and with appendfat and compare behavior.
6. Only after that baseline is green, introduce append-specific allocation policy.

Stock Linux `fs/fat` is never modified by this repository's append-specific work.
