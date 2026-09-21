# Physical phone keep-size probe — 2026-09-18

This receipt records the stock removable-storage boundary relevant to
`appendfat_mv`. It is not appendfat acceptance.

The target used by this historical probe was `~/storage/external-1`, which
resolves on the MIRO A1 to
`/storage/4A21-0000/Android/data/com.termux/files`. That is Termux's
app-private directory on the physical SD card, presented through Android's
FUSE storage path; it is **not** the whole-card root. The whole removable-card
root is `/storage/4A21-0000`, with the verified convenience symlink
`~/SD.card`.

The card is currently formatted as exFAT.

A 16 MiB keep-size reservation was attempted on a newly created zero-length
file:

```text
fallocate(3, FALLOC_FL_KEEP_SIZE, 0, 16777216) = -1 EOPNOTSUPP
fallocate: fallocate failed: keep size mode is unsupported
```

After the failed call the file remained logically empty and had no allocated
blocks:

```text
size=0 bytes
blocks=0
```

An ordinary `fallocate --length 16M` through the same Termux storage view also
failed at that mediated path.

## Meaning

This app-private SD-backed FUSE path cannot satisfy `appendfat_mv`'s
reservation precondition. The program must therefore fail before copying and
leave the source untouched on this path. This receipt must not be described as
whole-card-root acceptance; that requires a separate run against
`~/SD.card` / `/storage/4A21-0000`.

This result does not show that a future appendfat mount lacks keep-size support.
The pinned Linux FAT implementation and the appendfat QEMU keep-size gate are
separate evidence. Once appendfat is available on the physical device, the same
probe must be repeated against the actual appendfat mount before treating
`appendfat_mv` as usable there.
