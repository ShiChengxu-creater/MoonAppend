"""Independent hashlib/RFC oracle for the initial proof exporter (stdlib only)."""
from __future__ import annotations

import argparse
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SIZES = list(range(65)) + [65, 127, 128, 129]
LEAVES = tuple(bytes([i, 0, 255]) for i in range(129))


def leaf_hash(value: bytes) -> bytes:
    return hashlib.sha256(b"\x00" + value).digest()


def node_hash(left: bytes, right: bytes) -> bytes:
    return hashlib.sha256(b"\x01" + left + right).digest()


@lru_cache(maxsize=None)
def root(start: int, count: int) -> bytes:
    if count == 0:
        return hashlib.sha256(b"").digest()
    if count == 1:
        return leaf_hash(LEAVES[start])
    split = 1 << ((count - 1).bit_length() - 1)
    return node_hash(root(start, split), root(start + split, count - split))


def inclusion(start: int, count: int, index: int) -> list[bytes]:
    if count == 1:
        return []
    split = 1 << ((count - 1).bit_length() - 1)
    if index < split:
        return inclusion(start, split, index) + [root(start + split, count - split)]
    return inclusion(start + split, count - split, index - split) + [root(start, split)]


def consistency(start: int, old: int, new: int, known: bool = True) -> list[bytes]:
    if old == new:
        return [] if known else [root(start, new)]
    split = 1 << ((new - 1).bit_length() - 1)
    if old <= split:
        return consistency(start, old, split, known) + [root(start + split, new - split)]
    return consistency(start + split, old - split, new - split, False) + [root(start, split)]


def check_fixture(text: str) -> dict[str, int]:
    expected = {("R", n) for n in SIZES}
    expected |= {("I", n, i) for n in SIZES for i in range(n)}
    expected |= {("C", m, n) for n in SIZES for m in range(1, n + 1)}
    counts = {"roots": 0, "inclusion": 0, "consistency": 0}
    for line in text.splitlines():
        fields = line.split("\t")
        kind = fields[0]
        if kind == "R" and len(fields) == 3:
            n = int(fields[1])
            key = (kind, n)
            actual = bytes.fromhex(fields[2])
            wanted = root(0, n)
            counts["roots"] += 1
        elif kind in ("I", "C") and len(fields) == 4:
            a, b = map(int, fields[1:3])
            key = (kind, a, b)
            actual = [bytes.fromhex(s) for s in fields[3].split(",")] if fields[3] else []
            if kind == "I":
                wanted = inclusion(0, a, b)
                counts["inclusion"] += 1
            else:
                wanted = consistency(0, a, b)
                counts["consistency"] += 1
        else:
            raise AssertionError(f"Unexpected exporter record: {line[:100]!r}")
        if key not in expected:
            raise AssertionError(f"Duplicate or unexpected record {key}")
        expected.remove(key)
        if actual != wanted:
            raise AssertionError(f"Reference mismatch at {key}")
    if expected:
        raise AssertionError(f"Exporter omitted {len(expected)} required records")
    return counts


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=["native", "wasm-gc", "js"], default="wasm-gc")
    parser.add_argument("--go", help="Also check using the pinned transparency-dev/merkle Go module")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    fixture = subprocess.run(
        ["moon", "run", "examples/interop", "--target", args.target],
        cwd=ROOT, check=True, capture_output=True, encoding="utf-8",
    ).stdout
    counts = check_fixture(fixture)
    # Negative control: the oracle must notice a missing export record.
    try:
        check_fixture("\n".join(fixture.splitlines()[1:]))
    except AssertionError:
        pass
    else:
        raise AssertionError("Oracle failed its missing-record negative control")
    report = {"target": args.target, "python_hashlib": counts, "negative_control": "passed"}
    if args.go:
        result = subprocess.run(
            [args.go, "run", "-mod=vendor", ".", "check"], cwd=ROOT / "tools/go_reference",
            input=fixture, check=True, capture_output=True, encoding="utf-8",
        )
        report["go_reference"] = json.loads(result.stdout)
    rendered = json.dumps(report, indent=2, sort_keys=True)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)


if __name__ == "__main__":
    main()
