# Append arena design boundary

This note defines the first append-oriented experiment without yet changing allocation semantics.

The goal is to reduce repeated metadata mutation during sustained append workloads while preserving an ordinary FAT on-disk format and keeping stock FAT able to inspect the same volume.

## What the pinned baseline already provides

The identity-only appendfat source still has Linux FAT's existing preallocation path.

### Logical size is already separate from allocated capacity

`fat_fallocate(..., FALLOC_FL_KEEP_SIZE, ...)` allocates clusters without expanding `i_size`. Its keep-size branch compares the requested end against `inode->i_blocks`, computes additional clusters, and calls `appendfat_add_cluster()` until the requested allocated capacity exists.

`struct msdos_inode_info::mmu_private` is explicitly the physically allocated size used on the allocation path.

This means appendfat does not need a new on-disk metadata format merely to represent capacity beyond logical EOF.

### Writes can consume already allocated clusters

`__fat_get_block()` computes `last_block` from `inode->i_blocks`. At a cluster boundary it calls `appendfat_add_cluster()` only when the requested block is not already inside that allocated region. A write progressing through preallocated blocks therefore maps the existing FAT chain rather than extending it again.

This is the key existing mechanism to test before inventing a second reservation scheme.

### The allocator already has a multi-cluster interface

`appendfat_alloc_clusters(inode, cluster, nr_cluster)` can allocate more than one cluster in one call, subject to its fixed `MAX_BUF_PER_PAGE / 2` limit. It chains the selected free FAT entries as it scans them, updates free-space accounting, mirrors changed FAT buffers, and unwinds through the first allocated cluster on failure.

Important: this is **not a physical-contiguity guarantee**. The scan may skip occupied entries. Do not call a set of clusters returned by this function a contiguous run unless a later allocator explicitly proves adjacency.

`appendfat_chain_add(inode, first_cluster, nr_cluster)` can attach a prepared chain to the file and account the full `nr_cluster` in `i_blocks`.

### Current keep-size preallocation is deliberately unbatched

The current `fat_fallocate()` keep-size loop repeatedly calls `appendfat_add_cluster()`. `appendfat_add_cluster()` itself allocates exactly one cluster and then links it to the file.

So there is a concrete optimization seam: the filesystem already knows how to represent preallocated capacity, while the existing path performs that reservation one cluster at a time.


## Source trail and higher-level storage intent

Keep the layers visible rather than treating "fallocate" as one monolithic operation.

Useful source trail:

- util-linux command: `sys-utils/fallocate.c`
  <https://github.com/util-linux/util-linux/blob/master/sys-utils/fallocate.c>
- glibc Linux wrapper:
  <https://github.com/bminor/glibc/blob/master/sysdeps/unix/sysv/linux/fallocate.c>
- Linux VFS dispatch in `fs/open.c`:
  <https://github.com/torvalds/linux/blob/master/fs/open.c>
- Linux FAT implementation in `fs/fat/file.c`:
  <https://github.com/torvalds/linux/blob/master/fs/fat/file.c>

For this project, the interesting semantic boundary is not the command-line spelling. A higher-level program may want to state something like:

```text
store this append log
reserve backing space ahead of writes
keep its visible length unchanged until bytes are written
prefer sequential allocation
```

Those are storage requirements or preferences. They should not force the source language to name `fallocate`, libc, a syscall number, FAT, or `appendfat_add_cluster()`.

A later architecture/lowering layer may choose:

- Linux `fallocate(..., FALLOC_FL_KEEP_SIZE)`;
- an appendfat-specific reservation operation;
- another filesystem primitive on another target;
- or an explicit unsupported result when the target cannot preserve the requested semantics.

Keep requirements separate from preferences. "Must keep visible length unchanged" and "prefer sequential allocation" need not have the same failure behavior.

Capability also depends on the access path. A filesystem or kernel may implement the primitive while a mediated Android/FUSE-style path rejects it before that implementation is reached. Record the filesystem, mount/interface, kernel, and device facts separately.

Finally, cluster allocation is a filesystem-level claim. It does not by itself prove physical NAND placement, erase-block placement, or physical contiguity behind a flash translation layer.

This same example is mirrored into the Idriç/Adriç design notes and the ComputerScience architecture-search notes so the high-level intent, planner choice, and concrete filesystem experiment remain cross-linked rather than existing only in conversation.

## Terms

Use these terms precisely:

- **logical size** — `i_size`, the byte length visible as file contents;
- **allocated capacity** — clusters already linked to the file, reflected by `i_blocks`;
- **reservation** — allocated capacity beyond current logical EOF;
- **append arena** — a policy-managed reservation for future appends;
- **contiguous run** — only clusters whose disk cluster numbers are consecutive; ordinary multi-cluster allocation does not imply this.

