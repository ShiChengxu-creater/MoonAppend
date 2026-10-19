# MoonAppend

MoonBit append-only Merkle log and proof library. Initial acceptance version
`0.1.0-alpha.1` is under development; it is not published to Mooncakes.

Scope: SHA-256, RFC 9162 section 2.1 trees, inclusion proofs, consistency proofs,
bounded in-memory generation, native / wasm-gc / JavaScript core support.

This library checks commitments to ordered bytes. Applications provide trusted
snapshots and authenticate them separately. It does not authenticate people,
timestamps, event truth, or detect every split view of a log.

Toolchain baseline: MoonBit compiler `0.10.14+7d59c7ec9`, moon
`0.1.20260920`; dependency `moonbitlang/x@0.4.44`.

Run from the repository root, stopping on each failure:

```sh
moon update
moon check --target wasm-gc --deny-warn
moon build --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
```

API, examples, evidence and the initial acceptance entry will be documented as
the independently checked implementation is completed. License: Apache-2.0.
