///|
/// RFC subranges either are complete aligned subtrees or split into such nodes.
fn MemoryLog::range_root(self : MemoryLog, start : Int, count : Int) -> Hash32 {
  if count == 0 {
    return empty_root()
  }
  if (count & (count - 1)) == 0 && start % count == 0 {
    let mut level = 0
    let mut width = count
    while width > 1 {
      level = level + 1
      width = width / 2
    }
    return self.levels[level][start / count]
  }
  let k = split_size(count)
  hash_node(self.range_root(start, k), self.range_root(start + k, count - k))
}

///|
pub fn MemoryLog::snapshot_at(
  self : MemoryLog,
  size : UInt64,
) -> Snapshot raise AppendError {
  if size > self.size() {
    raise InvalidSize
  }
  { count: size, digest: self.range_root(0, size.to_int()), }
}
