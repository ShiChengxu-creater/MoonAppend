"""Actual cross-process workflows, crash recovery and native storage measurements."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]


def leaf(value):
    return hashlib.sha256(b"\0" + value).digest()


def node(left, right):
    return hashlib.sha256(b"\1" + left + right).digest()


def root(entries):
    if not entries:
        return hashlib.sha256(b"").digest()
    if len(entries) == 1:
        return leaf(entries[0])
    split = 1 << ((len(entries) - 1).bit_length() - 1)
    return node(root(entries[:split]), root(entries[split:]))


def repeated_root(count):
    powers = [leaf(b"benchmark-record")]
    for _ in range(count.bit_length()):
        powers.append(node(powers[-1], powers[-1]))
    result = None
    for level in range(count.bit_length()):
        if count & (1 << level):
            result = powers[level] if result is None else node(powers[level], result)
    return result or hashlib.sha256(b"").digest()


def rss(process):
    try:
        if os.name == "nt":
            import ctypes
            from ctypes import wintypes
            class Counters(ctypes.Structure):
                _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD)] + [
                    (name, ctypes.c_size_t) for name in ["PeakWorkingSetSize", "WorkingSetSize",
                    "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage", "QuotaPeakNonPagedPoolUsage",
                    "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage"]]
            counters = Counters()
            counters.cb = ctypes.sizeof(counters)
            if ctypes.windll.psapi.GetProcessMemoryInfo(wintypes.HANDLE(int(process._handle)),
                                                       ctypes.byref(counters), counters.cb):
                return counters.PeakWorkingSetSize
        else:
            for line in Path(f"/proc/{process.pid}/status").read_text().splitlines():
                if line.startswith("VmHWM:"):
                    return int(line.split()[1]) * 1024
    except (OSError, ValueError):
        pass
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT / "artifacts/storage-cli.json")
    parser.add_argument("--skip-scale", action="store_true")
    args = parser.parse_args()
    subprocess.run(["moon", "build", "--target", "native", "--release", "--deny-warn"], cwd=ROOT, check=True)
    directory = ROOT / "_build/native/release/build/cmd/moonappend"
    binary = next((p for p in [directory / "moonappend.exe", directory / "moonappend"] if p.is_file()), None)
    if binary is None:
        raise RuntimeError("Compiled native CLI was not found")
    work = Path(tempfile.mkdtemp(prefix="storage-workflows-", dir=ROOT / "_build"))
    checks = 0

    def run(*command, expected=0):
        nonlocal checks
        result = subprocess.run([str(binary), *map(str, command)], cwd=ROOT,
                                capture_output=True, text=True, encoding="utf-8", timeout=180)
        if result.returncode != expected:
            raise AssertionError(f"{command}: exit {result.returncode}; stdout={result.stdout}; stderr={result.stderr}")
        checks += 1
        return result.stdout

    def save(name, content):
        path = work / name
        path.write_text(content, encoding="utf-8")
        return path

    def records(name, values):
        return save(name, json.dumps({"format":"moonappend/1", "kind":"records", "entries":[v.hex() for v in values]}))

    entries = [f"event-{i}".encode() + b"\0\xff" for i in range(13)]
    first, second = records("first.json", entries[:8]), records("second.json", entries[8:])
    log = work / "事件日志"
    run("init", log)
    old = save("old.json", run("append", log, first))
    new = save("new.json", run("append", log, second))
    assert json.loads(old.read_text())["root"] == root(entries[:8]).hex()
    assert json.loads(new.read_text())["root"] == root(entries).hex()
    assert json.loads(run("audit", log)) == json.loads(new.read_text())
    saved_output = work / "快照.json"
    assert run("snapshot", log, 13, "--out", saved_output) == ""
    assert not saved_output.read_bytes().startswith(b"\xef\xbb\xbf")
    assert json.loads(saved_output.read_text(encoding="utf-8")) == json.loads(new.read_text())
    saved_bytes = saved_output.read_bytes()
    run("snapshot", log, 13, "--out", saved_output, expected=2)
    run("append", log, first, "--out", saved_output, expected=2)
    assert saved_output.read_bytes() == saved_bytes
    assert json.loads(run("audit", log)) == json.loads(new.read_text())
    proof = save("growth.json", run("consistency", log, 8, 13))
    run("verify-consistency", old, new, proof)
    wrong_old = json.loads(old.read_text())
    wrong_old["root"] = root([b"rewritten"] + entries[1:8]).hex()
    run("verify-consistency", save("wrong-old.json", json.dumps(wrong_old)), new, proof, expected=1)
    inclusion = save("inclusion.json", run("inclusion", log, 3, 8))
    one = records("one.json", [entries[3]])
    run("verify-inclusion", old, 3, one, inclusion)
    run("verify-inclusion", old, 3, records("wrong-one.json", [b"changed"]), inclusion, expected=1)
    interval = save("interval.json", run("range", log, 8, 13, 13))
    run("verify-range", new, 8, second, interval)
    run("verify-range", new, 8, records("reordered.json", list(reversed(entries[8:]))), interval, expected=1)
    assert json.loads(run("export", log, 3, 7))["entries"] == [v.hex() for v in entries[3:7]]
    run("range", log, 5, 5, 13, expected=2)
    run("init", log, expected=2)
    bad = '{"format":"moonappend/1","kind":"records","entries":[],"entr\\u0069es":[]}'
    run("append", log, save("duplicate.json", bad), expected=2)
    assert json.loads(run("audit", log)) == json.loads(new.read_text())
    huge = work / "oversized.json"
    with huge.open("wb") as file:
        file.seek(16777216)
        file.write(b"x")
    run("append", log, huge, expected=2)

    # Each command is a fresh process. Shard files contain only O(log n) hashes.
    left, right, merged, resumed = [work / name for name in ["left.bin", "right.bin", "merged.bin", "resumed.bin"]]
    run("shard", 0, first, left)
    run("shard", 8, second, right)
    run("merge", left, right, merged)
    assert json.loads(run("root", merged)) == json.loads(new.read_text())
    run("resume", left, second, resumed)
    assert json.loads(run("root", resumed)) == json.loads(new.read_text())
    before = left.read_bytes()
    run("shard", 0, first, left, expected=2)
    assert left.read_bytes() == before
    gap = work / "gap.bin"
    run("shard", 9, second, gap)
    run("merge", left, gap, work / "bad-merge.bin", expected=2)
    damaged = bytearray(left.read_bytes())
    damaged[-1] ^= 1
    (work / "damaged.bin").write_bytes(damaged)
    run("root", work / "damaged.bin", expected=2)

    # Kill a real writer while holding the OS lock. Reopen must release the lock
    # and retain only complete 1024-entry commits. This is not a power-cut test.
    crashed = work / "killed-writer"
    process = subprocess.Popen([str(binary), "generate", str(crashed), "1000000", "1024"],
                               cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            try:
                checkpoint = (crashed / "state").read_bytes()
                committed = int.from_bytes(checkpoint[26:34], "little")
                if committed >= 1024:
                    break
            except OSError:
                pass
            if process.poll() is not None:
                raise AssertionError("Crash writer finished before its checkpoint could be observed")
            time.sleep(0.01)
        else:
            raise AssertionError("Timed out waiting for a committed writer batch")
        run("audit", crashed, expected=2)
    finally:
        if process.poll() is None:
            process.kill()
        process.communicate(timeout=20)
    recovered = json.loads(run("audit", crashed))
    recovered_count = int(recovered["size"])
    assert recovered_count >= 1024 and recovered_count % 1024 == 0
    assert recovered["root"] == repeated_root(recovered_count).hex()
    run("append", crashed, records("after-crash.json", [b"after crash"]))
    run("audit", crashed)

    measurements = []
    if not args.skip_scale:
        for count in [70000, 140000]:
            destination = work / f"scale-{count}"
            began = time.perf_counter()
            process = subprocess.Popen([str(binary), "generate", str(destination), str(count), "1024"],
                                       cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            samples = []
            stopped = threading.Event()
            def sample():
                while not stopped.wait(0.01):
                    value = rss(process)
                    if value is not None:
                        samples.append(value)
            monitor = threading.Thread(target=sample)
            monitor.start()
            try:
                stdout, stderr = process.communicate(timeout=180)
            finally:
                stopped.set()
                monitor.join()
            if process.returncode:
                raise AssertionError(stderr.decode())
            append_seconds = time.perf_counter() - began
            head = json.loads(stdout)
            assert int(head["size"]) == count and head["root"] == repeated_root(count).hex()
            assert json.loads(run("audit", destination)) == head
            assert (destination / "nodes").stat().st_size == (2 * count - count.bit_count()) * 32
            measurements.append({"leaves":count, "batch_size":1024, "append_seconds":round(append_seconds, 4),
                "peak_rss_bytes": max(samples) if samples else None,
                "store_bytes": sum(p.stat().st_size for p in destination.iterdir() if p.is_file()),
                "root_matches_independent_hashlib": True})
    report = {"platform":os.name, "cli_invocations_checked":checks, "workflows":["persistent_event_log", "interval_receipt", "mergeable_shards"],
        "real_writer_kill_recovery":{"committed_leaves": recovered_count, "root_verified":True},
        "scale":measurements, "notes":"Sampled process memory and one timing run; no universal throughput or power-loss claim."}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"Workflow evidence: {work}")


if __name__ == "__main__":
    main()
