///|
/// A completed perfect subtree, addressed by its height and horizontal index.
pub fn MemoryLog::read_node(
  self : MemoryLog,
  level : Int,
  index : UInt64,
) -> Hash32 raise AppendError {
  if level < 0 || level >= self.levels.length() {
    raise InvalidIndex
  }
  if index >= self.levels[level].length().to_uint64() {
    raise InvalidIndex
  }
  self.levels[level][index.to_int()]
}

///|
/// Read only O(log n) immutable nodes from an application's storage backend.
pub fn compact_from_reader(
  start : UInt64,
  end : UInt64,
  read_node : (Int, UInt64) -> Hash32 raise Error,
) -> CompactRange raise Error {
  if start > end || end > MAX_TREE_SIZE {
    raise InvalidRange
  }
  let nodes = []
  let mut position = start
  while position < end {
    let width = block_width(position, end)
    let mut level = 0
    let mut value = width
    while value > 1UL {
      level = level + 1
      value = value / 2UL
    }
    nodes.push(read_node(level, position / width))
    position = position + width
  }
  CompactRange::new(start, end, nodes)
}

///|
pub fn snapshot_from_reader(
  size : UInt64,
  read_node : (Int, UInt64) -> Hash32 raise Error,
) -> Snapshot raise Error {
  compact_from_reader(0UL, size, read_node).snapshot()
}

///|
fn reader_root(
  start : UInt64,
  count : UInt64,
  read_node : (Int, UInt64) -> Hash32 raise Error,
) -> Hash32 raise Error {
  if count == 0UL {
    return empty_root()
  }
  if (count & (count - 1UL)) == 0UL && start % count == 0UL {
    let mut width = count
    let mut level = 0
    while width > 1UL {
      width = width / 2UL
      level = level + 1
    }
    return read_node(level, start / count)
  }
  let k = split_u64(count)
  hash_node(
    reader_root(start, k, read_node),
    reader_root(start + k, count - k, read_node),
  )
}

///|
fn split_u64(count : UInt64) -> UInt64 {
  let mut k = 1UL
  while k <= (count - 1UL) / 2UL {
    k = k * 2UL
  }
  k
}

///|
fn reader_inclusion(
  start : UInt64,
  count : UInt64,
  index : UInt64,
  reader : (Int, UInt64) -> Hash32 raise Error,
  output : Array[Hash32],
) -> Unit raise Error {
  if count == 1UL {
    return
  }
  let k = split_u64(count)
  if index < k {
    reader_inclusion(start, k, index, reader, output)
    output.push(reader_root(start + k, count - k, reader))
  } else {
    reader_inclusion(start + k, count - k, index - k, reader, output)
    output.push(reader_root(start, k, reader))
  }
}

///|
pub fn inclusion_from_reader(
  index : UInt64,
  size : UInt64,
  reader : (Int, UInt64) -> Hash32 raise Error,
) -> InclusionProof raise Error {
  if size == 0UL || size > MAX_TREE_SIZE || index >= size {
    raise InvalidIndex
  }
  let output = []
  reader_inclusion(0UL, size, index, reader, output)
  InclusionProof::new(index, size, output)
}

///|
fn reader_consistency(
  start : UInt64,
  old : UInt64,
  size : UInt64,
  known : Bool,
  reader : (Int, UInt64) -> Hash32 raise Error,
  output : Array[Hash32],
) -> Unit raise Error {
  if old == size {
    if !known {
      output.push(reader_root(start, size, reader))
    }
    return
  }
  let k = split_u64(size)
  if old <= k {
    reader_consistency(start, old, k, known, reader, output)
    output.push(reader_root(start + k, size - k, reader))
  } else {
    reader_consistency(start + k, old - k, size - k, false, reader, output)
    output.push(reader_root(start, k, reader))
  }
}

///|
pub fn consistency_from_reader(
  old : UInt64,
  size : UInt64,
  reader : (Int, UInt64) -> Hash32 raise Error,
) -> ConsistencyProof raise Error {
  if old > size || size > MAX_TREE_SIZE {
    raise InvalidSize
  }
  let output = []
  if old != 0UL && old != size {
    reader_consistency(0UL, old, size, true, reader, output)
  }
  ConsistencyProof::new(old, size, output)
}
