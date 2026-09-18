# `appendfat_mv` versus the alternatives

This note compares the small userspace mover in `tools/appendfat_mv.c` with the other approaches already represented in this repository.

The important point is that these approaches solve different problems. They should not be collapsed into one question such as “which `mv` is best?”

There are at least four separate questions:

1. **How should an ordinary file move behave?**
2. **Can destination allocation be established before the data copy starts?**
3. **Can later appends consume already allocated FAT clusters instead of repeatedly extending the FAT chain?**
4. **Can software control where the SD card physically places NAND writes?**

`appendfat_mv` is mainly an experiment for questions 2 and, indirectly, 3. It does not solve question 4.

## Short comparison

| Approach | Normal file at the end | Allocation before data copy | Works through current stock-phone FUSE path | Requires custom reader/state | Where policy lives |
| --- | --- | --- | --- | --- | --- |
| ordinary `mv` / ordinary cross-filesystem copy | yes | not guaranteed | yes | no | generic userspace |
| `appendfat_mv` | yes | yes, with `FALLOC_FL_KEEP_SIZE` | **no on the current phone probe** | no | small userspace tool + filesystem support |
| shell composition with `fallocate` + copy + remove | potentially | potentially | no on the current phone probe | no | shell plus multiple utilities |
| pre-zeroed `appendfat_arena` | no: visible file size is full capacity | effectively paid up front by writing zeros | expected to use only ordinary writes | **yes**, `.used` is authoritative | userspace arena format |
| kernel `appendfat` reservation policy | yes | yes | only after an actual appendfat mount exists | no | filesystem/kernel |
| FatFs-style pre-expansion | yes within that filesystem API | yes | not a drop-in Android filesystem path | no extra sidecar in the basic model | embedded FAT implementation |
| direct FAT/block editing | only if implemented correctly | complete low-level FAT control | generally inappropriate through mounted Android storage | usually yes/custom | raw filesystem/block layer |

The current project therefore has two deliberately different userspace experiments:

- `appendfat_mv`: preserve ordinary-file semantics, but require keep-size allocation support;
- `appendfat_arena`: work without keep-size support, but give up ordinary EOF semantics and maintain a separate logical length.

The kernel work is a third layer rather than another spelling of either userspace program.

## 1. Ordinary `mv`

For a move within one filesystem, the correct baseline is still a rename.

That is exactly what `appendfat_mv` does first:

~~~text
rename(source, destination)
~~~

If that succeeds, there is no reason to copy file data merely to exercise allocation policy. Rewriting a same-filesystem file would create extra data writes and metadata churn while losing the principal advantage of rename.

Across filesystems, ordinary `mv` has to become conceptually:

~~~text
create destination
copy data
copy enough metadata
remove source
~~~

A generic implementation is trying to preserve broad filesystem semantics: directories, symbolic links, permissions, timestamps, extended attributes, ACLs, sparse files, overwrite rules, interactive behavior, and platform-specific details.

That generality is useful, but it does not make “allocate the complete FAT chain before the first copied byte” an invariant.

For the append-FAT experiment, ordinary cross-filesystem `mv` is therefore the compatibility baseline, not the allocation-policy test.

## 2. What `appendfat_mv` changes

The cross-filesystem path in `appendfat_mv` is intentionally narrower:

~~~text
open source regular file
        ↓
create temporary file beside final destination
        ↓
fallocate(FALLOC_FL_KEEP_SIZE, 0, source_size)
        ↓
verify visible size is still zero
        ↓
copy exactly source_size bytes
        ↓
verify source identity/size/mtime did not change
        ↓
fsync destination file
        ↓
rename temporary file into final name
        ↓
unlink source
~~~

The important experiment is the ordering:

> **reservation first, data second**

On Linux FAT, keep-size preallocation can link clusters to the inode while leaving logical EOF unchanged. Subsequent writes inside that allocated region can use the existing chain rather than extending the chain as each new cluster boundary is reached.

That is a much narrower claim than “this optimizes the SD card.”

### What the C program buys over ordinary copy

The program keeps several operations under one set of invariants:

- the temporary file is created on the final destination filesystem;
- reservation happens before data copy;
- failure of the reservation aborts the move instead of silently falling back;
- the destination is not exposed under the final name until copied data has been synced;
- the source is not removed until after final-name installation;
- the copy length is snapshotted before copying;
- a changed source size or modification time aborts source removal;
- the 32-bit ARM build uses 64-bit file offsets.

That makes it useful as an acceptance harness for filesystem behavior.

### What it deliberately does not implement

It is not a GNU-`mv` replacement. The cross-filesystem path currently excludes or only partially handles:

