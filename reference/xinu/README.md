# Xinu

Canonical Embedded Xinu source:
- https://github.com/xinu-os/xinu

Useful directories:
- `device/` — explicit device-driver boundary.
- `system/` — small kernel services.
- `include/` — device and kernel interfaces.
- `test/` — compact acceptance tests.

For filesystem history, older Comer Xinu distributions are also worth inspecting because some include a small local filesystem. Keep those historical editions separate from Embedded Xinu.

Appendfat lesson:

```text
filesystem policy
    ↓
small device interface
    ↓
sector/block driver
```

Xinu is not a FAT reference. It is useful because its device abstraction is unusually readable and because old Xinu source keeps the complete system small enough to trace.