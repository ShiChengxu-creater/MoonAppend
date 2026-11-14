# 0.3.2 工具链兼容性补丁

2026-11-14（Asia/Shanghai）。本版本将 11 月 12 日的兼容性维护打包为新的补丁版本，保留公开 API、MADL/1 磁盘格式及 0.3.1 的相对路径修复。使用 `moon 0.1.20261104`、`moonc v0.10.20+65efd5b93`；旧的 9 月编译器不支持本版本的 `#derive` 和 `Int32` 写法。

发布前已通过三后端 check/build/test（native 105、wasm-gc/JS 各 93 个测试块）、Python/Go 参考对照、实际 ZIP 消费者、39 次存储 CLI、35 次备份 CLI 和工作目录切换回归。接口和 Go 测试向量重生成后保持同步。背景与完整复验命令见 [TOOLCHAIN_COMPATIBILITY.md](TOOLCHAIN_COMPATIBILITY.md)。

注册表发布后，用全新消费者验证确切版本：

```sh
python tools/verify_published.py --version 0.3.2 --extended --backup --out docs/evidence/registry-0.3.2.json
python tools/verify_paths.py --registry-version 0.3.2 --out docs/evidence/registry-paths-0.3.2.json
```

这些脚本拒绝本地 workspace 替代，从 Mooncakes 安装指定版本，验证三后端公开 API，并在 native 验证磁盘重开、审计、备份、副本独立追加、相对路径和 Unicode 路径。
