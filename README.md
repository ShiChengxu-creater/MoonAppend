# MoonAppend

MoonAppend 是 MoonBit 的有序追加日志库。它保存记录和 Merkle 节点，支持进程重启后继续追加、历史快照、批量提交，以及包含、一致性和连续区间证明。还提供可合并的 compact range，用少量哈希完成分片构树和状态恢复。

当前源码为 **0.3.1，尚未发布**，修复磁盘日志使用相对路径后切换工作目录可能提交到其他目录的问题。已发布的 **[0.3.0](https://mooncakes.io/docs/ShiChengxu/moonappend@0.3.0)** 包含审计备份，并通过三个后端的独立安装验证。0.3.0 磁盘调用方应传入绝对路径；使用相对路径时，须在关闭日志前保持进程工作目录不变。问题和回归说明见 [docs/PATH_FIX.md](docs/PATH_FIX.md)。

在调用方模块中安装：

```sh
moon add ShiChengxu/moonappend@0.3.0
```

0.3.0 注册表复验包括 native 4 个、wasm-gc 和 JS 各 2 个公开 API 测试，覆盖区间、JSON、分片状态、native 磁盘重开、备份及副本独立追加。结果见 [发布验证记录](docs/evidence/registry-0.3.0.json)。终验准备状态见 [FINAL_ACCEPTANCE.md](FINAL_ACCEPTANCE.md)。旧版 0.2.0 的独立安装记录也保留在证据目录中。

## 模块

| 导入路径 | 功能 | 后端 |
| --- | --- | --- |
| `ShiChengxu/moonappend` | 内存日志、批量追加、compact range、三类证明、外部节点读取接口 | native / wasm-gc / JS |
| `ShiChengxu/moonappend/wire` | 严格 JSON 快照、证明、十六进制记录交换 | native / wasm-gc / JS |
| `ShiChengxu/moonappend/disk` | 磁盘日志、提交检查点、重启恢复、随机读取、全量审计和独立备份 | native |
| `cmd/moonappend` | 上述能力的文件命令行入口 | native |

树、证明、序列化、提交顺序和恢复判断使用 MoonBit 实现。小型 C 适配层只负责文件偏移读写、同步、原子替换、Unicode 路径和操作系统锁。默认后端改为 native；便携核心也持续在另外两个后端验证。

## 从源码运行

工具链固定 `moon 0.1.20260920`、`moonc 0.10.14+7d59c7ec9`，依赖 `moonbitlang/x@0.4.44`。native 需要 C 编译环境，Windows 本地使用 MSVC，Linux CI 使用系统 C 工具链。JS 需要 Node.js。

```sh
moon update
moon run cmd/moonappend --target native -- --help
python tools/verify_storage_cli.py
python tools/verify_backup.py
python tools/verify_paths.py
```

两个 Python 脚本会在 `_build/` 创建独立数据目录，分别运行 39 次存储工作流和 35 次备份恢复命令行验证，包括进程终止恢复、7 万/14 万条实际构树和 18 MiB 载荷备份。需要 Python 3.12+；详细场景和输入文件见 [docs/SCENARIOS.md](docs/SCENARIOS.md)。

逐步运行可用 [Windows 快速上手](docs/QUICKSTART.md)，包含完整输入、命令和预期结果。版本差异见 [CHANGELOG.md](CHANGELOG.md)。

## 三种使用方式

- **持久化事件日志**：分批追加事件，关闭程序后重新打开，保留历史快照并继续写；读取单条记录，或对整个日志做损坏审计。
- **区间数据回执**：导出 `[start,end)` 的记录和共享证明，接收方只拿这批数据及可信快照即可离线验证内容、顺序和位置。
- **分片构树与恢复**：各任务分别计算相邻区间的 compact range，合并得到总根；保存构树状态后可从新进程继续，无须保留全部叶子。

这些是可复现的集成示例，不表示已有生产部署。各自的输入、处理步骤、错误案例与输出见 [场景说明](docs/SCENARIOS.md)。

## 核心 API

在调用方的 `moon.pkg` 中导入根包并取别名 `tree`。例如：

```moonbit
let log = @tree.MemoryLog::new()
let old = log.append_batch([b"one", b"two"])
let head = log.append_batch([b"three", b"four"])
let growth = log.prove_consistency(2UL, 4UL)
assert_true(@tree.verify_consistency(old, head, growth).is_verified())
let proof = log.prove_range(1UL, 3UL, 4UL)
assert_true(@tree.verify_range(head, 1UL, [b"two", b"three"], proof).is_verified())
```

上述调用可能抛出错误，应放在可抛出错误的函数或测试中。磁盘调用方导入 `ShiChengxu/moonappend/disk`，使用 `DiskLog::create/open`、`append_batch`、`snapshot_at`、`prove_range`、`read_entry` 和 `audit`；使用结束必须 `close`。

0.3 源码新增 `log.backup(NEW_DIR)`：先全量审计，再分块复制已提交内容，最后提交目标检查点。
通过 `DiskLog::open(NEW_DIR)` 恢复；副本可以独立追加。CLI 为 `backup DIR NEW_DIR`，目标目录必须不存在。

公开 API 由 `moon info` 生成：根目录、`wire/` 和 `disk/` 各有 `pkg.generated.mbti`。外部消费者验证见 `tools/verify_consumer.py`，不会依赖包内私有字段。

## 存储与信任边界

磁盘日志写入节点、索引和原始记录，先同步数据，再原子替换检查点。重启时验证检查点和前沿，回收未提交尾部；短于已提交长度的文件直接报错。写入发生 I/O 错误后，该对象禁止继续追加，应关闭重开，并检查最后实际提交的快照。提供六阶段故障注入和实际终止写进程的恢复测试。

`open` 只检查恢复所需状态，**全历史损坏检查使用 `audit`**。校验和和 Merkle 根不认证来源；调用方要独立保存可信快照、确定记录编码及处理身份认证。库不证明事件真实、没有遗漏或运营方从未分叉。

持久化支持本地文件系统和单写者；不提供数据库事务、并发线程安全或网络文件系统保证。同步和原子替换的语义仍取决于 OS、文件系统及硬件。进程终止测试不等同于物理断电认证。格式、恢复边界及资源上限见 [docs/STORAGE.md](docs/STORAGE.md)。

## 验证与规模记录

0.3.0 的本地记录为 native **104** 个测试块，wasm-gc、JS 各 **93** 个。0.3.1 源码已通过 native **105** 个测试块和工作目录切换回归；其余本轮检查状态见 [路径修复记录](docs/PATH_FIX.md)。历史独立参考和消费者记录单独保留，测试数量不是覆盖率。

```sh
moon fmt --check
moon check --target native --deny-warn
moon build --target native --deny-warn
moon test --target native --deny-warn
python tools/verify_reference.py --target native --go go
python tools/verify_expanded_reference.py --target native --go go
python tools/verify_consumer.py --target native
python tools/verify_storage_cli.py
python tools/verify_backup.py
```

核心命令也分别替换为 `wasm-gc` 和 `js` 运行；磁盘与 CLI 仅 native。Go 对照使用仓库保留的锁定源码，离线 `-mod=vendor` 构建，需要 Go 1.22.7+。CI 使用 Go 1.27.2、Python 3.12、Node.js 22，并保存参考与存储实测附件。

完整结果和限制见 [docs/EXTENDED_VALIDATION.md](docs/EXTENDED_VALIDATION.md)。原先 0.1 的发布及初验记录保存在 [docs/VALIDATION.md](docs/VALIDATION.md)。

## 来源与许可

Apache-2.0。算法依据 RFC 9162；compact ranges 参考 transparency-dev/merkle 的公开设计及其锁定 Go 实现进行对照。pymerkle 的公开文档用于了解可插拔存储设计，未引入其代码或运行时依赖。

详见 [THIRD_PARTY.md](THIRD_PARTY.md)、[AI_USAGE.md](AI_USAGE.md)、[docs/TOPIC_RECHECK.md](docs/TOPIC_RECHECK.md)。本项目不宣称发明 Merkle 算法，也不宣称生态中绝无同类。
