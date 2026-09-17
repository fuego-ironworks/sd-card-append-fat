# OpenBSD msdosfs

Upstream:
- https://github.com/openbsd/src
- inspect `sys/msdosfs/` in the pinned source revision.

Read the FAT implementation, mount operations, vnode operations, and the mount/data structures together.

Why it is here: OpenBSD gives another independently maintained descendant of the old BSD msdosfs implementation. Differences among FreeBSD, NetBSD, and OpenBSD are useful evidence for which pieces are fundamental FAT invariants and which are kernel-local policy.

Example comparison table to build later:

```text
operation           FreeBSD   NetBSD   OpenBSD
FAT entry update       ?         ?         ?
chain allocation       ?         ?         ?
free-space hint        ?         ?         ?
FAT copy update        ?         ?         ?
sync ordering          ?         ?         ?
```

Fill this table from pinned revisions rather than assumptions.