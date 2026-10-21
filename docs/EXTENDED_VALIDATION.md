# 0.2 扩展验证记录

日期：2026-10-21，Asia/Shanghai。版本 `0.2.0`，已发布到 Mooncakes，并完成注册表独立安装复验。
此前已发布的 `0.1.0-alpha.1` 不包含本次新增功能。本文是工程实测记录，不表示赛事已复审通过。

## 对初审问题的实际补充

| 反馈 | 实现 | 验证 |
| --- | --- | --- |
| 功能偏窄 | 磁盘原始记录/偏移/节点存储，公开 storage reader 接口 | 重启、随机读取、全量审计、外部消费者 |
| 缺少状态恢复 | 原子检查点、OS 锁、未提交尾部恢复、compact checkpoint | 六个写入失败阶段、实际终止写进程、损坏及截短拒绝 |
| 构树规模受限 | O(log n) 前沿、可合并分片、磁盘偏移节点读取 | 7 万及 14 万条实际构树，与独立 Python 根一致 |
| 缺少批量操作 | 整批校验的内存追加与磁盘提交 | 限额失败不改变可用状态；跨进程完整批次恢复 |
| 缺少区间证明 | 一份共享边界证明绑定连续多条记录、顺序和位置 | 小树全部区间、逐节点篡改、独立 Go 对照 |
| 场景重复 | 重启事件日志、区间回执、分片合并与续算 | 独立 CLI 输入输出及错误用例，见 SCENARIOS.md |

## 本地矩阵

固定工具链与初版一致：`moon 0.1.20260920`、`moonc 0.10.14+7d59c7ec9`，
依赖 `moonbitlang/x@0.4.44`。Windows native 使用 MSVC，Python 3.13.9、Go 1.27.2。

| 项目 | native | wasm-gc | JS |
| --- | --- | --- | --- |
| check / build，禁止警告 | 通过 | 通过 | 通过 |
| 测试块 | 98/98 | 92/92 | 92/92 |
| 原始 Python / Go 根及 RFC 证明对照 | 通过 | 通过 | 通过 |
| Go compact range / 区间证明对照 | 通过 | 通过 | 通过 |
| 干净 Git archive 公开 API 消费者 | 2/2 | 1/1 | 1/1 |

原始对照每个后端包含 69 个根、2,529 条包含路径、2,529 条一致性路径。
新增对照每个后端包含 595 个 compact range、6,545 个区间证明；Go 使用锁定的
`transparency-dev/merkle@c39fbf350a405f68571bf4c42a6a518eb0a46a4b` 的真实公开 API。
两组对照都有缺失记录的负控制，错误输出不能因测试没运行而通过。

92 个便携测试块中 59 个是原有的 Go 生成向量；另外 33 个包含手写用例和穷举循环。
native 另有 6 个存储测试块（包括六阶段故障注入循环）。数量不等于覆盖率。
完整本地矩阵执行于 `9612e18`，后续 CLI 文件输出增强及 39 次实际调用执行于 `0fe8a41`；
核心算法未在这次 CLI 增强中修改。版本号为 `0.2.0` 的提交 `c8e3d64` 已通过三后端 CI。

## native 应用、恢复及规模

`python tools/verify_storage_cli.py` 已通过 39 次预期退出码检查，覆盖三个不同工作流、
正常和错误证明、重复字段、超限文件、已有文件保护及 Unicode 路径。
新加 `--out` 输出由程序写 UTF-8 无 BOM，避免 shell 编码差异。

实际终止一个百万条目标的写进程后，重新打开并审计日志：保留完整的 1024 条批次，
根匹配独立 hashlib，进程锁被释放，恢复后可继续追加。具体终止时机不固定，
因此保留条数每次可不同；不把它写成固定业务结果。

Windows native release 本次样本（每条固定 16 字节、每批 1024 条）：

| 记录数 | 构建时间（含进程启动） | 采集到的峰值工作集 | 存储文件总字节 |
| --- | --- | --- | --- |
| 70,000 | 0.8647 s | 8,417,280 | 6,720,099 |
| 140,000 | 1.7727 s | 8,359,936 | 13,440,099 |

两个根均与独立 Python 一致，完成后另执行全量审计；审计不计入上述构建时间。
这是同一机器的单次样本，不是普遍吞吐、RSS 上限或与成熟库的性能胜出结论。
进程内存每约 10 ms 采样 Windows 的 PeakWorkingSetSize；Linux CI 使用 VmHWM。

原始结构化结果见 [evidence/storage-cli-windows.json](evidence/storage-cli-windows.json)，
三个后端的扩展对照结果见同目录 `expanded-*.json`。

## 复验与发布状态

完整命令在 README；CI 对三个后端运行核心检查和双参考，native 额外执行存储工作流，
并上传结果。源码消费者从 Git archive 建新目录，native 实际调用磁盘包，
这组结果单独证明源码消费者可用；注册表安装另行复验，结果见下文。

提交 `41f99e2` 的[三后端远程 CI](https://github.com/ShiChengxu-creater/MoonAppend/actions/runs/39619825250)
已全部通过，包括 Linux native 的 39 次 CLI 调用、真实写进程终止恢复、7 万/14 万叶构树。
包含发布检查脚本及 `0.2.0` 版本号的提交 `c8e3d64` 的[三后端 CI](https://github.com/ShiChengxu-creater/MoonAppend/actions/runs/39624787753) 也已全部通过。

0.2 已通过 `moon package --list` 和实际打包检查。将真实发布 ZIP 解压到新的消费者，
native 的 2 个公开 API 测试、wasm-gc 和 JS 各 1 个测试均通过，包含磁盘、JSON 和区间 API。
复验可用 `python tools/verify_consumer.py --target native --package-zip PATH_TO_ZIP`。
这仍是安装本地包归档，不是已经从 Mooncakes 安装了新版本。

`0.2.0` 已发布到 [Mooncakes](https://mooncakes.io/docs/ShiChengxu/moonappend@0.2.0)。发布后执行：

```sh
python tools/verify_published.py --version 0.2.0 --extended --out artifacts/registry-0.2.json
```

新的独立消费者没有 `moon.work` 本地替代，实际执行 `moon update`、`moon add`，
依赖树确认为 `ShiChengxu/moonappend@0.2.0`。三个后端的 check/build 全部通过；
native 3/3、wasm-gc 2/2、JS 2/2 个公开 API 测试通过，覆盖原有证明、新增区间、
JSON、分片状态恢复及 native 磁盘重开。原始结果见
[evidence/registry-0.2.0.json](evidence/registry-0.2.0.json)。

已发布包中的 README 保留打包时的“尚未发布”说明；本页和 GitHub README 记录发布后的实际状态。

尚未承诺数据库事务、多写者、线程安全、物理断电恢复认证、网络调度器或完整 CT 服务。
完整故障语义见 STORAGE.md，交换格式见 FORMAT.md。
