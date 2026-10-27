"""Exercise public disk API across process working-directory changes in isolation."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CWD_HELPER = r'''#include "moonbit.h"
#include <stdlib.h>
#ifdef _WIN32
#include <windows.h>
#include <direct.h>
#else
#include <unistd.h>
#endif
/* Test consumer only: no process-directory mutation API enters the library. */
MOONBIT_FFI_EXPORT int ma_review_chdir(moonbit_bytes_t path) {
#ifdef _WIN32
  int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (char *)path, -1, NULL, 0);
  if (!n) return -1;
  wchar_t *w = malloc((size_t)n * sizeof(wchar_t));
  if (!w) return -1;
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (char *)path, -1, w, n)) { free(w); return -1; }
  int result = _wchdir(w); free(w); return result;
#else
  return chdir((char *)path);
#endif
}
'''
PROGRAM = r'''///|
#borrow(path)
extern "C" fn change_directory(path : Bytes) -> Int = "ma_review_chdir"
///|
fn cd(path : String) -> Int { change_directory(@utf8.encode(path) + b"\x00") }
///|
fn exercise() -> Unit raise Error {
  let origin = @env.current_dir().unwrap()
  defer ignore(cd(origin))
  let left = LEFT_PATH
  let right = RIGHT_PATH
  assert_eq(cd(left), 0)
  let original = @disk.DiskLog::create("日志")
  let first = original.append_batch([b"original-first"])
  let other = @disk.DiskLog::create(right + "/日志")
  let other_head = other.append_batch([b"other-first"])
  other.close()
  assert_eq(cd(right), 0)
  let second = original.append_batch([b"original-second"])
  assert_eq(second.size(), 2UL)
  original.close()
  let reopened = @disk.DiskLog::open(left + "/日志")
  assert_eq(reopened.audit(), second)
  assert_eq(reopened.read_entry(1UL), b"original-second")
  assert_true(@tree.verify_consistency(first, second, reopened.prove_consistency(1UL, 2UL)).is_verified())
  reopened.close()
  assert_eq(cd(left), 0)
  let relative = @disk.DiskLog::open("日志")
  assert_eq(cd(right), 0)
  let third = relative.append_batch([b"original-third"])
  relative.close()
  let latest = @disk.DiskLog::open(left + "/日志")
  assert_eq(latest.audit(), third)
  assert_eq(latest.read_entry(2UL), b"original-third")
  assert_eq(latest.backup("副本"), third)
  latest.close()
  let copy = @disk.DiskLog::open("副本")
  assert_eq(cd(left), 0)
  let copy_head = copy.append_batch([b"copy-only"])
  copy.close()
  let restored = @disk.DiskLog::open(right + "/副本")
  assert_eq(restored.audit(), copy_head)
  assert_eq(restored.read_entry(3UL), b"copy-only")
  restored.close()
  let unchanged = @disk.DiskLog::open(right + "/日志")
  assert_eq(unchanged.audit(), other_head)
  assert_eq(unchanged.read_entry(0UL), b"other-first")
  unchanged.close()
  let source = @disk.DiskLog::open(left + "/日志")
  assert_eq(source.audit(), third)
  source.close()
  println("PATH_REGRESSION_OK")
}
///|
fn main { try! exercise() }
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT / "artifacts/paths.json")
    args = parser.parse_args()
    version = re.search(r'^version\s*=\s*"([^"]+)"', (ROOT / "moon.mod").read_text(encoding="utf-8"), re.M).group(1)
    build = (ROOT / "_build").resolve()
    build.mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="path-regression-", dir=build)).resolve()
    if not work.is_relative_to(build):
        raise RuntimeError("Unexpected regression destination")
    consumer = work / "consumer"
    consumer.mkdir()
    left, right = work / "left", work / "right"
    left.mkdir()
    right.mkdir()
    (work / "moon.work").write_text('members = [ ' + json.dumps(ROOT.as_posix(), ensure_ascii=False) + ', "./consumer" ]\n', encoding="utf-8")
    (consumer / "moon.mod").write_text('name = "local/path_regression"\nversion = "0.0.0"\nimport { "ShiChengxu/moonappend@' + version + '" }\n', encoding="utf-8")
    (consumer / "moon.pkg").write_text('import { "ShiChengxu/moonappend" @tree, "ShiChengxu/moonappend/disk", "moonbitlang/core/env", "moonbitlang/core/encoding/utf8" }\npkgtype(kind: "executable")\nsupported_targets = "native"\noptions("native-stub": ["cwd.c"])\n', encoding="utf-8")
    (consumer / "cwd.c").write_text(CWD_HELPER, encoding="utf-8")
    program = PROGRAM.replace("LEFT_PATH", json.dumps(left.as_posix(), ensure_ascii=False)).replace("RIGHT_PATH", json.dumps(right.as_posix(), ensure_ascii=False))
    (consumer / "main.mbt").write_text(program, encoding="utf-8")
    result = subprocess.run(["moon", "run", "--target", "native", "--deny-warn", str(consumer)], cwd=work,
                            capture_output=True, encoding="utf-8", errors="replace", timeout=180)
    if result.returncode or "PATH_REGRESSION_OK" not in result.stdout:
        raise RuntimeError(f"Path regression failed\n{result.stdout}\n{result.stderr}")
    report = {"version": version, "source": "local source consumer; not a registry installation",
              "relative_create_survives_chdir": True, "relative_open_survives_chdir": True,
              "same_named_other_log_unchanged": True, "relative_backup_reopens_and_appends": True,
              "unicode_paths": True, "historical_consistency_verified": True}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
