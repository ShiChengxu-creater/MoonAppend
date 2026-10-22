# Changes

## 0.3.0 — source candidate, unpublished

- Native `DiskLog::backup` and CLI `backup`: audit the complete source, copy only
  committed data in bounded chunks, and commit the new checkpoint last. Reopen
  the copy using the normal API; it retains historical proofs and appends independently.
- Existing destinations and corrupt sources are refused. Five backup failure
  boundaries test partial-copy rejection and continued source usability.
- Record JSON decoding now enforces the encoder's aggregate raw-byte budget
  before allocating the next entry. Exact-limit and limit-plus-one regressions
  run on all three portable targets.
- Add cross-process backup checks with 18 MiB payloads, a Windows native CI job,
  and a final acceptance evidence index. Native disk format remains MADL/1.

## 0.2.0 — published 2026-10-21

- Add native durable log files, checkpoint recovery, OS single-writer locks,
  random reads and full audits.
- Add batch append, mergeable compact ranges and resumable checkpoints,
  shared interval proofs and storage-reader callbacks.
- Add strict JSON interchange and native CLI workflows.
- Verify Python/Go interoperability, real process-kill recovery and scale;
  independently install the exact Mooncakes version on all three supported targets.

## 0.1.0-alpha.1 — published 2026-10-19

- Bounded memory-only Merkle log with historical snapshots, RFC 9162 inclusion
  and consistency proofs and three-target reference validation.
