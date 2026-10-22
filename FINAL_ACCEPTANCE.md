# MoonAppend 终验准备记录

更新日期：2026-10-22（Asia/Shanghai）。参赛者提供的主办方通知确认报名初审已通过。
初审通过不代表最终验收；本文件记录交付状态和可复核入口。

## 交付版本

- GitHub 当前源码 `0.3.0`：在已申报方向内新增审计备份、独立恢复，并修复记录 JSON 解码的累计限额。
- Mooncakes 已发布 `0.2.0`：三个后端独立安装通过，[结果](docs/evidence/registry-0.2.0.json)。该包不含 0.3 的备份 API。
- `0.3.0` 尚未发布；不能将 0.2 的安装结果作为 0.3 的注册表证据。

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
| CI | .github/workflows/ci.yml | Linux 三后端；新增 Windows native 任务，须看实际运行结果 |

## 完成门禁

源码修改后执行格式检查、生成 API、三后端 check/build/test、独立参考、存储及备份工作流，
检查差异后提交并推送。CI 对相应提交执行；运行链接与实际结果须与候选版本对应。
0.3 已在 Windows 本地通过三后端 check/build/test：native 104/104、wasm-gc 和 JS 各 93/93。
备份工作流 35 次调用通过。独立参考、完整存储工作流、实际包消费者及远程 CI 仍需本轮复验。

发布前检查真实 ZIP，在独立消费者中导入根包、wire 和 native disk 的新增 API。
实际发布由参赛者决定；发布后执行注册表独立安装，记录确切版本和结果，再更新本页。

## 最终提交材料

1. 公开仓库和确切提交、成功 CI 链接、Mooncakes 对应版本。
2. 功能、三个场景、测试、恢复及规模实测记录；README 的安装与使用命令。
3. Apache-2.0 许可证、第三方来源和 AI 辅助范围。
4. 参赛者核对并提交的终验材料。申报书仍位于项目外，不纳入 Git。

不承诺多写者事务、并发线程安全、网络文件系统和物理断电认证。
快照校验只针对调用方独立保存的可信根，不认证事件真实性或运营方身份。
