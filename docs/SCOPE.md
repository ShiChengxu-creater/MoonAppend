# Initial acceptance boundary

Required: SHA-256 domain-separated ordered trees, incremental append, historical
snapshots, inclusion proof generation/verification, consistency proof
generation/verification, independent reference checks, one memory-only example,
and the same core tests on native, wasm-gc and JavaScript.

Deferred to final acceptance: strict JSON interchange, file CLI, the remaining
scenario integrations and final 0.1.0 publication/install verification.
The alpha.1 preview was published on 2026-10-20; a fresh registry consumer passed
public API checks, builds and tests on native, wasm-gc and JavaScript.

No server, signing, persistence, sparse trees, consensus or proof of event truth.
Never classify a self-reported root as an authenticated root. The final acceptance
entry must distinguish local tests, commits, pushes, remote CI and publication.
