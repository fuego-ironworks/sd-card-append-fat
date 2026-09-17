# Pinned-Linux QEMU FAT image equivalence

This gate checks that the identity-only appendfat derivative still behaves like ordinary FAT for a small cross-mount fixture before any append-specific allocation policy is introduced.

## Kernel boundary

- upstream: `https://github.com/torvalds/linux.git`
- exact commit: `238650ef6c7c7cca08e032527329424c9fbd70e5`
- stock filesystems: Linux `vfat` / `msdos`
- derivative filesystems: `appendfat` / `appendmsdos`

The harness refuses a different Linux commit.

## Round trip

`tests/qemu-fat-equivalence.sh` builds one kernel with stock FAT and appendfat built in, creates a fresh 64 MiB FAT32 image, boots that kernel under QEMU, and gives the image to the guest as a virtio block device.

Inside the guest:

1. stock `vfat` mounts the image and creates a long filename, a directory, and file data;
2. `appendfat` mounts the same image, verifies the stock-created objects, appends to the existing long-name file, and creates another file and directory;
3. stock `vfat` mounts the same image again and verifies the appendfat-created and appendfat-modified data;
4. the guest emits `APPENDFAT_QEMU_EQUIVALENCE_PASS` only after the stock remount succeeds.

After the guest round trip, the host runs `fsck.fat -n -v` against the resulting image.

## First accepted probe

GitHub Actions run `35239588723` completed this sequence successfully on 2026-09-17: the combined kernel built, the guest reached the equivalence sentinel, and the final host `fsck.fat -n -v` step completed successfully.

The durable workflow re-runs the same boundary rather than treating that one run as permanent evidence.

## What this accepts

This gate establishes, for the exact pinned upstream Linux kernel and this fixture, that stock `vfat` and built-in `appendfat` can coexist in one booted kernel and can round-trip ordinary FAT32 file, directory, long-filename, and file-data changes through the same image. It also establishes that `fsck.fat -n -v` accepts the resulting image in the tested run.

## What this does not accept

It does not establish:

- loadable `.ko` module loading/unloading behavior;
- append-arena allocation semantics, because none are implemented yet;
- crash or power-loss correctness;
- every FAT12/FAT16/FAT32 feature or mount option;
- Android common-kernel, vendor-kernel, or exact-phone compatibility;
- physical SD-card behavior, controller behavior, flash translation behavior, or removal/reinsertion behavior.

Those remain separate gates. QEMU evidence must not be promoted to physical-device evidence.
