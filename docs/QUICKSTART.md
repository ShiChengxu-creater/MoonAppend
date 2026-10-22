# Windows 从源码跑通日志、区间交付和备份

需要 README 中固定的 MoonBit 工具链及 native C 编译环境。在仓库根目录的 PowerShell 执行。
每次创建独立的 `_build` 子目录，输入 JSON 为 UTF-8 无 BOM。以下 `--out` 目标都必须不存在。

## 保存两批事件

```powershell
moon update
if ($LASTEXITCODE -ne 0) { throw 'moon update failed' }
moon build --target native --release --deny-warn
if ($LASTEXITCODE -ne 0) { throw 'moon build failed' }
$demoRoot = Join-Path (Get-Location) ('_build/demo-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $demoRoot | Out-Null
$demoCli = Join-Path (Get-Location) '_build/native/release/build/cmd/moonappend/moonappend.exe'
$demoUtf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $demoRoot 'first.json'), '{"format":"moonappend/1","kind":"records","entries":["6f6e65","74776f"]}', $demoUtf8)
[IO.File]::WriteAllText((Join-Path $demoRoot 'second.json'), '{"format":"moonappend/1","kind":"records","entries":["7468726565"]}', $demoUtf8)
function Invoke-MoonAppendDemo {
  & $demoCli @args
  if ($LASTEXITCODE -ne 0) { throw "MoonAppend failed: $args" }
}
Invoke-MoonAppendDemo init "$demoRoot/log"
Invoke-MoonAppendDemo append "$demoRoot/log" "$demoRoot/first.json" --out "$demoRoot/old.json"
Invoke-MoonAppendDemo append "$demoRoot/log" "$demoRoot/second.json" --out "$demoRoot/new.json"
Invoke-MoonAppendDemo audit "$demoRoot/log"
```

两个快照的 `size` 分别为 `"2"` 和 `"3"`，日志保存 `one`、`two`、`three` 三条原始字节。

## 验证增长和交付区间

```powershell
Invoke-MoonAppendDemo consistency "$demoRoot/log" 2 3 --out "$demoRoot/growth.json"
Invoke-MoonAppendDemo verify-consistency "$demoRoot/old.json" "$demoRoot/new.json" "$demoRoot/growth.json"
Invoke-MoonAppendDemo export "$demoRoot/log" 1 3 --out "$demoRoot/delivery.json"
Invoke-MoonAppendDemo range "$demoRoot/log" 1 3 3 --out "$demoRoot/range.json"
Invoke-MoonAppendDemo verify-range "$demoRoot/new.json" 1 "$demoRoot/delivery.json" "$demoRoot/range.json"
```

验证返回 `"status":"VERIFIED"`、`"verified":true`。实际接收方必须独立取得可信的 `new.json`；
演示在同一机器生成文件只是为了复现调用。错误数据和拒绝用例由 `tools/verify_storage_cli.py` 验证。

## 分片与续算

```powershell
Invoke-MoonAppendDemo shard 0 "$demoRoot/first.json" "$demoRoot/left.bin"
Invoke-MoonAppendDemo shard 2 "$demoRoot/second.json" "$demoRoot/right.bin"
Invoke-MoonAppendDemo merge "$demoRoot/left.bin" "$demoRoot/right.bin" "$demoRoot/merged.bin"
Invoke-MoonAppendDemo root "$demoRoot/merged.bin"
Invoke-MoonAppendDemo resume "$demoRoot/left.bin" "$demoRoot/second.json" "$demoRoot/resumed.bin"
Invoke-MoonAppendDemo root "$demoRoot/resumed.bin"
```

两个结果都应等于 `new.json` 的三条记录快照。

## 备份和独立恢复（需要 0.3 源码）

```powershell
Invoke-MoonAppendDemo backup "$demoRoot/log" "$demoRoot/backup"
Invoke-MoonAppendDemo audit "$demoRoot/backup"
Invoke-MoonAppendDemo append "$demoRoot/backup" "$demoRoot/second.json"
Invoke-MoonAppendDemo audit "$demoRoot/backup"
Invoke-MoonAppendDemo audit "$demoRoot/log"
```

备份刚创建时与保存的三条记录快照一致；向副本追加后，副本为四条，源日志仍为三条。
完整备份、历史证明、源损坏和已有目标保护的复验命令为 `python tools/verify_backup.py`。
实际恢复还须将 `audit` 结果与独立保存的预期快照比较。
