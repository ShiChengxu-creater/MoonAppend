# Changes

## 0.3.1 — source candidate, unpublished

- Bind disk log directories to absolute paths when creating or opening them.
  Appending after the caller changes its working directory now updates the
  original checkpoint and preserves another directory's same-named log.
- Resolve new backup directories before opening their files and committing state.
- Add isolated native public API regressions for relative create/open, Unicode
  paths, historical proofs and independently writable backups. Gate them on
  Linux and Windows. Public APIs and MADL/1 storage format are unchanged.
- Require an explicit `--version` when verifying a registry release, so omitting
  it cannot silently verify the old 0.1.0-alpha.1 package.

## 0.3.0 — published 2026-10-22

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
- Install the exact Mooncakes release in a fresh consumer without a workspace
  override: check/build and 4 native / 2 wasm-gc / 2 JS public API tests pass,
  including audited backup, preserved interval proofs and independent append.

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
