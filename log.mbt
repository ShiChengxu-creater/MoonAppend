///|
/// In-memory complete-subtree store. Payloads are not retained after hashing.
pub struct MemoryLog {
  priv limits : Limits
  priv levels : Array[Array[Hash32]]
  priv mut count : Int
  priv mut total_bytes : Int
}

///|
pub fn MemoryLog::new(
  limits? : Limits = { leaves: 65536, bytes: 67108864, },
) -> MemoryLog {
  { limits, levels: [[]], count: 0, total_bytes: 0, }
}

///|
pub fn MemoryLog::size(self : MemoryLog) -> UInt64 {
  self.count.to_uint64()
}

///|
pub fn MemoryLog::input_bytes(self : MemoryLog) -> Int {
  self.total_bytes
}

///|
/// Validation precedes mutation: a rejected append leaves the log unchanged.
pub fn MemoryLog::append(
  self : MemoryLog,
  leaf : Bytes,
) -> UInt64 raise AppendError {
  if self.count >= self.limits.leaves {
    raise LeafLimit
  }
  if leaf.length() > self.limits.bytes - self.total_bytes {
    raise ByteLimit
  }
  let index = self.count
  let mut current = hash_leaf(leaf)
  self.levels[0].push(current)
  let mut position = index
  let mut level = 0
  while position % 2 == 1 {
    current = hash_node(self.levels[level][position - 1], current)
    level = level + 1
    if self.levels.length() == level {
      self.levels.push([])
    }
    self.levels[level].push(current)
    position = position / 2
  }
  self.count = self.count + 1
  self.total_bytes = self.total_bytes + leaf.length()
  index.to_uint64()
}

///|
pub fn MemoryLog::snapshot(self : MemoryLog) -> Snapshot {
  let mut remainder = self.count
  let mut root : Hash32? = None
  for level in 0..<self.levels.length() {
    if remainder % 2 == 1 {
      let node = self.levels[level][remainder - 1]
      root = Some(
        match root {
          None => node
          Some(right) => hash_node(node, right)
        },
      )
    }
    remainder = remainder / 2
  }
  { count: self.size(), digest: root.unwrap_or(empty_root()), }
}
