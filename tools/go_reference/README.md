# Independent reference (development only)

Imports unmodified upstream algorithms from transparency-dev/merkle at commit
`c39fbf350a405f68571bf4c42a6a518eb0a46a4b` (2026-10-12). The small vendor tree
retains upstream copyright headers and Apache-2.0 LICENSE. Its exact file hashes
are in `vendor-source.json`. It is not MoonAppend's MoonBit implementation.

No module proxy is needed. Go 1.22.7 or later:

```sh
go run -mod=vendor . check < ../../artifacts/fixture.tsv
```

Normally use `python tools/verify_reference.py --target wasm-gc --go go` from
the repository root. The adapter compares exact roots and generated paths and
calls upstream VerifyInclusion and VerifyConsistency on MoonAppend's paths.

To reproduce vendoring, clone upstream, checkout the exact commit above, then run
`python tools/vendor_reference.py /path/to/checkout`. Source bytes are read from
the committed Git blobs; no checkout changes or line-ending conversion enter
the vendor tree. The adapter and vendor material are excluded from the library
package at final publication.
