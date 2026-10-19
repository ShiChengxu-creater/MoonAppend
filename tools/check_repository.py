"""Verify reference provenance and report honest source/test/generated counts."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    record = json.loads((ROOT / "tools/go_reference/vendor-source.json").read_text(encoding="utf-8"))
    vendor = ROOT / "tools/go_reference/vendor/github.com/transparency-dev/merkle"
    for name, expected in record["sha256"].items():
        if hashlib.sha256((vendor / name).read_bytes()).hexdigest() != expected:
            raise AssertionError(f"Vendored reference changed: {name}")
    commits = int(subprocess.check_output(["git", "rev-list", "--count", "HEAD"], cwd=ROOT, text=True))
    if commits < 10:
        raise AssertionError("Acceptance repository needs at least 10 real commits")
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    forbidden = {".mooncakes", "_build", "artifacts", "__pycache__", ".tools"}
    counts = {"production_moonbit_lines": 0, "handwritten_test_lines": 0,
              "generated_test_lines": 0, "example_moonbit_lines": 0}
    for name in filter(None, tracked):
        path = Path(name)
        if forbidden.intersection(path.parts):
            raise AssertionError(f"Unintended tracked cache: {name}")
        if path.suffix != ".mbt":
            continue
        lines = len((ROOT / path).read_text(encoding="utf-8").splitlines())
        key = ("generated_test_lines" if path.name == "go_vectors_test.mbt" else
               "example_moonbit_lines" if path.parts[0] == "examples" else
               "handwritten_test_lines" if path.name.endswith(("_test.mbt", "_wbtest.mbt")) else
               "production_moonbit_lines")
        counts[key] += lines
    print(json.dumps({"commits": commits, "vendor_files_checked": len(record["sha256"]),
                      "physical_lines_including_comments": counts}, indent=2))


if __name__ == "__main__":
    main()
