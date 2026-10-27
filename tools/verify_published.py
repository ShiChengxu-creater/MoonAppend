"""Install an exact Mooncakes release in a fresh consumer and test its public API."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MODULE = "ShiChengxu/moonappend"
TESTS = r'''///|
test "published package checks growth historical inclusion and rewritten history" {
  let log = @append.MemoryLog::new()
  ignore(log.append(b"one"))
  let saved = log.snapshot()
  ignore(log.append(b"two"))
  ignore(log.append(b"three"))
  assert_true(@append.verify_consistency(saved, log.snapshot(), log.prove_consistency(1UL, 3UL)).is_verified())
  let inclusion = log.prove_inclusion(0UL, 1UL)
  assert_true(@append.verify_inclusion(saved, 0UL, b"one", inclusion).is_verified())
  assert_false(@append.verify_inclusion(saved, 0UL, b"changed", inclusion).is_verified())
  let changed = @append.MemoryLog::new()
  ignore(changed.append(b"rewritten"))
  ignore(changed.append(b"two"))
  ignore(changed.append(b"three"))
  assert_false(@append.verify_consistency(saved, changed.snapshot(), changed.prove_consistency(1UL, 3UL)).is_verified())
}
'''

EXTENDED_TESTS = r'''///|
test "published extended API verifies range JSON and restored shards" {
  let log = @append.MemoryLog::new()
  let head = log.append_batch([b"one", b"two", b"three"])
  let proof = log.prove_range(1UL, 3UL, 3UL)
  assert_true(@append.verify_range(head, 1UL, [b"two", b"three"], @wire.decode_range(@wire.encode_range(proof))).is_verified())
  let left = @append.CompactRange::from_leaves(0UL, [b"one"])
  let right = @append.CompactRange::from_leaves(1UL, [b"two", b"three"])
  assert_eq(@append.CompactRange::restore(left.checkpoint()).merge(right).snapshot(), head)
}
'''

DISK_TEST = r'''///|
test "published native disk API survives reopening" {
  let path = @env.current_dir().unwrap() + "/registry-disk-" + @env.now().to_string()
  let log = @disk.DiskLog::create(path)
  let saved = log.append_batch([b"one", b"two"])
  log.close()
  let restored = @disk.DiskLog::open(path)
  defer restored.close()
  assert_eq(restored.audit(), saved)
  assert_eq(restored.read_entry(1UL), b"two")
}
'''

BACKUP_TEST = r'''///|
test "published backup restores an independently writable log" {
  let path = @env.current_dir().unwrap() + "/registry-backup-" + @env.now().to_string()
  let log = @disk.DiskLog::create(path)
  defer log.close()
  let head = log.append_batch([b"one", b"two", b"three"])
  assert_eq(log.backup(path + "-copy"), head)
  let restored = @disk.DiskLog::open(path + "-copy")
  defer restored.close()
  assert_eq(restored.audit(), head)
  assert_eq(restored.prove_range(1UL, 3UL, 3UL), log.prove_range(1UL, 3UL, 3UL))
  assert_eq(restored.append(b"copy-only"), 3UL)
  assert_eq(log.audit(), head)
}
'''


def run(command, cwd):
    result = subprocess.run(command, cwd=cwd, capture_output=True, encoding="utf-8", timeout=240)
    if result.returncode:
        raise RuntimeError(f"{command!r}\n{result.stdout}\n{result.stderr}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True, help="Exact Mooncakes release to install and verify")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--extended", action="store_true", help="Also exercise 0.2 range/wire/shard/disk APIs")
    parser.add_argument("--backup", action="store_true", help="Also exercise 0.3 native audited backup API; requires --extended")
    args = parser.parse_args()
    if args.backup and not args.extended:
        parser.error("--backup requires --extended")
    if not args.version or any(c not in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-+" for c in args.version):
        raise ValueError("Expected a release version, not a path or dependency expression")
    build = ROOT / "_build"
    build.mkdir(exist_ok=True)
    consumer = Path(tempfile.mkdtemp(prefix="published-consumer-", dir=build)).resolve()
    for parent in [consumer, *consumer.parents]:
        if (parent / "moon.work").exists():
            raise RuntimeError(f"A workspace could substitute local source: {parent}")
    (consumer / "moon.mod").write_text(
        'name = "local/moonappend_registry_consumer"\nversion = "0.0.0"\n', encoding="utf-8")
    initial_imports = '"ShiChengxu/moonappend" @append, '
    if args.extended:
        initial_imports += '"ShiChengxu/moonappend/wire", '
    (consumer / "moon.pkg").write_text('import { ' + initial_imports + '} for "test"\n', encoding="utf-8")
    (consumer / "consumer_test.mbt").write_text(TESTS + (EXTENDED_TESTS if args.extended else ""), encoding="utf-8")
    run(["moon", "update"], consumer)
    run(["moon", "add", f"{MODULE}@{args.version}"], consumer)
    dependency_tree = run(["moon", "tree"], consumer)
    if f"{MODULE}@{args.version}" not in dependency_tree:
        raise AssertionError(f"Expected exact registry version in dependency tree:\n{dependency_tree}")
    targets = {}
    for target in ["native", "wasm-gc", "js"]:
        imports = '"ShiChengxu/moonappend" @append, '
        count = 1
        if args.extended:
            count = 2
            imports += '"ShiChengxu/moonappend/wire", '
            if target == "native":
                count = 4 if args.backup else 3
                imports += '"ShiChengxu/moonappend/disk", "moonbitlang/core/env", '
                (consumer / "disk_test.mbt").write_text(DISK_TEST + (BACKUP_TEST if args.backup else ""), encoding="utf-8")
            else:
                (consumer / "disk_test.mbt").unlink(missing_ok=True)
        (consumer / "moon.pkg").write_text('import { ' + imports + '} for "test"\n', encoding="utf-8")
        run(["moon", "check", "--target", target, "--deny-warn"], consumer)
        run(["moon", "build", "--target", target, "--deny-warn"], consumer)
        output = run(["moon", "test", "--target", target, "--deny-warn"], consumer)
        if f"Total tests: {count}, passed: {count}, failed: 0" not in output:
            raise AssertionError(output)
        targets[target] = {"check": "passed", "build": "passed", "public_api_tests": f"{count}/{count}"}
    report = {"module": MODULE, "version": args.version, "source": "Mooncakes registry",
              "local_workspace_override": False, "targets": targets,
              "dependency_tree": "\n".join(dependency_tree.strip().splitlines()[1:])}
    rendered = json.dumps(report, indent=2) + "\n"
    (consumer / "result.json").write_text(rendered, encoding="utf-8")
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    print(f"Fresh consumer: {consumer}")


if __name__ == "__main__":
    main()
