# Explicit keep-size batching measurement

## Result

The QEMU comparison supports a narrow conclusion: batching reduces allocator
invocations, allocator/attachment FAT-buffer references, and FSINFO dirty
notifications. It did not reduce the number of FAT-entry updates or the
guest-visible virtio writes in the representative 17-cluster reservation.
For the measured two-FAT FAT32 image, the latter stayed at four write
operations and four sectors after `sync()` in both versions.

This is metadata-work evidence from the pinned QEMU guest. The block counters
are guest-visible virtio block statistics; they do not attribute writes to
individual FAT copies at the host device, and they do not predict SD-card or
NAND behavior.

## Representative FAT32 workload

The static helper creates a zero-length file, reserves one cluster, then
extends it to 17 clusters. This exercises the old one-cluster path and four
additional-cluster batches; the allocator's `MAX_BUF_PER_PAGE / 2` bound is
four clusters in this QEMU 4 KiB page build. The cluster size is 512 bytes. A
second operation extends the same chain from 17
to 19 clusters; a third repeats the 19-cluster request without adding space.
The helper checks that `i_size` remains zero and that `st_blocks` matches the
requested capacity. It snapshots `/sys/block/vda/stat` around each operation
and calls `sync()` at both boundaries.

The entry-update, buffer-reference, and mirror counters below sum the single
cluster allocation events and the tail-link updates recorded for the
representative reservation. FAT-buffer figures are sums of per-call unique
buffers collected by the allocator or attachment operation; they are not a
global count of unique physical FAT sectors across the whole workload.

| Workload | Path | Allocator calls | Chain attachments | FAT entry updates | FAT buffer references | Mirror buffer copies | FSINFO dirty calls | virtio writes / sectors |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 1 to 17 clusters | Baseline | 17 | 17 | 33 | 33 | 33 | 17 | 4 / 4 |
| 1 to 17 clusters | Batched | 5 | 5 | 33 | 9 | 9 | 5 | 4 / 4 |
| 17 to 19 clusters | Baseline | 2 | 2 | 4 | 4 | 4 | 2 | 3 / 3 |
| 17 to 19 clusters | Batched | 1 | 1 | 4 | 2 | 2 | 1 | 3 / 3 |
| Repeat 19 clusters | Either | 0 | 0 | 0 | 0 | 0 | 0 | 0 / 0 |

The `fat_updates` allocator counter counts `ent_put()` calls while building
the allocated chain. `tail_link` counts the separate update attaching that
chain to the file's old tail. Batching combines fewer buffers and FSINFO
notifications but still has to create the same FAT chain links: the measured
33 updates for the first reservation and four for the extension did not
change. In this workload, writeback coalescing also meant those metadata
reductions did not lower observed virtio writes.

The test-only `APPENDFAT_ALLOC_METRICS` instrumentation is compiled only when
`APPENDFAT_ALLOC_METRICS=1` is exported by the keep-size test script. Per-inode
counters are enabled only for reservations needing at most 64 additional
clusters, so the 1 GiB ENOSPC request does not emit per-cluster log noise. The
instrumentation counts allocator requests/results, allocator FAT-entry
updates and collected buffers, mirrored buffer copies, FSINFO dirty calls,
chain attachments, and tail-link buffers. It does not change allocation
decisions.

## Semantic and compatibility receipts

- The batched 17-cluster operation reported `size=0`, `blocks=17`; extension
  reported `size=0`, `blocks=19`; repeating the same request allocated nothing.
- The FAT16 ENOSPC fixture returned ENOSPC and reported
  `enospc_partial_blocks=65372` while the file size remained zero. This
  preserves the previous interface behavior: clusters successfully attached
  before the request runs out of space remain allocated even though the
  request returns ENOSPC. After stock-vfat remount and unlink, `fsck.fat`
  reported no allocated clusters, so the exercised failing batch and cleanup
  left no leaked chain.
- The keep-size fixture passed, including the zero-length file, nonempty file,
  one-cluster and multi-batch reservation, partial/full consumption, truncate,
  unlink, repeated/overlapping requests, stock `vfat` remount, and host
  `fsck.fat -n -v` checks. The FAT-width matrix reserved capacity on FAT12,
  FAT16, and FAT32 and passed its stock-remount and `fsck.fat -n -v` checks.
- The separate characterization still shows that unused keep-size allocation
  is not preserved across a clean unmount/remount boundary: in the live
  appendfat mount the six-byte file used 512 512-byte blocks and the empty file
  used 256; after stock `vfat` remount they used one block and zero blocks.
  `fsck.fat -n -v` returned status 0 at each accepted clean boundary. Batching
  does not add a persistence semantic.

## Reproduction and provenance

Both comparison runs used the same pinned upstream Linux source commit:
`238650ef6c7c7cca08e032527329424c9fbd70e5`. The script verifies that exact
revision before applying the appendfat source. The source branch was based on
`main` at `001e5e8a84ffed711eccb356877bd02de7563c1c`.

The one-cluster baseline keep-size workflow used branch commit
`832ad483bbe8c1b1fdbf62a00e841b87a326c628`; GitHub Actions checked out its
synthetic PR merge tree `490995942eb796cc1f7e2f927f15bba2b361c0d0` (run
[36465757164](https://github.com/fuego-ironworks/sd-card-append-fat/actions/runs/36465757164)).
The batched implementation used branch commit
`ae2e5f1a9799e3983f430b8e09ffb42b6505d24d`; GitHub Actions checked out its
synthetic PR merge tree `ee5088f366709a2d4569d7ce010734e2cbe4e0ef` (run
[36467418914](https://github.com/fuego-ironworks/sd-card-append-fat/actions/runs/36467418914)).
Both ran `sh tests/qemu-keep-size.sh linux`, which also runs
`sh tests/qemu-keep-size-characterization.sh linux` and the post-phase host
`fsck.fat -n -v` checks.

From the repository root, with the pinned Linux checkout in `linux`, reproduce
the workload with:

```sh
APPENDFAT_ALLOC_METRICS=1 sh tests/qemu-keep-size.sh linux
```

The normal script invocation itself enables the same compile-time metric flag.
To rerun the other compatibility gates against the same pinned checkout, use:

```sh
sh tests/qemu-fat-matrix.sh linux
sh tests/qemu-module-load.sh linux
sh tests/qemu-fat-equivalence.sh linux
sh tests/qemu-power-cut.sh linux
```

These workflows passed on the batched implementation commit:

- [FAT-width matrix run 36467419029](https://github.com/fuego-ironworks/sd-card-append-fat/actions/runs/36467419029)
- [Module load/unload/reload run 36467418932](https://github.com/fuego-ironworks/sd-card-append-fat/actions/runs/36467418932)
- [FAT image equivalence run 36467418957](https://github.com/fuego-ironworks/sd-card-append-fat/actions/runs/36467418957)
- [Abrupt power-cut regression run 36467418915](https://github.com/fuego-ironworks/sd-card-append-fat/actions/runs/36467418915)

The power-cut result is only the repository's existing synced-write regression
boundary. It is not a general crash-safety claim for reservation batching.
