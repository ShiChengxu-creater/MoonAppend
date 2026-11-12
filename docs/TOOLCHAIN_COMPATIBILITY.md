# 工具链兼容性维护（2026-11-12）

本次使用 [MoonBit 官方下载渠道](https://www.moonbitlang.com/download/) 当日提供的当前正式工具链，隔离安装后执行源码与实际 ZIP 包的验证。原始版本输出为：

```text
moon 0.1.20261104 (940aa18 2026-11-04)
moonc v0.10.20+65efd5b93 (2026-11-05)
moonrun 0.1.20261104 (940aa18 2026-11-04)
Feature flags enabled: rr_moon_mod,rr_moon_pkg
```

官方 Windows ZIP 的 SHA-256 为 `bdff9a3b2d7c61a3adae2fe09221d3de63effc6cab28bfa0cbeb94fb0d529d79`，与官方校验文件一致。本地环境为 Windows x64 / MSVC、Python 3.13.9、Node.js 24.22.1、Go 1.27.2；Go 参考实现离线使用保留的 vendor 源码。Linux/Windows CI 的 Node.js 版本为 22。

## 问题与修复

原始主分支 `e6751adfe7935b92d7c75161401a14cf287da2a2` 在当前工具链执行 `moon check --target native --deny-warn` 时，旧 `} derive(...)` 语法触发弃用诊断，严格检查失败。CI 原先只安装 9 月的编译器，无法提前发现这一变化。

使用当前 `moon fmt` 迁移至前置 `#derive(...)`，并同步可选参数声明和 `Int32` 的规范写法；`Int32` 对应原有 32 位 `Int`。`moon info` 已同步三个公开包的接口。证明算法、公开调用方式和 MADL/1 存储格式保留。依赖 `moonbitlang/x@0.4.44` 在当前工具链解析和编译通过。

## 验证结果

| 目标后端 | check / build / test（均含 `--deny-warn`） | 测试块 | 内存示例 | ZIP 包公开 API 测试 |
| --- | --- | --- | --- | --- |
| native | 通过 | 105 / 105 | 通过 | 2 / 2 |
| wasm-gc | 通过 | 93 / 93 | 通过 | 1 / 1 |
| js | 通过 | 93 / 93 | 通过 | 1 / 1 |

每个后端都通过独立 Python / Go 参考对照：69 个根、2,529 个包含证明、2,529 个一致性证明，以及 Go 的 595 个 compact range、6,545 个连续区间证明，缺失记录的负向对照也通过。独立消费模块从真实 `moon package` ZIP 导入公开 API，验证历史证明、区间和 JSON 交换、状态恢复；native 另验证磁盘重开、审计、备份及副本独立追加。

Windows native 额外通过：

- 39 次存储 CLI 调用，包括真实写进程终止恢复，以及 70,000 / 140,000 条记录的独立根校验。
- 35 次备份恢复 CLI 调用，包括 18 MiB 载荷哈希、历史证明、损坏输入拒绝及独立追加。
- 独立消费者的工作目录切换回归：相对 create/open/backup、同名目录隔离、Unicode 路径和历史一致性。
- Go 向量重生成幂等性、保留参考源码的 SHA-256、公开接口同步和格式检查。

机器可读的步骤、结果及日志哈希见 [maintenance/2026-11-12.json](maintenance/2026-11-12.json)。完整本地日志归档在维护会话目录，CI 通过 Actions 附件保存同类验证记录。测试块数量不代表覆盖率；进程终止恢复也不等同于物理断电认证。

## 复验与持续维护

安装官方当前工具链后，在仓库根目录运行下列命令，并将后端分别设为 `native`、`wasm-gc`、`js`：

```sh
moon version --all
moon update
moon info
moon fmt --check
moon check --target native --deny-warn
moon build --target native --deny-warn
moon test --target native --deny-warn
moon run examples/memory --target native
python tools/verify_reference.py --target native --go go
python tools/verify_expanded_reference.py --target native --go go
python tools/verify_consumer.py --target native --package
```

以下存储工作流仅限 native，需要 C 编译器和 Python 3.12+：

```sh
python tools/verify_storage_cli.py
python tools/verify_backup.py
python tools/verify_paths.py
python tools/check_repository.py
python tools/generate_go_vectors.py --go go
moon info
moon fmt --check
```

CI 已改为在推送、PR、手动触发和每周一北京时间 10:43 安装官方当前正式工具链，持续运行 Linux 三后端及 Windows native 验证；实际版本日志和验证附件在失败时也保留。磁盘包和 CLI 仍仅支持 native，便携核心及 wire 支持三个后端。

本次结果针对维护后的仓库源码与本地打包产物；模块版本仍为 0.3.1。旧工具链不在本次验证范围内；后续工具链以 CI 实际记录的版本和结果为准。现有 Mooncakes 0.3.1 的发布记录与本次源码维护分别保留，本次未发布新版本。
