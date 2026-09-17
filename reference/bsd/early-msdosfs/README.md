# Early BSD msdosfs — Paul Popelka / NetBSD 1993 import

This replaces the earlier, incorrect claim that the small `msdosfs` allocator lived in the `sergev/4.4BSD-Lite2` tree. That mirror does not contain the cited `sys/msdosfs/` source. Do not treat this entry as 4.4BSD-Lite2 provenance.

## Exact historical source

Repository:
- https://github.com/NetBSD/src

Pinned import commit:
- `54eb3b1f88e39311cfcb3c4aa6f4f9111045e2b5`
- 1993-08-13
- path: `sys/msdosfs/`

The NetBSD commit message describes bringing in fixed/renamed MS-DOS filesystem code from Jeff Polk, with notes dated 1993-07-22 that the package was renamed from PCFS to MSDOSFS.

The source files themselves retain the earlier origin notice:
- written by Paul Popelka;
- dated October 1992;
- redistribution notice retained in each file.

Pinned files useful here:
- `msdosfs_fat.c` — blob `4a84bd09715666029fc76cf3fadd7871303fb158`
- `fat.h` — blob `23636cfd1646353831f3ebbcaeaff5f91889d15b`
- `msdosfs_vfsops.c` — blob `89f350fc1ba837640830b7d1199c31f1ca20a2d0`
- `msdosfs_vnops.c` — blob `95e662d01ba7271980cc66e8658fc60d491b1bac`

## Read first

The 1993 `msdosfs_fat.c` is valuable because the basic FAT operations are unusually exposed:
- `clusteralloc` — find and allocate one free cluster;
- `clusterfree` / `freeclusterchain` — release allocation;
- `fatentry` — get/set one FAT entry;
- `updateotherfats` — propagate a changed FAT block to the other FAT copies;
- `pcbmap` — walk a file's cluster chain and map logical clusters.

Later BSD descendants add operations such as `chainalloc` and `chainlength`; do not project those later interfaces backward into this 1993 file. Use the FreeBSD, NetBSD, and OpenBSD reference folders for the later lineage.

## Appendfat comparison

```text
ordinary FAT allocation
        ↓
allocate cluster / set FAT entry
        ↓
update all FAT copies
        ↓
link file chain
```

This is useful for seeing the minimum on-disk mutation without the surrounding machinery of a modern kernel. For contiguous-run allocation, compare the later BSD descendants separately rather than attributing that API to this historical snapshot.

## Provenance and license boundary

Do not vendor this source merely because the historical notice is permissive. If any code is promoted into production, review the exact pinned file's notices and lineage at that time and preserve them verbatim. This reference is evidence about implementation history and mechanism, not automatic license clearance for derivative production code.
