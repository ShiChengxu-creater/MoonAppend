"""Exercise public API from a clean committed-source consumer, without publishing."""
import argparse
from io import BytesIO
import json
from pathlib import Path, PurePosixPath
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TESTS = r'''///|
test "separate consumer verifies a saved prefix and a historical inclusion" {
  let log = @append.MemoryLog::new()
  ignore(log.append(b"one"))
  let saved = log.snapshot()
  ignore(log.append(b"two"))
  ignore(log.append(b"three"))
  let proof = log.prove_consistency(1UL, 3UL)
  assert_true(@append.verify_consistency(saved, log.snapshot(), proof).is_verified())
  let inclusion = log.prove_inclusion(0UL, 1UL)
  assert_true(@append.verify_inclusion(saved, 0UL, b"one", inclusion).is_verified())
  assert_false(@append.verify_inclusion(saved, 0UL, b"changed", inclusion).is_verified())
}
'''


def run(command, cwd):
    result = subprocess.run(command, cwd=cwd, capture_output=True, encoding="utf-8", timeout=180)
    if result.returncode:
        raise RuntimeError(f"{command!r}\n{result.stdout}\n{result.stderr}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=["native", "wasm-gc", "js"], default="wasm-gc")
    args = parser.parse_args()
    revision = run(["git", "rev-parse", "HEAD"], ROOT).strip()
    archive = subprocess.check_output(["git", "archive", "--format=zip", revision], cwd=ROOT)
    build = (ROOT / "_build").resolve()
    build.mkdir(exist_ok=True)
    workspace = Path(tempfile.mkdtemp(prefix="consumer-", dir=build)).resolve()
    if not workspace.is_relative_to(build):
        raise RuntimeError("Unexpected consumer destination")
    source = workspace / "source"
    source.mkdir()
    with zipfile.ZipFile(BytesIO(archive)) as files:
        for name in files.namelist():
            entry = PurePosixPath(name)
            dest = (source / entry).resolve()
            if entry.is_absolute() or "\\" in name or not dest.is_relative_to(source):
                raise RuntimeError("Unsafe archive path")
            if name.endswith("/"):
                dest.mkdir(parents=True, exist_ok=True)
            else:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(files.read(name))
    consumer = workspace / "consumer"
    consumer.mkdir()
    (workspace / "moon.work").write_text('members = [ "./source", "./consumer" ]\n', encoding="utf-8")
    (consumer / "moon.mod").write_text(
        'name = "local/moonappend_consumer"\nversion = "0.0.0"\n'
        'import { "ShiChengxu/moonappend@0.1.0-alpha.1" }\n', encoding="utf-8")
    (consumer / "moon.pkg").write_text(
        'import { "ShiChengxu/moonappend" @append, } for "test"\n', encoding="utf-8")
    (consumer / "consumer_test.mbt").write_text(TESTS, encoding="utf-8")
    run(["moon", "check", "--target", args.target, "--deny-warn", str(consumer)], workspace)
    output = run(["moon", "test", "--target", args.target, "--deny-warn", str(consumer)], workspace)
    if "Total tests: 1, passed: 1, failed: 0" not in output:
        raise AssertionError(output)
    report = {"commit": revision, "target": args.target, "public_api_test_blocks": 1,
              "source": "clean Git archive; not a Mooncakes installation"}
    (workspace / "result.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
