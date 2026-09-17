# SkyOS

Historical project by Robert Szeleney.

SkyOS itself is primarily a historical/reference target rather than a source tree to vendor here. Contemporary descriptions say its VFS supported FAT12/16/32, ISO9660, and virtual filesystems, and that OpenBFS was ported and developed into SkyFS as its primary filesystem.

Useful external reference:
- OpenBFS / Be File System lineage, because that is where the interesting filesystem implementation came from.

Why it belongs here:
- a small independently developed OS with a VFS supporting multiple filesystem implementations;
- direct historical FAT12/16/32 support;
- an example of replacing/adapting the preferred filesystem without making the VFS itself filesystem-specific.

Appendfat comparison:

```text
VFS
├── FAT
├── appendfat      ← separate identity
└── other FS
```

That is the same isolation rule we want in Linux: stock FAT remains present while appendfat is independently selectable.

Do not import SkyOS code unless an exact legally redistributable source release is identified.