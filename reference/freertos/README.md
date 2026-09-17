# FreeRTOS / FreeRTOS+FAT

FreeRTOS kernel itself does not define FAT semantics; the relevant companion is FreeRTOS+FAT.

References:
- https://www.freertos.org/FreeRTOS-Plus/FreeRTOS_Plus_FAT/
- community/reference ports expose the same disk object and sector read/write boundary.

Study:
- disk/media initialization;
- partition and mount boundary;
- sector cache sizing;
- removable-media insertion/removal;
- blocking versus asynchronous storage drivers.

Append logger example:

```text
insert card
mount
reserve arena
repeat:
    append one record
    checkpoint only at selected boundaries
on removal/error:
    stop issuing writes
```

This folder is mainly for embedded storage integration patterns; FatFs and NuttX are stronger references for the FAT allocator itself.