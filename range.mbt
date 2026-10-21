///|
/// Custom compact-range multiproof of one nonempty contiguous interval.
/// Nodes are the canonical left gap followed by the canonical right gap.
pub struct RangeProof {
  priv start : UInt64
  priv end : UInt64
  priv size : UInt64
  priv nodes : Array[Hash32]
} derive(Eq, Debug)

///|
pub extend RangeProof with Eq::{equal, not_equal}

///|
pub extend RangeProof with @debug.Debug::{to_repr}

///|
fn compact_count(start : UInt64, end : UInt64) -> Int {
  let mut position = start
  let mut count = 0
  while position < end {
    position = position + block_width(position, end)
    count = count + 1
  }
  count
}

///|
pub fn RangeProof::new(
  start : UInt64,
  end : UInt64,
  size : UInt64,
  nodes : Array[Hash32],
) -> RangeProof raise AppendError {
  if start >= end || end > size || size > MAX_TREE_SIZE {
    raise InvalidRange
  }
  if nodes.length() != compact_count(0UL, start) + compact_count(end, size) {
    raise InvalidProofLength
  }
  { start, end, size, nodes: nodes[:].to_owned(), }
}

///|
pub fn RangeProof::start(self : RangeProof) -> UInt64 {
  self.start
}

///|
pub fn RangeProof::end(self : RangeProof) -> UInt64 {
  self.end
}

///|
pub fn RangeProof::tree_size(self : RangeProof) -> UInt64 {
  self.size
}

///|
pub fn RangeProof::nodes(self : RangeProof) -> Array[Hash32] {
  self.nodes[:].to_owned()
}

///|
pub fn range_from_reader(
  start : UInt64,
  end : UInt64,
  size : UInt64,
  reader : (Int, UInt64) -> Hash32 raise Error,
) -> RangeProof raise Error {
  if start >= end || end > size || size > MAX_TREE_SIZE {
    raise InvalidRange
  }
  let left = compact_from_reader(0UL, start, reader)
  let right = compact_from_reader(end, size, reader)
  let nodes = left.nodes()
  for node in right.nodes() {
    nodes.push(node)
  }
  RangeProof::new(start, end, size, nodes)
}

///|
pub fn MemoryLog::prove_range(
  self : MemoryLog,
  start : UInt64,
  end : UInt64,
  size : UInt64,
) -> RangeProof raise Error {
  if size > self.size() {
    raise InvalidSize
  }
  range_from_reader(start, end, size, (level, index) => {
    self.read_node(level, index)
  })
}

///|
/// Binds every supplied record and its order to a caller-selected tree and start.
pub fn verify_range(
  trusted : Snapshot,
  start : UInt64,
  leaves : Array[Bytes],
  proof : RangeProof,
) -> Verification {
  if start != proof.start ||
    trusted.size() != proof.size ||
    leaves.length().to_uint64() != proof.end - proof.start {
    return Rejected("METADATA_MISMATCH")
  }
  if leaves.length() > 65536 {
    return Rejected("LEAF_LIMIT")
  }
  try {
    let count = compact_count(0UL, start)
    let left = CompactRange::new(0UL, start, proof.nodes[:count].to_owned())
    let middle = CompactRange::from_leaves(start, leaves)
    let right = CompactRange::new(
      proof.end,
      proof.size,
      proof.nodes[count:].to_owned(),
    )
    if left.merge(middle).merge(right).snapshot().root() == trusted.root() {
      Verified
    } else {
      Rejected("ROOT_MISMATCH")
    }
  } catch {
    _ => Rejected("INVALID_RANGE")
  }
}
