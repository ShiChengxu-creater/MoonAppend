# MoonAppend 初验入口

版本 `0.1.0-alpha.1`。这是本地/仓库初验，不表示赛事已审核或 Mooncakes 已发布。

## 一分钟查看核心闭环

在本仓库根目录执行：

```sh
moon update
moon run examples/memory --target wasm-gc
```

应依次看到 `VERIFIED`、`ROOT_MISMATCH`、`VERIFIED`、`ROOT_MISMATCH`，
分别对应正常追加、改写旧历史、原叶包含成功、改动叶包含失败。

## 完整初验

每条失败即停止。把 `wasm-gc` 分别替换为 `native` 和 `js` 复验所有承诺后端。

```sh
moon fmt --check
moon check --target wasm-gc --deny-warn
moon build --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
python tools/verify_reference.py --target wasm-gc --go go
python tools/verify_consumer.py --target wasm-gc
python tools/check_repository.py
```

当前测试集含 82 个测试块，其中 59 个由独立 Go 参考生成；块中另有小树穷举和逐节点篡改循环。
独立 exporter 对照包含 69 个根、2,529 条包含路径、2,529 条一致性路径，分别与 Python
hashlib oracle 及锁定 Go 实现核对。上述数字是具体用例数量，不是覆盖率。
Go 生成的虚拟树向量覆盖 32/53/63 位边界，不需要生成数十亿条记录。

重生成外部向量：

```sh
python tools/generate_go_vectors.py --go go
git diff --exit-code
```

独立消费者从指定 HEAD 的 Git archive 建立新工作目录，仅使用公开包 API，
不复用源码树构建缓存；它仍是本地源代码消费者，不能冒称从 Mooncakes 安装成功。

## 交付状态

- 本地：核心两类证明、增量/历史快照、内存示例、独立参考均已实现。
- Git：已超过 10 次按真实进展形成的提交；确切数量由 `git rev-list --count HEAD` 查看。
- CI：已配置三后端的检查、构建、测试、独立对标、消费者、来源校验和接口/向量无漂移门禁。
- 推送、远程 CI 和最终本地矩阵状态：见后续 `docs/VALIDATION.md` 的实际记录。
- Mooncakes：未发布。严格 JSON、文件 CLI、剩余场景和发布安装属于终验。

初验中发现的问题先修复并补回归测试，再进入终验扩展。
