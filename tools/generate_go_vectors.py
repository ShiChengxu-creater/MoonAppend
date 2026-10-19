"""Regenerate large virtual-tree vectors using the pinned, offline Go oracle."""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--go", default="go")
    args = parser.parse_args()
    result = subprocess.run(
        [args.go, "run", "-mod=vendor", ".", "vectors"],
        cwd=ROOT / "tools/go_reference", check=True, capture_output=True, encoding="utf-8")
    (ROOT / "go_vectors_test.mbt").write_text(result.stdout, encoding="utf-8", newline="\n")
    subprocess.run(["moon", "fmt"], cwd=ROOT, check=True)
    print("Regenerated go_vectors_test.mbt; inspect git diff to confirm reproducibility.")


if __name__ == "__main__":
    main()
