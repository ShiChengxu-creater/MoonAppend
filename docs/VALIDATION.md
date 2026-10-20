# MoonAppend 初验实测记录

日期：2026-10-19（Asia/Shanghai）。版本：`0.1.0-alpha.1`。
本记录说明开发侧的初验结果，不表示赛事官方已经验收。

## 对应版本与可核查证据

- 核心实现、测试和文档完成于 `1f89a1e7d79d7795cb2cd9d75a82b548c13e756f`。
- 补齐示例生成接口后，`92b509e4503c6187799c6e1fe7f983469834a856`
  已通过[首次远程三后端 CI](https://github.com/ShiChengxu-creater/MoonAppend/actions/runs/39264858411)。
- 增加未跟踪生成文件门禁后，`d6184ece0305246452fa8cd7ffb799a6da643b22`
  已通过[加强后的远程三后端 CI](https://github.com/ShiChengxu-creater/MoonAppend/actions/runs/39264977417)。
- 写入本记录前有 19 次真实提交，均已推送至公开仓库
  [ShiChengxu-creater/MoonAppend](https://github.com/ShiChengxu-creater/MoonAppend)。
  后续提交数量以 `git rev-list --count HEAD` 为准。
- 本记录的提交本身会再次触发相同 CI；不能将前一提交的通过状态自动视为后续版本的结果。

## 环境

本地为 Windows，native 使用 MSVC；远程为 `ubuntu-24.04`。
两端固定 `moon 0.1.20260920 (914d7da)`、`moonc v0.10.14+7d59c7ec9`、
`moonrun 0.1.20260920`，依赖 `moonbitlang/x@0.4.44`。
本地 Python 3.13.9、Go 1.27.2；CI Python 3.12、Go 1.27.2、Node.js 22。

Go 对照使用 `transparency-dev/merkle` 的提交
`c39fbf350a405f68571bf4c42a6a518eb0a46a4b`，通过 `-mod=vendor` 离线构建。
第三方 9 个文件逐一核对 SHA-256，来源与许可证见 [THIRD_PARTY.md](../THIRD_PARTY.md)。

## 实际结果

下表中的项目在本地和上述远程 CI 均已执行成功。

| 检查 | native | wasm-gc | js |
| --- | --- | --- | --- |
| `moon check --deny-warn` | 通过 | 通过 | 通过 |
| `moon build --deny-warn` | 通过 | 通过 | 通过 |
| `moon test --deny-warn` | 82/82 | 82/82 | 82/82 |
| 内存增长及历史改写示例 | 通过 | 通过 | 通过 |
| Python hashlib 独立对照 | 通过 | 通过 | 通过 |
| 锁定 Go 实现独立对照 | 通过 | 通过 | 通过 |
| Git archive 独立公开 API 消费者 | 1/1 | 1/1 | 1/1 |

每种后端的 exporter 分别向 Python 和 Go 对照 69 个根、2,529 条包含路径、
2,529 条一致性路径；所有结果一致。删除一条输出的负控制也能被检测。
82 个测试块中 23 个为手写测试，59 个为 Go 生成向量；同一用例在三个后端复跑，
不能把复跑次数算成不同功能覆盖。测试块内还包含大小 1–64 的叶包含及旧/新大小穷举、
逐证明节点篡改、缺失/额外路径、限额、历史不变性和公开数组隔离检查。
虚拟大树向量覆盖 `2^32`、`2^53` 邻近边界及 `2^63−1`，不分配该规模的实际日志。

内存示例的实际输出：

```text
growth 3 -> 7: VERIFIED
rewritten history: ROOT_MISMATCH
release-2 inclusion: VERIFIED
changed leaf: ROOT_MISMATCH
```

另已通过格式检查、`moon info` 公开接口再生成、Go 向量再生成无差异检查、
第三方来源校验和不少于 10 次提交的 CI 门禁。
源码物理行数含注释：核心 MoonBit 624 行、手写测试 607 行、外部生成测试 5,147 行、
示例 MoonBit 89 行；这些数字不代表质量或覆盖率，第三方 Go 源码不算自主 MoonBit 实现。

复验命令见 [INITIAL_ACCEPTANCE.md](../INITIAL_ACCEPTANCE.md)，
CI 会保存每个后端的 `reference-*` JSON 结果作为运行附件。

## 初验范围与后续工作

初验闭环已完成：SHA-256 有序树、增量追加、历史快照、两类证明生成和验证、
内存示例、双参考对照及三后端检查。

尚未实施严格 JSON 交换格式、文件 CLI、其余现实场景集成、Mooncakes 发布和安装复验。
独立消费者是干净源码消费者，不是从 Mooncakes 安装的证据。
赛事最终要求的三个完整场景和人工撰写的一页申报书仍须在正式申报前完成。
相邻项目检索见 [TOPIC_RECHECK.md](TOPIC_RECHECK.md)，不宣称绝无同类或保证通过赛事验收。

## 2026-10-20：预览版发布与真实安装复验

参赛者执行 `moon publish`，原目录及解压后的发布包检查通过，服务器返回 `200 OK`。
随后通过 `tools/verify_published.py` 创建新的消费者，执行 `moon update` 和
`moon add ShiChengxu/moonappend@0.1.0-alpha.1`，确实从包仓库安装了这个版本。
消费者及其父目录没有 `moon.work`，未复制本仓库源码作为依赖。

三个后端的检查、构建和 1 个公开 API 测试块均通过；测试包含正常追加一致性、
历史包含、错误叶子拒绝及改写旧历史拒绝。依赖树确认版本为 `0.1.0-alpha.1`，
运行时依赖为 `moonbitlang/x@0.4.44`。
具体结果见 [registry-alpha.1.json](evidence/registry-alpha.1.json)。

复验命令：`python tools/verify_published.py --version 0.1.0-alpha.1`。
源码 CI 的 Git archive 消费者和这次包仓库安装复验分别记录，不能互相替代。
当前只发布了 alpha 预览版；严格 JSON、文件 CLI、剩余场景和正式版 `0.1.0` 仍待完成。
发布包中附带的文档是上传时的旧快照；本节及 GitHub README 是发布后的补充记录，
本次没有重发或覆盖同一版本。