The first append-arena work does not require a contiguous run.

## Evidence required before the first semantic change

Before changing the allocator, extend the pinned-Linux QEMU fixture to characterize stock keep-size preallocation itself.

At minimum exercise:

1. create an ordinary FAT32 image;
2. mount it with appendfat;
3. create a regular file and write a known prefix;
4. reserve additional capacity with `FALLOC_FL_KEEP_SIZE`;
5. verify logical file size did not grow;
6. append data that fits entirely inside the reservation;
7. unmount and remount with stock `vfat`;
8. verify exact size and contents;
9. run `fsck.fat -n -v` on the resulting image.

Add edge fixtures for:

- zero-length file with a reservation;
- reservation followed by only a partial append;
- reservation extending across multiple clusters;
- close/unmount with unused reserved clusters still present;
- truncate after reservation;
- ENOSPC during reservation;
- remount by stock `vfat` before any append consumes the reservation.

Do not assume `fsck.fat` or non-Linux FAT implementations accept a cluster chain longer than logical file size merely because Linux exposes `FALLOC_FL_KEEP_SIZE`; measure it.

## First semantic candidate: batch explicit reservations

If the compatibility fixture is green, the smallest implementation experiment is to change only the explicit keep-size preallocation path:

```text
requested reservation
        ↓
compute clusters still needed
        ↓
allocate a bounded batch with appendfat_alloc_clusters(..., count)
        ↓
attach that prepared chain once with appendfat_chain_add(..., count)
        ↓
repeat only if the reservation exceeds the allocator's bounded batch size
```

This should be evaluated before automatic reserve-ahead behavior.

The intended invariant is semantic equivalence with the existing `FALLOC_FL_KEEP_SIZE` interface: same logical size, same ordinary FAT chain representation, same error behavior unless a difference is explicitly justified.

Do not claim fewer physical writes merely from fewer function calls. Count metadata buffers or block-device writes in the experiment.

## Metadata that reservation does and does not avoid

A reservation still mutates metadata when it is created:

- FAT entries for the reserved chain;
- mirrored FAT copies;
- free-cluster accounting / FAT32 FSINFO state;
- the file's starting cluster if it was previously empty;
- in-memory allocated-block accounting.

Once the reservation exists, an append inside it can avoid FAT-chain extension at that moment. It does **not** automatically eliminate:

- data-sector writes;
- directory-entry file-size updates;
- timestamp/archive-bit updates;
- writeback or flushes required by sync semantics.

Those costs must be measured separately. The project should optimize the writes that actually dominate on the target medium rather than treating all metadata writes as interchangeable.

## Automatic reserve-ahead is a later policy

Automatic allocation when a writer reaches the end of the current reservation changes space consumption and failure behavior. Keep it separate from the batching experiment.

A later policy must specify at least:

- initial reservation size;
- refill threshold;
- refill size or growth rule;
- maximum unused reservation per file;
- free-space floor where reserve-ahead is reduced or disabled;
- behavior on ENOSPC;
- truncate/unlink behavior;
- whether a mount option enables the policy;
- whether reservations survive close/reopen and unmount/remount.

Do not hide such policy in a generic cluster allocator.

## Crash boundaries to exercise before production acceptance

Once reservation semantics change, generate explicit cut points around:

1. FAT entries for a new reserved chain written, before linking it to the file;
2. file's old tail linked to the new chain;
3. FAT mirrors only partially updated;
4. FAT32 FSINFO update before/after FAT update;
5. data written into a reserved cluster before directory size update;
6. directory size updated before a later data flush;
7. truncate/free of unused reservation interrupted partway through.

For each fixture, record what stock `vfat`, appendfat, and `fsck.fat` observe. A clean normal-operation QEMU run is not crash-safety evidence.

## Acceptance sequence

1. **Characterize existing keep-size reservation** under QEMU and stock remount.
2. **Instrument metadata writes** for unreserved append versus reserved append.
3. **Batch explicit reservation only**, keeping the user-visible `fallocate` semantics unchanged.
4. Re-run stock-remount, `fsck.fat`, truncation, ENOSPC, and crash-cut fixtures.
5. Only then consider an automatic append-arena policy.
6. Reconcile the accepted design into the exact Android/vendor kernel separately.
7. Physical SD-card testing remains a distinct final evidence layer.

The first implementation change should be driven by these measurements, not by the assumption that contiguous allocation or a new on-disk structure is inherently required.
