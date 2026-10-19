# MoonAppend

MoonBit 的追加日志 Merkle 证明库。核心能力是生成并验证两个历史快照之间的
**一致性证明**：在可信旧根已保存的前提下，检查新的承诺是否保留了旧记录及其顺序。
另提供单条记录的包含证明、增量追加和历史前缀快照。

仓库：[ShiChengxu-creater/MoonAppend](https://github.com/ShiChengxu-creater/MoonAppend)。
当前 `0.1.0-alpha.1` 用于初验，**尚未发布到 Mooncakes**。初验入口见
[INITIAL_ACCEPTANCE.md](INITIAL_ACCEPTANCE.md)。

## 运行内存示例

工具链：`moon 0.1.20260920`、`moonc 0.10.14+7d59c7ec9`，依赖锁定
`moonbitlang/x@0.4.44`。native 使用 C 工具链，本地已能调用 MSVC；JS 需要 Node.js；
wasm-gc 使用 MoonBit 自带 moonrun。独立参考脚本需要 Python 3.12+ 和 Go 1.22.7+，
CI 使用 Python 3.12、Node.js 22、Go 1.27.2。

在仓库根目录逐条运行，失败即停止：

```sh
moon update
moon run examples/memory --target wasm-gc
```

输出：

```text
growth 3 -> 7: VERIFIED
rewritten history: ROOT_MISMATCH
release-2 inclusion: VERIFIED
changed leaf: ROOT_MISMATCH
```

示例先保存 3 条发布记录的旧快照，正常追加到 7 条；再用改写旧记录后生成的新证明，
验证它无法匹配原先保存的旧根。所有计算都在内存中，不需要网络或文件服务。

## 库接口

模块名为 `ShiChengxu/moonappend`。初验源码消费者通过本地 `moon.work` 使用，
不能把尚未发布的 `moon add` 命令当作可用安装方式。公开 API 见
[pkg.generated.mbti](pkg.generated.mbti)。

```moonbit
let log = @moonappend.MemoryLog::new()
ignore(log.append(b"first record"))
let saved = log.snapshot()
ignore(log.append(b"second record"))
let grown = log.snapshot()
let proof = log.prove_consistency(1UL, 2UL)
assert_true(@moonappend.verify_consistency(saved, grown, proof).is_verified())
```

构造和追加可能抛出 `AppendError`，应在可抛出错误的函数或 `try/catch` 中使用。
可编译的完整例子在 `examples/memory`。证明构造器验证元数据及路径限额，并复制节点数组；
对外返回的节点数组不会泄露内部可变存储。`Hash32` 包含不可变字节。

## 初验能力与边界

| 能力 | alpha 状态 |
| --- | --- |
| SHA-256、叶/节点域分离、规范非二次幂树 | 已实现 |
| 有界内存追加、历史前缀根、快照 | 已实现 |
| 包含证明生成与严格验证 | 已实现 |
| 一致性证明生成与严格验证 | 已实现 |
| 无文件系统示例、独立 Python/Go 对照、三后端 CI | 已提供；具体运行状态见初验记录 |
| 严格 JSON、文件 CLI、其余场景集成 | 留待终验 |
| Mooncakes 发布、从包仓库安装 | 尚未进行 |

树形和证明算法限定为 [RFC 9162 §2.1](https://www.rfc-editor.org/rfc/rfc9162.html#section-2.1)
的 SHA-256 配置，不是完整 CT、X.509 或 SCT 实现。

默认生成器最多 65,536 叶，累计载荷最多 64 MiB，可通过 `Limits::new` 收紧。
内存只保存哈希和完整子树，不保存载荷；限额不是进程总内存保证。
验证器支持到 `2^63−1` 的逻辑树大小，无须分配该规模的树，路径最多 128 节点。
文本调用方必须显式确定 UTF-8 等字节编码，库不 trim、排序、换行转换或正规化。

`old_size == 0` 返回 `NO_PRIOR_HISTORY`；相等大小要求空证明且根相同。
`VERIFIED` 只表示输入承诺间的关系符合证明。调用方必须独立取得可信快照并完成身份认证；
库不证明记录真实、时间可信、日志完整披露或运营方从不分叉。`MemoryLog` 是单线程可变对象，
并发访问和持久化由上层负责。详见 [docs/ALGORITHMS.md](docs/ALGORITHMS.md)。

## 验证

对 `native`、`wasm-gc`、`js` 分别执行：

```sh
moon fmt --check
moon check --target wasm-gc --deny-warn
moon build --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
python tools/verify_reference.py --target wasm-gc --go go
python tools/verify_consumer.py --target wasm-gc
```

把命令中的目标替换为另外两个后端。Go 参考源码已锁定提交并保留许可证，
`-mod=vendor` 方式不需要访问模块代理；它只服务开发验收，不参与产品运行时。
`go_vectors_test.mbt` 是外部生成的测试夹具，与手写实现分别统计。

CI 运行同样的检查、构建、测试、场景、独立对照和消费者测试，并检查生成向量可重复性、
公开 API 无漂移、参考来源校验值与至少 10 次 Git 提交。

## 来源与许可

Apache-2.0。实现及参考范围见 [THIRD_PARTY.md](THIRD_PARTY.md)，
AI 协作说明见 [AI_USAGE.md](AI_USAGE.md)。生态差异和复查记录见
[docs/TOPIC_RECHECK.md](docs/TOPIC_RECHECK.md)。本项目不宣称发明 Merkle 算法或生态中绝无同类。
