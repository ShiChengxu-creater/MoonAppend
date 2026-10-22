# 三个独立工作流

这些示例使用同一组底层算法，但各自调用不同的库能力：持久化与恢复、区间数据交付、
分片构树与状态续算。没有假设已有生产用户。

在仓库根目录执行 `python tools/verify_storage_cli.py` 可以自动复现全部场景和负例。
输入及输出会保存在打印出的 `_build/storage-workflows-*` 目录；脚本不会读写其他业务目录。
工具链和构建方式见 README。以下命令中的 `moon run cmd/moonappend --target native --`
是 CLI 入口，已编译的可执行文件也接受相同参数。

## 1. 应用事件日志：进程重启后继续追加

后端程序逐批收到事件，需要保存内容、恢复已确认的提交，并能审查旧历史。

- 输入：两份 UTF-8 `records` JSON 文件，第一批 8 条，第二批 5 条。
- 处理：`init DIR` 创建日志；`append DIR first.json --out old.json` 保存旧快照；
  下一次独立进程运行 `append DIR second.json --out new.json`。
- 输出：13 条记录的持久化日志，以及不同时间保存的两个快照。
- 审阅：`consistency DIR 8 13 --out growth.json`；
  `verify-consistency old.json new.json growth.json` 返回 `VERIFIED`。
- 恢复：强制终止另一个真实批量写进程，再 `audit DIR`；已提交记录数是完整批次的整数倍，
  根与独立 hashlib 一致。OS 锁自动释放，恢复后可以再次追加。
- 失败例：另一个写进程仍持锁时打开失败；旧根错误、一条记录损坏、已提交节点文件截短时拒绝。

这里复用的是保留原始记录的持久化 API、提交检查点和恢复机制，而非只做内存证明。

0.3 源码增加备份恢复：`backup DIR NEW_DIR` 全量审计后复制已提交日志，
`audit NEW_DIR` 再次核对；对照独立保存的预期快照后，可直接 `append NEW_DIR records.json`。
副本独立追加，原日志保持原来的内容；目标已存在或源历史损坏时拒绝。
`python tools/verify_backup.py` 运行 35 次跨进程检查，另有五阶段备份失败的单元回归。

## 2. 数据接收回执：交付一个区间而不披露全日志

接收方希望验证第 8 至 12 条数据属于约定的 13 条记录快照，无须拿到其余记录。

- 输入：由独立渠道取得的可信 `new.json`，五条交付记录及区间证明。
- 生成：`range DIR 8 13 13 --out receipt.json`；
  `export DIR 8 13 --out delivery.json` 输出原始字节的十六进制表示。
- 验证：`verify-range new.json 8 delivery.json receipt.json`。
- 输出：全部五条记录的内容、位置和顺序验证结果；一份证明共享两侧边界节点。
- 失败例：更换其中一条记录、重排交付顺序、删除一条记录、错误起点或畸形路径均拒绝。

验证命令只读快照、交付文件和证明，不打开源日志，也不依赖其他记录或数据库。

## 3. 分片任务：合并构树结果并保存计算进度

导入任务将 `[0,8)` 和 `[8,13)` 分给两个计算单元，协调端需要合并摘要，不重新持有全部数据。

- 输入：各分片的起始索引及记录批次。
- 分片：`shard 0 first.json left.bin` 与 `shard 8 second.json right.bin`。
- 合并：`merge left.bin right.bin merged.bin`；`root merged.bin` 得到总根，
  与上述磁盘日志及独立 Python 全量构树结果一致。
- 续算：`resume left.bin second.json resumed.bin` 在新进程中恢复并继续构树，得到相同根。
- 失败例：分片不相邻、顺序错误、检查点损坏或输出文件已存在时拒绝，原输出保持不变。

compact checkpoint 只保存 O(log n) 哈希。可将这样的对象对接批处理或分片调度；
项目提供可合并数据结构，不提供网络调度器、并行执行框架，也不声称已测出并行加速比。
checkpoint 不认证分片来源，需要可信输入或最后与独立可信根比较。
