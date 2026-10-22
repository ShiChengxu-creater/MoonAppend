# 0.3.0 终验候选的本地证据

2026-10-22，Windows 本地。功能代码提交 `88a94ff5a3ee5064257d10e90183744c6f9716dd`，
MoonBit 工具链与 README 固定版本一致。后续文档和脚本提交不改变该次实测的算法代码。

| 文件 | 来源 |
| --- | --- |
| reference-native / wasm-gc / js.json | 独立 Python hashlib 和锁定 Go：每后端 69 根、2,529 包含及 2,529 一致性证明，负控制通过 |
| expanded-native / wasm-gc / js.json | 锁定 Go API：每后端 595 compact ranges、6,545 区间证明，负控制通过 |
| source-consumer-native / wasm-gc / js.json | Git archive 源码，干净工作区公开 API 调用 |
| package-consumer-native / wasm-gc / js.json | 真实 moon package ZIP 的公开 API 调用，native 包含备份和独立追加 |
| storage-windows.json | 39 次存储工作流、实际写进程终止、7 万/14 万叶实测 |
| backup-windows.json | 35 次备份恢复调用、18 MiB 载荷逐文件校验、损坏及覆盖拒绝 |

本轮完整测试矩阵另通过 native 104/104、wasm-gc 和 JS 各 93/93；
包括累计记录字节上限和五阶段备份失败回归。测试块数量不是覆盖率。
以上文件保留发布前的源码及包归档结果，不是注册表安装证据。
0.3 发布后另完成注册表独立安装：native 4/4、wasm-gc 和 JS 各 2/2，
原始结果单独保存在 [../registry-0.3.0.json](../registry-0.3.0.json)。
远程 Linux / Windows 的运行与附件见根目录 FINAL_ACCEPTANCE.md 中的 CI 链接。
