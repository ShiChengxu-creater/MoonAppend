"""Cross-process audited backup/restore, corruption refusal and large-file copies."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

from verify_storage_cli import ROOT, root


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT / "artifacts/backup.json")
    args = parser.parse_args()
    subprocess.run(["moon", "build", "--target", "native", "--release", "--deny-warn"], cwd=ROOT, check=True)
    folder = ROOT / "_build/native/release/build/cmd/moonappend"
    binary = next(p for p in [folder / "moonappend.exe", folder / "moonappend"] if p.is_file())
    work = Path(tempfile.mkdtemp(prefix="backup-workflows-", dir=ROOT / "_build"))
    checks = 0

    def run(*command, expected=0):
        nonlocal checks
        result = subprocess.run([str(binary), *map(str, command)], cwd=ROOT,
                                capture_output=True, text=True, encoding="utf-8", timeout=180)
        if result.returncode != expected:
            raise AssertionError(f"{command}: exit {result.returncode}; {result.stdout}; {result.stderr}")
        checks += 1
        return json.loads(result.stdout) if expected == 0 else result.stderr

    def records(name, entries):
        path = work / name
        path.write_text(json.dumps({"format": "moonappend/1", "kind": "records",
                                   "entries": [v.hex() for v in entries]}), encoding="utf-8")
        return path

    def digest(path):
        with path.open("rb") as file:
            return hashlib.file_digest(file, "sha256").hexdigest()

    source, copy = work / "原日志", work / "独立备份"
    run("init", source)
    entries = [b"one", b"two", b"", b"\x00\xff"]
    batch = records("records.json", entries)
    saved = run("append", source, batch)
    assert saved["root"] == root(entries).hex()
    assert run("backup", source, copy) == saved
    assert run("audit", copy) == saved
    for name in ["state", "nodes", "index", "payload"]:
        assert digest(source / name) == digest(copy / name)
    assert run("inclusion", copy, 1, 4) == run("inclusion", source, 1, 4)
    assert run("range", copy, 1, 3, 4) == run("range", source, 1, 3, 4)
    assert run("consistency", copy, 2, 4) == run("consistency", source, 2, 4)
    copy_state = digest(copy / "state")
    run("backup", source, copy, expected=2)
    assert digest(copy / "state") == copy_state
    existing = work / "existing-file"
    existing.write_bytes(b"keep")
    run("backup", source, existing, expected=2)
    assert existing.read_bytes() == b"keep"
    run("append", source, records("source.json", [b"source-only"]))
    assert run("audit", copy) == saved
    divergent = run("append", copy, records("copy.json", [b"copy-only"]))
    assert run("audit", copy) == divergent
    assert run("audit", source)["root"] != divergent["root"]

    # Fast open accepts the checkpoint frontier, but backup must audit payloads.
    with (copy / "payload").open("r+b") as file:
        file.write(b"X")
    refused = work / "corrupt-copy-refused"
    run("backup", copy, refused, expected=2)
    assert not refused.exists()

    empty, empty_copy = work / "empty", work / "empty-copy"
    empty_head = run("init", empty)
    assert run("backup", empty, empty_copy) == empty_head
    assert run("audit", empty_copy) == empty_head
    assert run("append", empty_copy, batch)["root"] == saved["root"]

    # Copy a payload larger than read_file's 16 MiB limit; backup streams chunks.
    large, large_copy = work / "large", work / "large-copy"
    run("init", large)
    value = b"\xa5" * 1048576
    large_batch = records("large.json", [value, value])
    for _ in range(9):
        large_head = run("append", large, large_batch)
    assert large_head["root"] == root([value] * 18).hex()
    assert run("backup", large, large_copy) == large_head
    assert run("audit", large_copy) == large_head
    assert (large_copy / "payload").stat().st_size == 18 * 1048576
    assert digest(large / "payload") == digest(large_copy / "payload")

    # A partial destination without a committed checkpoint is never an empty log.
    incomplete = work / "incomplete"
    incomplete.mkdir()
    for name in ["nodes", "index", "payload", "state.tmp"]:
        (incomplete / name).write_bytes(b"partial")
    run("audit", incomplete, expected=2)
    report = {"cli_invocations_checked": checks, "copy_matches_committed_files": True,
              "historical_proofs_preserved": True, "independent_append_after_restore": True,
              "corrupt_source_refused_before_destination_created": True,
              "existing_destinations_preserved": True, "empty_backup_writable": True,
              "large_payload_bytes": 18 * 1048576, "large_copy_sha256_matches": True,
              "incomplete_destination_refused": True,
              "notes": "No physical power-loss or hostile concurrent file replacement guarantee."}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"Backup evidence: {work}")


if __name__ == "__main__":
    main()
