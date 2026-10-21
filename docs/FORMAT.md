# JSON 交换格式 moonappend/1

由 `ShiChengxu/moonappend/wire` 编码和解码。只接受一个平面对象，值为字符串或字符串数组。
UTF-8 文件不带 BOM。解析拒绝重复字段（包括转义后相同的键）、未知或缺失字段、
非预期类型、嵌套对象、尾随内容和非法转义。

共同字段是 `"format":"moonappend/1"` 和对象种类 `kind`。所有大小和索引是十进制字符串，
不接受数字、符号、前导零或超出 `2^63−1` 的值。哈希必须是 64 位小写十六进制；
记录使用偶数位小写十六进制，保留原始字节，不自动正规化文本或业务 JSON。

| kind | 其余且仅有的字段 |
| --- | --- |
| `snapshot` | `size`, `root` |
| `inclusion` | `index`, `size`, `nodes` |
| `consistency` | `old_size`, `new_size`, `nodes` |
| `range` | `start`, `end`, `size`, `nodes` |
| `records` | `entries` |

字段顺序无意义。示例批次（字节 `one`、`two`）：

```json
{"format":"moonappend/1","kind":"records","entries":["6f6e65","74776f"]}
```

## 区间证明

零起点，半开区间 `[start,end)`，要求 `start < end <= size`。
`nodes` 是 `[0,start)` 的规范 compact nodes，随后是 `[end,size)` 的规范 compact nodes，
均按从左到右顺序排列。各部分长度由索引唯一决定，不由证明者任意指定。
验证方根据自己期望的 `start` 和全部记录生成中间区间，依次合并，再比较独立可信根。
证明不会自动认证 `snapshot`；不能只把同一输入包里的自报根作为信任来源。

此证明可对一整批连续记录共享边界节点，不等于重复逐条调用包含验证；
它是自定义 compact-range multiproof，不是 RFC 9162 的原始线格式。

## 资源与结果

文件输入最多 16 MiB；数组的节点数和记录条数先受限，再校验具体形状。
记录交换最多 4096 条，每条最多 1 MiB，编码总原始字节最多 8,372,224；
该限制为十六进制和 JSON 开销留下空间。磁盘直接 API 的批次载荷上限另为 16 MiB。
包含/一致性节点最多 128，区间节点数按 canonical gap 形状精确校验。

CLI 通过退出码区分：0 成功；1 证明不匹配或无先前历史；2 参数、格式、资源或 I/O 错误。
验证结果 JSON 含 `status` 和 `verified`。输出原始快照/证明/记录时可用 `--out NEW.json`，
由程序排他创建 UTF-8 文件，避免不同 shell 的重定向编码差异。
