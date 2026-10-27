# Scope after the 2026-10-21 review response

Implemented: RFC SHA-256 trees, incremental and atomic batch append, historical
snapshots, inclusion/consistency/interval proofs, mergeable compact ranges and
checkpoints, storage reader callbacks, strict JSON interchange, and native
file-backed logs with recovery, audit and CLI workflows.

Portable core and wire support native, wasm-gc and JS. Disk and CLI are native.
The three workflows are persistent events, interval receipts and shard merge/resume.
Current source version 0.3.1 is unpublished and fixes log-directory binding across
process working-directory changes. See PATH_FIX.md for the reproducer and checks.
Version 0.3.0 is published on Mooncakes. It adds audited independent backups
and an aggregate byte-budget fix for record decoding. A fresh registry consumer,
without a local workspace override, passed check/build and 4 native / 2 wasm-gc /
2 JS public API tests. Evidence is in evidence/registry-0.3.0.json. See
FINAL_ACCEPTANCE.md for release-specific checks and publication status.
Version 0.2.0 is published on Mooncakes. A fresh registry consumer, without a local
workspace override, passed check/build and 3 native / 2 wasm-gc / 2 JS public API
tests. Evidence is in evidence/registry-0.2.0.json, separate from source-archive
consumer tests. Version 0.1.0-alpha.1 is the earlier limited-memory release.

No server, signing, multiwriter transactions, sparse trees, consensus or proof of event truth.
Never classify a self-reported root as an authenticated root. The final acceptance
entry must distinguish local tests, commits, pushes, remote CI and publication.