- directories;
- symbolic links;
- ownership;
- ACLs;
- extended attributes;
- hard-link topology;
- sparse-file preservation;
- interactive overwrite policy;
- complete metadata-error handling.

In particular, `fchmod()` and `futimens()` are currently best-effort in the implementation: their return values are ignored.

That is acceptable for a narrow allocation experiment only if the limitation remains explicit.

## 3. Why not just run `fallocate`, then `cp`, then `rm`?

At first sight the C program looks like something the shell can already express:

~~~sh
fallocate --keep-size --length "$size" destination
cp source destination
rm source
~~~

That simple sequence is not equivalent.

The central problem is that the copy program controls how it opens the destination. A normal copy implementation may truncate or replace the destination before writing. If it does, the preallocation performed by the earlier `fallocate` command can be discarded or changed before the copy begins.

A shell version therefore has to specify much more carefully:

1. create the destination without replacing it later;
2. reserve it;
3. copy through an already-open or explicitly non-truncating destination;
4. detect short reads and writes;
5. handle interruption;
6. sync before publishing;
7. publish atomically when possible;
8. remove the source only after successful publication;
9. clean temporary files on error.

One can build that from `fallocate`, `dd`, file-descriptor redirections, `mv`, `sync`, and careful traps. At that point the shell script is implementing a small transaction protocol.

The C program is useful because the file descriptors and ordering are explicit and testable in one process.

This does **not** mean C is inherently superior. It means the experiment is about a stateful sequence of filesystem calls, and representing that state explicitly is useful.

## 4. Why ordinary `fallocate` and `ftruncate` are not substitutes

There are two different ideas that are easy to conflate:

~~~text
allocate storage and extend logical EOF
~~~

versus:

~~~text
allocate storage beyond logical EOF while preserving visible size
~~~

`appendfat_mv` requires the second behavior.

A normal allocation that grows the file to the full source size before copying creates an immediately visible destination containing unwritten or zero-filled logical data. That changes publication and failure semantics.

Similarly, `ftruncate()` changes logical size and, depending on the filesystem, may create a sparse logical range without allocating all storage.

The keep-size interface is valuable precisely because **logical size and allocated capacity remain separate**.

That separation is also the mechanism discussed in `docs/append-arena-design.md` for the kernel implementation.

## 5. The current stock-phone result

The physical-phone probe retained in `docs/phone-keep-size-probe-2026-09-18.md` is decisive for the current stock path.

Through the Termux removable-storage view, both keep-size fallocate and ordinary fallocate returned:

~~~text
EOPNOTSUPP
~~~

The path is mediated by Android's storage/FUSE layer, and the card is currently exFAT.

So on the phone as it exists today:

~~~text
appendfat_mv reservation
        ↓
EOPNOTSUPP
        ↓
fail before copy
        ↓
source remains untouched
~~~

That is the intended result.

It means `appendfat_mv` is presently useful for:

- Linux/QEMU appendfat testing;
- any filesystem path that really exposes keep-size fallocate;
- a later physical appendfat mount on the phone, after the same probe is rerun.

It is **not** presently a way around the stock Android removable-storage boundary.

## 6. The pre-zeroed userspace arena

`tools/appendfat_arena.c` attacks the stock-phone constraint from the opposite direction.

Instead of asking the filesystem to maintain:

~~~text
logical_size < allocated_capacity
~~~

it creates an ordinary file whose visible size is already the full capacity:

~~~text
visible_size = allocated_capacity
~~~

It then stores the application-visible logical end separately:

~~~text
arena.used = logical_used_length
~~~

Creation explicitly writes zeros over the whole arena. Later appends use `pwrite()` inside the existing visible file instead of extending EOF.

### Strengths

This uses ordinary operations that are more likely to survive an Android FUSE/storage boundary:

- create;
- write;
- `pwrite`;
- `fsync`;
- rename.

It does not require fallocate support.

For a workload that can tolerate a private arena representation, it directly tests the hypothesis:

> Pay allocation/growth cost once, then perform later logical appends without extending the large file.

### Costs

The arena is not an ordinary file with ordinary EOF semantics.

A program that opens `cache.arena` sees the whole capacity, including trailing zero space. It must understand `cache.arena.used`, or data must be exported through `appendfat_arena dump`.

Creation also writes every byte of the arena once. That is a real data-write cost, unlike keep-size reservation, which can allocate filesystem metadata without writing the eventual user data first.

So the arena exchanges compatibility and an initial write cost for wider applicability on the current phone.

### A useful implementation difference

