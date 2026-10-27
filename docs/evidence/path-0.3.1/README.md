# 0.3.1 路径修复证据

2026-10-27，Windows 本地；源码修复提交 `436918c774c13198e27f23f2dacded72a88b8e58`。

- `baseline-0.3.0.json`：修改前，在两个隔离测试目录中复现相对路径的检查点错位。
- `paths-windows.json`：修改后，相对创建、打开、备份在切换工作目录后均保持正确，另一目录日志不变。
- `storage-windows.json`、`backup-windows.json`：完整存储、进程终止恢复、规模及备份流程重新通过。
- `package-consumer-native/wasm-gc/js.json`：真实 0.3.1 ZIP 公开 API 消费者通过。

native 105 个测试块、wasm-gc 和 JS 各 93 个另已运行通过，数量不等于覆盖率。
Linux 和 Windows CI 链接见 `docs/PATH_FIX.md`；以上保留源码与本地包归档证据。
0.3.1 发布后另完成注册表复验，原始结果为 [../registry-0.3.1.json](../registry-0.3.1.json)
和 [../registry-paths-0.3.1.json](../registry-paths-0.3.1.json)，没有本地工作区替代。
