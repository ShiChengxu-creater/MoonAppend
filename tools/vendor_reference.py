"""Reproduce the small test-only vendor tree from the pinned upstream checkout."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

COMMIT = "c39fbf350a405f68571bf4c42a6a518eb0a46a4b"
VERSION = "v0.0.0-20261012081240-c39fbf350a40"
MODULE = "github.com/transparency-dev/merkle"
FILES = ["LICENSE", "hasher.go", "compact/nodes.go", "compact/range.go",
         "proof/proof.go", "proof/verify.go", "rfc6962/rfc6962.go",
         "testonly/tree.go", "testonly/constants.go"]
ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("checkout", type=Path)
    args = parser.parse_args()
    head = subprocess.check_output(["git", "-C", str(args.checkout), "rev-parse", "HEAD"], text=True).strip()
    if head != COMMIT:
        raise SystemExit("Reference checkout is not the pinned commit")
    vendor = ROOT / "tools/go_reference/vendor"
    hashes = {}
    for name in FILES:
        # Read the committed blob; ignore checkout edits and autocrlf settings.
        data = subprocess.check_output(["git", "-C", str(args.checkout), "show", f"{COMMIT}:{name}"])
        destination = vendor / MODULE / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        hashes[name] = hashlib.sha256(data).hexdigest()
    packages = [MODULE] + [MODULE + "/" + p for p in ["compact", "proof", "rfc6962", "testonly"]]
    (vendor / "modules.txt").write_text(
        f"# {MODULE} {VERSION}\n## explicit; go 1.22.7\n" + "\n".join(packages) + "\n", encoding="utf-8")
    (ROOT / "tools/go_reference/vendor-source.json").write_text(
        json.dumps({"repository": "https://github.com/transparency-dev/merkle", "commit": COMMIT,
                    "version": VERSION, "license": "Apache-2.0", "sha256": hashes}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8")


if __name__ == "__main__":
    main()
