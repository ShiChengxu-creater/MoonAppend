"""Compare canonical ranges and interval witnesses to the pinned Go compact API."""
import argparse
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--go", default="go")
    parser.add_argument("--target", default="wasm-gc", choices=["native", "wasm-gc", "js"])
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    fixture = subprocess.run(["moon", "run", "examples/expanded_interop", "--target", args.target],
                             cwd=ROOT, capture_output=True, text=True, encoding="utf-8", check=True).stdout
    command = [args.go, "run", "-mod=vendor", ".", "check-expanded"]
    result = subprocess.run(command, cwd=ROOT / "tools/go_reference", input=fixture,
                            capture_output=True, text=True, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(result.stderr)
    counts = json.loads(result.stdout)
    negative = subprocess.run(command, cwd=ROOT / "tools/go_reference", input="\n".join(fixture.splitlines()[1:]) + "\n",
                              capture_output=True, text=True, encoding="utf-8")
    if negative.returncode == 0:
        raise AssertionError("Reference accepted an incomplete export")
    report = {"target": args.target, "pinned_go_compact": counts, "negative_control": "passed"}
    rendered = json.dumps(report, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered, encoding="utf-8")
    print(rendered, end="")


if __name__ == "__main__":
    main()
