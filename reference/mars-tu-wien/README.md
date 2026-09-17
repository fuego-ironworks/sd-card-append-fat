# MARS — Maintainable Real-Time System

Candidate for the remembered operating system developed in Vienna.

MARS was a distributed hard-real-time system associated with Hermann Kopetz and Technische Universität Wien. The second academic prototype was operating in Vienna by 1988; contemporary papers describe a kernel designed for predictable hard-real-time task execution and communication.

Primary paper to locate:
- Andreas Damm et al., "The Real-Time Operating System of MARS," ACM SIGOPS Operating Systems Review 23(3), 1989, pp. 141–157.

Relevant ideas rather than FAT code:
- time-triggered operation;
- statically planned execution and communication;
- predictable behavior at specified peak load;
- explicit timing/commit schedules.

Appendfat thought experiment:

```text
record production period
        ↓
known append/checkpoint schedule
        ↓
data-sector writes
        ↓
less-frequent metadata checkpoint
```

This is not currently a source-code reference and should not be treated as one. Keep it for deterministic scheduling/crash-boundary ideas unless a redistributable MARS source tree is found.