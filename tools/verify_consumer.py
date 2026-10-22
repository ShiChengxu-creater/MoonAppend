"""Exercise public API from a clean committed-source consumer, without publishing."""
import argparse
from io import BytesIO
import json
import re
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
  let range = log.prove_range(1UL, 3UL, 3UL)
  assert_true(@append.verify_range(log.snapshot(), 1UL, [b"two", b"three"], range).is_verified())
  assert_eq(@wire.decode_range(@wire.encode_range(range)), range)
  let state = @append.CompactRange::from_leaves(0UL, [b"one", b"two", b"three"])
  assert_eq(@append.CompactRange::restore(state.checkpoint()).snapshot(), log.snapshot())
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
    source_group = parser.add_mutually_exclusive_group()
    source_group.add_argument("--package-zip", type=Path, help="Verify an actual moon package archive instead of git archive")
    source_group.add_argument("--package", action="store_true", help="Run moon package and verify the resulting archive")
    parser.add_argument("--out", type=Path, help="Save the consumer result as JSON")
    args = parser.parse_args()
    revision = run(["git", "rev-parse", "HEAD"], ROOT).strip()
    if args.package:
        run(["moon", "package"], ROOT)
        metadata = (ROOT / "moon.mod").read_text(encoding="utf-8")
        module = re.search(r'^name\s*=\s*"([^"]+)"', metadata, re.M).group(1)
        version = re.search(r'^version\s*=\s*"([^"]+)"', metadata, re.M).group(1)
        args.package_zip = ROOT / "_build/publish" / f"{module.replace('/', '-')}-{version}.zip"
    archive = (args.package_zip.read_bytes() if args.package_zip else
               subprocess.check_output(["git", "archive", "--format=zip", revision], cwd=ROOT))
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
    version = re.search(r'^version\s*=\s*"([^"]+)"', (source / "moon.mod").read_text(encoding="utf-8"), re.M).group(1)
    (consumer / "moon.mod").write_text(
        'name = "local/moonappend_consumer"\nversion = "0.0.0"\n'
        f'import {{ "ShiChengxu/moonappend@{version}" }}\n', encoding="utf-8")
    extra_imports = ('"ShiChengxu/moonappend/disk", "moonbitlang/core/env", ' if args.target == "native" else '')
    (consumer / "moon.pkg").write_text(
        'import { "ShiChengxu/moonappend" @append, "ShiChengxu/moonappend/wire", ' + extra_imports + '} for "test"\n', encoding="utf-8")
    (consumer / "consumer_test.mbt").write_text(TESTS, encoding="utf-8")
    expected_tests = 1
    if args.target == "native":
        expected_tests = 2
        (consumer / "disk_test.mbt").write_text('''///|
test "separate native consumer persists and reopens a log" {
  let path = @env.current_dir().unwrap() + "/consumer-disk-" + @env.now().to_string()
  let log = @disk.DiskLog::create(path)
  let head = log.append_batch([b"one", b"two"])
  log.close()
  let reopened = @disk.DiskLog::open(path)
  defer reopened.close()
  assert_eq(reopened.audit(), head)
  assert_eq(reopened.read_entry(1UL), b"two")
  assert_eq(reopened.backup(path + "-backup"), head)
  let copy = @disk.DiskLog::open(path + "-backup")
  defer copy.close()
  assert_eq(copy.audit(), head)
  assert_eq(copy.append(b"independent"), 2UL)
  assert_eq(reopened.snapshot(), head)
}
''', encoding="utf-8")
    run(["moon", "check", "--target", args.target, "--deny-warn", str(consumer)], workspace)
    output = run(["moon", "test", "--target", args.target, "--deny-warn", str(consumer)], workspace)
    if f"Total tests: {expected_tests}, passed: {expected_tests}, failed: 0" not in output:
        raise AssertionError(output)
    report = {"commit": revision, "version": version, "target": args.target, "public_api_test_blocks": expected_tests,
              "source": ("moon package archive; not a Mooncakes installation" if args.package_zip else
                         "clean Git archive; not a Mooncakes installation")}
    rendered = json.dumps(report, indent=2) + "\n"
    (workspace / "result.json").write_text(rendered, encoding="utf-8")
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered, encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
