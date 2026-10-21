# Scope after the 2026-10-21 review response

Implemented: RFC SHA-256 trees, incremental and atomic batch append, historical
snapshots, inclusion/consistency/interval proofs, mergeable compact ranges and
checkpoints, storage reader callbacks, strict JSON interchange, and native
file-backed logs with recovery, audit and CLI workflows.

Portable core and wire support native, wasm-gc and JS. Disk and CLI are native.
The three workflows are persistent events, interval receipts and shard merge/resume.
Current source version is 0.2.0, unpublished; registry 0.1.0-alpha.1 is the
earlier limited-memory release. New-release publication and registry installation
must be recorded separately from source-archive consumer tests.

No server, signing, multiwriter transactions, sparse trees, consensus or proof of event truth.
Never classify a self-reported root as an authenticated root. The final acceptance
entry must distinguish local tests, commits, pushes, remote CI and publication.
