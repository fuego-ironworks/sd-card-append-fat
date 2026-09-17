# µC/OS-II

Current custodian/source repository:
- https://github.com/weston-embedded/uC-OS2

The current repository is Apache-2.0, but older book/distribution editions had different licensing. Treat each version separately.

Read for style and embedded boundaries rather than FAT allocation:
- `Source/` — small deterministic kernel core.
- `Ports/` — processor-specific boundary.
- configuration templates — compile-time feature selection.

Related Micrium products included a filesystem, but do not assume µC/OS-II kernel source itself contains the FAT implementation.

Appendfat lesson:

```text
small stable core
+ explicit architecture-specific port
+ compile-time configuration
```

That is a useful model for keeping append logic separate from Linux/Android integration glue.