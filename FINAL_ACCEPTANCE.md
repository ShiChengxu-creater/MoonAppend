# MoonAppend 终验准备记录

更新日期：2026-10-27（Asia/Shanghai）。参赛者提供的主办方通知确认报名初审已通过。
初审通过不代表最终验收；本文件记录交付状态和可复核入口。

## 交付版本

- 当前源码候选 `0.3.1`：修复日志的相对目录绑定，尚未发布；本轮检查见 [docs/PATH_FIX.md](docs/PATH_FIX.md)。
- `0.3.0`：在已申报方向内新增审计备份、独立恢复，并修复记录 JSON 解码的累计限额。
- Mooncakes 已发布 [0.3.0](https://mooncakes.io/docs/ShiChengxu/moonappend@0.3.0)：三个后端检查和构建通过，native 4/4、wasm-gc 和 JS 各 2/2 个独立消费者测试通过，包含备份 API。[注册表结果](docs/evidence/registry-0.3.0.json)。
- 旧版 `0.2.0` 的[安装结果](docs/evidence/registry-0.2.0.json)保留作历史记录，不替代本次验证。

## 功能与复核入口

| 项目 | 代码及说明 | 可复现检查 |
| --- | --- | --- |
| 增量、批次和历史证明 | 根包，docs/ALGORITHMS.md | 三后端 `moon test`；Python / 锁定 Go 对照 |
| 持久化、重启和故障恢复 | disk，docs/STORAGE.md | 六阶段提交故障；实际写进程终止和恢复 |
| 可扩展构树、区间证明 | compact.mbt、range.mbt、reader.mbt | 595 compact ranges、6,545 区间证明的 Go 对照 |
| 严格交换格式 | wire，docs/FORMAT.md | 重复字段、边界整数、错误类型、累计字节限额 |
| 审计备份与独立恢复 | disk/backup.mbt | 五阶段备份故障；35 次跨进程检查及 18 MiB 复制 |
| 三个应用流程 | docs/SCENARIOS.md | 39 次存储工作流调用、7 万/14 万叶实测 |
| 外部可用 API | 各 pkg.generated.mbti | tools/verify_consumer.py；实际打包 ZIP 消费者 |
| 开源和来源 | LICENSE、THIRD_PARTY.md、AI_USAGE.md | tools/check_repository.py 校验保留的上游文件 |
| CI | .github/workflows/ci.yml | Linux 三后端；Windows native；实际发布 ZIP 消费者 |

## 完成门禁

下述完整矩阵及注册表记录对应已发布 0.3.0，不替代 0.3.1 的本轮证据。
参赛者确认终验日期为 2026-10-30；0.3.1 正式交付前仍需对应 CI、打包、发布及注册表复验。

源码修改后执行格式检查、生成 API、三后端 check/build/test、独立参考、存储及备份工作流，
检查差异后提交并推送。CI 对相应提交执行；运行链接与实际结果须与候选版本对应。
0.3 已在 Windows 本地通过三后端 check/build/test：native 104/104、wasm-gc 和 JS 各 93/93。
三后端 Python/Go 双参考、595 compact ranges / 6,545 区间证明对照均通过。
干净 Git archive 及真实 ZIP 消费者通过：native 各 2 个测试，wasm-gc 和 JS 各 1 个，
其中 native 使用新增备份 API。完整存储工作流 39 次调用、备份工作流 35 次调用通过；
实际写进程终止后恢复通过，7 万/14 万叶的根均与独立 hashlib 相同。

功能提交 `88a94ff` 的[远程运行](https://github.com/ShiChengxu-creater/MoonAppend/actions/runs/39802259971)
结果为成功，包含新增 Windows native 任务。补充实际 ZIP 安装门禁的提交 `6b47300`
的[远程运行](https://github.com/ShiChengxu-creater/MoonAppend/actions/runs/39803306034)
也已通过。源码算法没有在该脚本改进中修改。
包含完整终验证据和快速上手的提交 `9acfbd7` 的[远程运行](https://github.com/ShiChengxu-creater/MoonAppend/actions/runs/39803762302)也已通过。

本地结构化证据见 [docs/evidence/final-0.3.0](docs/evidence/final-0.3.0/README.md)，
分别标注参考、工作流和消费者来源。不能把这些结果记作 0.3 的 Mooncakes 安装。
Windows 快速上手的四段 PowerShell 已逐字执行，增长/区间验证通过，
分片合并及恢复根一致，备份独立追加后源日志仍为三条。

发布前检查真实 ZIP，在独立消费者中导入根包、wire 和 native disk 的新增 API。
参赛者已完成 0.3.0 发布。发布后另建无 `moon.work` 本地替代的独立消费者，执行：

```sh
python tools/verify_published.py --version 0.3.0 --extended --backup --out artifacts/registry-0.3.json
```

依赖树确认为 `ShiChengxu/moonappend@0.3.0`，三个后端的 check/build 通过；
native 4/4、wasm-gc 和 JS 各 2/2 个测试通过。`--backup` 实际验证备份重开、
历史区间证明保留、副本独立追加以及源日志不随副本改变。
原始结果见 [docs/evidence/registry-0.3.0.json](docs/evidence/registry-0.3.0.json)。

已发布归档的 README 保留打包时的“尚未发布”说明；GitHub README 和本页记录后续发布、
安装验证状态，不重复上传相同版本。下一步是参赛者核对正式终验材料并提交。

## 最终提交材料

1. 公开仓库和确切提交、成功 CI 链接、Mooncakes 对应版本。
2. 功能、三个场景、测试、恢复及规模实测记录；README 的安装与使用命令。
3. Apache-2.0 许可证、第三方来源和 AI 辅助范围。
4. 参赛者核对并提交的终验材料。申报书仍位于项目外，不纳入 Git。

不承诺多写者事务、并发线程安全、网络文件系统和物理断电认证。
快照校验只针对调用方独立保存的可信根，不认证事件真实性或运营方身份。