The arena code currently performs a directory `fsync` after atomically replacing its `.used` pointer.

The first `appendfat_mv` implementation syncs the destination file before its final rename, but it does **not** yet sync the destination directory after the rename or the source directory after unlinking the source.

That means the arena currently has a stronger explicit directory-durability step for its metadata commit.

For a more durability-conscious mover, the next revision of `appendfat_mv` should consider:

~~~text
fsync(destination file)
rename(temp, destination)
fsync(destination parent)
unlink(source)
fsync(source parent)
~~~

with careful handling when source and destination parents are the same directory.

That still would not provide crash guarantees stronger than the mounted filesystem, but it would make the intended ordering more explicit.

## 7. Kernel appendfat: where the real policy belongs

The userspace mover can request reservation, but it cannot choose the FAT allocator's detailed behavior.

The kernel appendfat work can.

The current design note identifies the important existing Linux FAT mechanisms:

- allocated capacity is represented separately from logical `i_size`;
- keep-size fallocate already creates capacity beyond EOF;
- writes can consume clusters already linked to the file;
- the FAT allocator already has a multi-cluster allocation interface;
- the current keep-size loop nevertheless grows reservation one cluster at a time.

This gives a clean kernel optimization seam:

~~~text
userspace requests reservation
        ↓
appendfat computes clusters required
        ↓
allocator obtains a bounded batch
        ↓
prepared chain is attached in a batch
        ↓
later writes consume the existing chain
~~~

That is qualitatively different from `appendfat_mv`.

`appendfat_mv` says **when** to request allocation relative to the copy.

Kernel appendfat decides **how** that allocation is implemented inside FAT.

Longer-term automatic reserve-ahead policy also belongs there because it changes free-space consumption and ENOSPC behavior for every writer, not just one copy command.

## 8. FatFs and pre-expansion

The Elm-Chan FatFs reference is valuable because it exposes the same idea in a much smaller implementation than Linux.

The repository's FatFs note highlights:

- FAT-entry update;
- cluster-chain creation/extension;
- a narrow block-device interface;
- explicit synchronization;
- file pre-expansion through `f_expand` where configured.

Conceptually, FatFs makes the append experiment easy to state:

~~~text
pre-expand capacity
keep logical used length
write within allocated range
checkpoint logical length
~~~

That is extremely close to what this project is trying to reason about.

The difference is integration.

FatFs is appropriate when the program or embedded system owns the filesystem stack or has direct access to the medium. Android applications normally do not replace the mounted removable-storage filesystem with an embedded FAT library just to move one file.

So FatFs is currently more useful as:

- an algorithmic comparison;
- a small readable source of FAT behavior;
- a possible test model;
- a source of ideas about pre-expansion and explicit block-I/O boundaries.

It is not a drop-in replacement for `appendfat_mv` on the phone.

## 9. dosfstools: oracle, not mover

The `dosfstools` reference solves another distinct problem.

`mkfs.fat` constructs a valid filesystem and `fsck.fat` validates or repairs on-disk structures. That makes it useful after allocation experiments:

~~~text
construct image
mount stock FAT
mount appendfat
perform reservation/write experiment
unmount
fsck.fat
remount stock FAT
verify contents
~~~

This is an external validity oracle.

It would be a mistake to turn a mounted-file move into userspace direct editing of FAT tables just because dosfstools contains code that understands the format. Mounted kernel state, caches, directory updates, and FAT mirrors must remain coherent.

The repository should continue to treat dosfstools primarily as an on-disk checker rather than a production write path.

## 10. Direct FAT-sector manipulation

A still lower-level alternative would be to bypass normal file APIs and directly alter FAT entries and data sectors.

That gives more control over FAT cluster numbers, but it introduces several problems:

- the filesystem must not be concurrently mounted in the ordinary way;
- free-space accounting must remain coherent;
- FAT mirrors must remain coherent;
- directory entries must be committed correctly;
- crash ordering becomes the program's responsibility;
- Android may not permit access to the relevant block device;
- raw FAT cluster placement is still not raw NAND placement.

The last point matters.

Even if software selects exact logical sectors on the SD block device, the card's flash-translation layer can map those sectors to NAND however it chooses.

Therefore these are distinct levels:

~~~text
file offset
    ↓
filesystem block / FAT cluster
    ↓
SD logical block address
    ↓
controller-private NAND placement
~~~

The project can control or measure the first three to varying degrees. It should not claim control over the final mapping without hardware-specific evidence.

## 11. Faster copy engines do not change the allocation question

The current mover uses an ordinary 256 KiB read/write loop.

Once reservation behavior is established, copy transport can be treated as a separate optimization. Candidate interfaces include:

