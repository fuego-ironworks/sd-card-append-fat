# Appendfat acceptance gates

The tests are intentionally split by evidence class. A green result in one lane
must not be promoted into a stronger lane.

## Pinned-Linux QEMU gates

### FAT image equivalence

`tests/qemu-fat-equivalence.sh` remains the small stock-vfat → appendfat →
stock-vfat FAT32 gate.

### Loadable modules

`tests/qemu-module-load.sh` builds appendfat as `.ko` modules while stock FAT is
built in. The guest:

1. proves `appendfat` is not registered before insertion;
2. loads `appendfat_core.ko`, `appendfat.ko`, and `appendmsdos.ko`;
3. mounts and modifies the image through the module-backed filesystems;
4. unloads the modules and proves the filesystem registrations disappear;
5. reloads appendfat and verifies the same data;
6. remounts with stock `vfat`;
7. leaves the resulting image for host `fsck.fat -n -v`.

This is a module load/unload/reload and coexistence gate for the pinned QEMU
kernel. It is not Android module evidence.

### FAT-width and mount-option matrix

`tests/qemu-fat-matrix.sh` exercises FAT12, FAT16, and FAT32 images through
stock `vfat`, `appendfat`, `appendmsdos`, stock `msdos`, and stock `vfat`
again. It also exercises a representative `utf8=1,shortname=mixed` mount and
a read-only appendfat mount.

This is deliberately not described as exhaustive coverage of every FAT
feature or every mount option. New options and feature-specific fixtures can
be added without changing the claim made by existing rows.

### Keep-size reservation compatibility

`tests/qemu-keep-size.sh` characterizes the existing Linux
`FALLOC_FL_KEEP_SIZE` mechanism before append-arena allocation semantics
change. It covers:

- reservation on a zero-length file;
- logical size staying unchanged after reservation;
- partial consumption of a reservation;
- a reservation spanning multiple clusters;
- close/unmount with unused reserved capacity;
- truncate after reservation;
- ENOSPC during reservation;
- stock-vfat remount after appendfat reservation;
- host `fsck.fat -n -v`.

`tests/qemu-keep-size-characterization.sh` separately pins the allocation
state at three clean boundaries: unused reservation, partial logical
consumption, and full logical consumption. In the pinned 64 MiB FAT32 fixture,
the live appendfat reservations occupy 512 and 256 512-byte blocks before
unmount. By the next stock-`vfat` mount, the unused excess is gone: the
six-byte file occupies one block and the zero-length file occupies none. The
host `fsck.fat -n -v` invocation immediately between each guest phase must
return status 0.

That means this fixture does **not** establish a persistent on-disk append
reservation across a clean unmount/remount boundary. The clean `fsck.fat`
result must not be described as evidence that stock tools accept a file chain
that remains allocated past logical EOF; the excess reservation is no longer
present by the remount check. Keep-size allocation can still be evaluated as
a mounted-session batching mechanism, but persistence requires a different
design or a separate on-disk representation.

The same fixture is intended to remain green when reservation batching is
introduced. It does not by itself prove a future automatic reserve-ahead
policy.

### Abrupt power cut after durable writes

`tests/qemu-power-cut.sh` mounts through appendfat, writes known data, explicitly
syncs it, then the host kills QEMU with `SIGKILL` before guest unmount. An
immediate read-only `fsck.fat -n -v` must observe the expected dirty bit rather
than being treated as a clean-unmount check. The unchanged image then boots
through stock `vfat`, verifies the synced data, and cleanly unmounts. Because
that mount/unmount is not assumed to normalize every on-disk crash marker, the
host then runs an explicit `fsck.fat -a -v` recovery step. A final read-only
`fsck.fat -n -v` must pass.

This establishes one abrupt-power-loss boundary: already-synced data survives
an unclean VM termination, stock `vfat` can read the dirty-but-synced image,
and an explicit filesystem-repair step returns the image to a clean state
accepted by `fsck.fat`. It does **not** claim that stock `vfat` alone clears
all crash-state metadata, nor does it claim crash correctness at arbitrary
metadata instruction points. The reservation design still requires explicit
future cut points around FAT linking, mirror updates, FSINFO, directory-size
updates, data flush ordering, and interrupted truncate/free.

## Android common and vendor kernel gate

`tests/android-kernel-compat.sh` is intentionally not a generic green CI job.
It requires:

- a checked-out Android common or vendor kernel tree;
- an exact expected commit SHA;
- an explicit Kbuild config target;
- an architecture, defaulting to `arm64`.

It refuses symbolic revisions such as `main`, copies appendfat into that exact
tree, integrates the Kconfig/Makefile entries, and attempts a module build.
A pass is source/build compatibility with that exact tree only. It is not a
boot, mount, vendor-image, or physical-phone receipt.

Android common and vendor kernels must be recorded as separate runs even if
they happen to share source.

## Exact Android device facts

`tests/android-device-facts.sh` records the build fingerprint, kernel release,
machine architecture, filesystems, relevant mounts, block-device facts, and
whether `appendfat` is registered. It is a fact receipt. It does not call a
stock phone compatible merely because source compiled elsewhere.

A true exact-phone acceptance run additionally requires a kernel actually
containing appendfat and a successful mount/data fixture on that phone.

## Physical SD-card gate

`tests/physical-sd-round-trip.sh` is a root-only, explicitly armed physical
media test. It does not format the supplied block device. It:

1. mounts the existing filesystem with stock `vfat` and writes a uniquely
   named fixture;
2. unmounts and mounts the same physical block device with appendfat;
3. verifies, appends, and creates data;
4. unmounts and remounts with stock `vfat`;
5. verifies the round trip, removes the fixture, and runs `fsck.fat -n -v`;
6. records available block-device identity and block statistics in a retained
   receipt.

The script refuses writes unless
`APPENDFAT_PHYSICAL_ACCEPT_WRITES` exactly equals the supplied block-device
path.

This is physical media-path evidence. It does not expose undocumented SD-card
controller firmware or the card's internal flash-translation layer, so it must
not be described as proving those internals correct. Removal/reinsertion and
power interruption of real media remain separate physical procedures.

## Append-arena semantic gate

The current tree intentionally has no new append-arena allocation semantics.
The first semantic change must keep the keep-size compatibility fixture green
and add tests for whatever new policy is actually implemented.

At minimum a future automatic reserve-ahead policy needs explicit tests for its
initial reservation, refill threshold and size, maximum unused reservation,
free-space floor, ENOSPC behavior, truncate/unlink behavior, enable/disable
mount option, and persistence across close/reopen and unmount/remount. Those
tests should be written against the concrete policy rather than inventing an
interface before implementation.
