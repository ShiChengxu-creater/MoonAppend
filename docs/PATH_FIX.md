# 0.3.1 工作目录切换修复

2026-10-27（Asia/Shanghai）。0.3.1 已发布，源码、实际包归档和注册表消费者分别验证。

## 已复现的问题

0.3.0 的 `DiskLog` 保存调用方传入的目录字符串。若先在目录 A 用相对路径 `日志`
创建或打开日志，随后切换进程工作目录到 B，原来的数据文件描述符仍指向 A，
检查点路径却会相对于 B 重新解释。B 中恰好有同名日志时，追加可能报告成功，
但 A 的状态未提交，B 的检查点与数据文件不匹配。

隔离复现中，追加报告 2 条记录；原目录重开只保留 1 条，另一目录日志拒绝打开。
所有输入都在 `_build/review-cwd-*` 中生成，没有访问业务日志。现有 CLI 每条命令使用独立
进程且不会主动更改工作目录，先前流程没有覆盖此库调用模式。

已发布 0.3.0 的规避方式：向 `DiskLog::create/open` 传入绝对目录；使用相对目录时，
在关闭前保持进程工作目录不变。不建议在终验前扩大存储格式或并发功能范围。

## 修复与回归

创建或打开目录时解析并保存绝对路径，之后的检查点替换使用同一路径；备份目录也在
打开其文件前固定。Windows 使用 `_wfullpath` 和 Unicode 编解码，POSIX 使用 `realpath`。
解析失败、非目录、空路径或含 NUL 的输入报错。公开 API 和 MADL/1 格式不变。

`python tools/verify_paths.py` 创建单独 native 消费者，覆盖：

- 相对路径创建后切换目录，再追加、关闭和重开。
- 相对路径打开后切换目录，再追加、审计和验证历史一致性证明。
- 另一目录中的同名日志保持原来的记录和快照。
- 相对备份目录、Unicode 路径，以及副本打开后切换目录再独立追加。

切换工作目录的 C 辅助函数仅生成在测试消费者中，不进入产品 API。
Linux 和 Windows CI 都执行这项回归。目录及符号链接仍须由调用方管理，
不允许打开期间移动目录、替换文件或并发修改全局工作目录。

## 本轮结果

Windows 本地 native 105/105 个测试块通过，wasm-gc 和 JS 各 93/93，便携后端 check/build 通过；
新增工作目录回归、39 次存储流程、35 次备份流程及 7 万/14 万叶构树通过。
三个后端的真实 ZIP 消费者通过：native 2 个测试，wasm-gc 和 JS 各 1 个。
以上消费者验证使用当前源码打包，不是注册表安装。

功能提交 `436918c` 的 [Linux/Windows CI](https://github.com/ShiChengxu-creater/MoonAppend/actions/runs/40463564290)
已通过，包括两种 OS 的工作目录切换回归。原始结果见 [evidence/path-0.3.1](evidence/path-0.3.1/README.md)。
发布验证脚本现要求显式 `--version`，缺省参数会拒绝运行，避免静默检查旧预览版。
包含最终修复说明的提交 `bdd13e6` 的 [CI](https://github.com/ShiChengxu-creater/MoonAppend/actions/runs/40464154792) 也已通过。

发布后运行 `python tools/verify_published.py --version 0.3.1 --extended --backup`，
三个后端 check/build 和 native 4/4、wasm-gc / JS 各 2/2 个测试均通过。
另运行 `python tools/verify_paths.py --registry-version 0.3.1`，在没有本地工作区替代的
注册表消费者中，Windows native 的相对创建、相对打开、备份、Unicode 路径、历史一致性
及另一同名日志保持不变的检查均通过。依赖树确认为 `ShiChengxu/moonappend@0.3.1`。
结果见 [registry-0.3.1.json](evidence/registry-0.3.1.json) 与
[registry-paths-0.3.1.json](evidence/registry-paths-0.3.1.json)。
0.3.0 的历史测试和安装证据继续保留；跨版本数据升级和多轮恢复压力验证仍为后续工作。