- `copy_file_range`;
- `sendfile`;
- larger or adaptive buffers;
- asynchronous I/O.

None of those automatically solve the append-FAT problem.

The critical invariant remains:

~~~text
reserve destination first
        ↓
copy through the reserved destination
~~~

A faster copy engine is useful only if it preserves that boundary and behaves correctly through the relevant Android/filesystem path.

## 12. Crash and publication semantics

The approaches make different promises.

### Ordinary move within one filesystem

A rename gives the cleanest namespace operation and avoids data copying.

### `appendfat_mv`

Current ordering protects against deleting the source before the destination data file has been synced and installed. It does not yet include directory syncs around namespace changes.

It also cannot prevent every source-content race. Checking size and modification time catches common changes, but a writer could theoretically alter bytes while restoring those metadata values.

That is acceptable for the current experiment but should not be oversold as a fully race-proof general-purpose mover.

### Pre-zeroed arena

The data is written and synced first. The small logical pointer is then written to a new file, synced, renamed, and its directory synced.

If an append fails before pointer commit, the authoritative logical length remains old. Data written beyond that old logical end is uncommitted scratch space.

That is a useful transaction model for append-only application data, but only applications that understand the arena format receive those semantics.

### Kernel appendfat

Crash behavior must ultimately be tested at FAT-specific cut points: chain creation, chain attachment, FAT mirrors, FSINFO, directory-size update, truncate, and reservation freeing.

Neither userspace experiment proves those kernel crash boundaries.

## 13. Practical division of labor

The alternatives fit together rather than eliminating one another.

### On the current stock Android phone

Use the pre-zeroed arena to study repeated writes into already-grown storage, because the observed removable-storage path rejects keep-size fallocate.

`appendfat_mv` should continue to fail closed there.

### In QEMU/Linux appendfat testing

Use `appendfat_mv` as a small userspace caller that makes reservation-before-copy explicit.

Use the dedicated keep-size tests to characterize filesystem semantics independently of the mover.

Use `fsck.fat` and stock FAT remounts as external compatibility checks.

### On a future physical appendfat mount

First rerun the direct keep-size probe.

If it succeeds, run `appendfat_mv` and record:

- source size;
- reservation length;
- destination logical size immediately after reservation;
- allocated blocks or clusters if observable;
- copied data hash;
- stock-remount compatibility where possible;
- write and metadata counts where instrumentation allows.

### In the production filesystem

Put batching and automatic append-reservation policy in appendfat itself, after the existing keep-size semantics and compatibility gates are characterized.

## 14. What should be improved in `appendfat_mv` before calling it mature

The current program is good enough as a focused reservation/copy harness, but several improvements are separable from the core experiment.

### Durability

Consider syncing destination and source parent directories around final namespace changes.

### Metadata error policy

Decide whether permission and timestamp preservation are required. If required, stop ignoring `fchmod` and `futimens` failures.

### Overwrite semantics

Make replacement behavior explicit and test existing destination files, directories, and races.

### Source-change detection

The current size/mtime check is useful but not a complete snapshot guarantee. A stronger mode could hash while copying or impose a caller-level immutability assumption.

### Copy engine

Benchmark the plain read/write loop against `copy_file_range` or `sendfile` only after allocation semantics are held constant.

### Physical receipt

Do not call the tool accepted for the phone merely because it passes host or QEMU tests. The physical appendfat mount must expose the required fallocate behavior.

## 15. Bottom line

`appendfat_mv` occupies a deliberately narrow middle layer:

~~~text
ordinary mv
    │
    │ no allocation guarantee
    ▼
appendfat_mv
    │
    │ explicit keep-size reservation before copy
    ▼
kernel appendfat
    │
    │ controls FAT allocation policy itself
    ▼
block device
    │
    │ logical sectors
    ▼
SD controller / NAND
~~~

The pre-zeroed arena sits alongside that stack as a workaround for an interface that cannot express keep-size reservation.

The useful conclusions are:

1. **Keep ordinary rename for same-filesystem moves.**
2. **Use `appendfat_mv` to test reservation-before-copy where keep-size fallocate exists.**
3. **Use the pre-zeroed arena on the current stock-phone path when the goal is to experiment with writing inside already-grown storage.**
4. **Put real FAT allocation policy in appendfat, not in a bigger and bigger `mv` clone.**
5. **Use FatFs as a compact conceptual allocator reference and dosfstools as an external validity oracle.**
6. **Do not equate FAT cluster control with physical NAND placement.**

That division keeps the experiments understandable and makes each layer prove only what it actually controls.
