///|
/// Canonical maximal aligned perfect subtrees covering exactly [start, end).
/// Hashes are unauthenticated until compared with an independently trusted root.
pub struct CompactRange {
  priv start : UInt64
  priv end : UInt64
  priv nodes : Array[Hash32]
} derive(Eq, Debug)

///|
pub extend CompactRange with Eq::{equal, not_equal}

///|
pub extend CompactRange with @debug.Debug::{to_repr}

///|
fn block_width(start : UInt64, end : UInt64) -> UInt64 {
  let mut width = 1UL
  while width <= (end - start) / 2UL && start % (width * 2UL) == 0UL {
    width = width * 2UL
  }
  width
}

///|
pub fn CompactRange::new(
  start : UInt64,
  end : UInt64,
  nodes : Array[Hash32],
) -> CompactRange raise AppendError {
  if start > end || end > MAX_TREE_SIZE {
    raise InvalidRange
  }
  let mut position = start
  let mut count = 0
  while position < end {
    position = position + block_width(position, end)
    count = count + 1
  }
  if nodes.length() != count {
    raise InvalidProofLength
  }
  { start, end, nodes: nodes[:].to_owned(), }
}

///|
pub fn CompactRange::empty(
  start? : UInt64 = 0UL,
) -> CompactRange raise AppendError {
  CompactRange::new(start, start, [])
}

///|
pub fn CompactRange::start(self : CompactRange) -> UInt64 {
  self.start
}

///|
pub fn CompactRange::end(self : CompactRange) -> UInt64 {
  self.end
}

///|
pub fn CompactRange::nodes(self : CompactRange) -> Array[Hash32] {
  self.nodes[:].to_owned()
}

///|
/// Merge adjacent shards without needing their payloads or internal nodes.
pub fn CompactRange::merge(
  self : CompactRange,
  right : CompactRange,
) -> CompactRange raise AppendError {
  if self.end != right.start {
    raise NonContiguous
  }
  let starts : Array[UInt64] = []
  let widths : Array[UInt64] = []
  let hashes : Array[Hash32] = []
  for range in [self, right] {
    let mut position = range.start
    for node in range.nodes {
      let mut start = position
      let mut width = block_width(position, range.end)
      position = position + width
      let mut hash = node
      while !widths.is_empty() {
        let last = widths.length() - 1
        if widths[last] != width || starts[last] % (width * 2UL) != 0UL {
          break
        }
        start = starts[last]
        hash = hash_node(hashes[last], hash)
        width = width * 2UL
        ignore(starts.pop())
        ignore(widths.pop())
        ignore(hashes.pop())
      }
      starts.push(start)
      widths.push(width)
      hashes.push(hash)
    }
  }
  { start: self.start, end: right.end, nodes: hashes, }
}

///|
pub fn CompactRange::append_hash(
  self : CompactRange,
  leaf : Hash32,
) -> CompactRange raise AppendError {
  if self.end == MAX_TREE_SIZE {
    raise InvalidSize
  }
  self.merge({ start: self.end, end: self.end + 1UL, nodes: [leaf], })
}

///|
pub fn CompactRange::append(
  self : CompactRange,
  leaf : Bytes,
) -> CompactRange raise AppendError {
  if leaf.length() > 67108864 {
    raise ByteLimit
  }
  self.append_hash(hash_leaf(leaf))
}

///|
pub fn CompactRange::snapshot(
  self : CompactRange,
) -> Snapshot raise AppendError {
  if self.start != 0UL {
    raise InvalidRange
  }
  let mut root = empty_root()
  for i = self.nodes.length() - 1; i >= 0; i = i - 1 {
    root = if i == self.nodes.length() - 1 {
      self.nodes[i]
    } else {
      hash_node(self.nodes[i], root)
    }
  }
  Snapshot::new(self.end, root)
}

///|
pub fn CompactRange::from_leaves(
  start : UInt64,
  leaves : Array[Bytes],
) -> CompactRange raise AppendError {
  if leaves.length() > 65536 {
    raise LeafLimit
  }
  let mut total = 0
  for leaf in leaves {
    if leaf.length() > 67108864 - total {
      raise ByteLimit
    }
    total = total + leaf.length()
  }
  let mut range = CompactRange::empty(start~)
  for leaf in leaves {
    range = range.append(leaf)
  }
  range
}

///|
fn push_u64(output : Array[Byte], value : UInt64) -> Unit {
  for shift in 0..<8 {
    output.push(((value >> (shift * 8)) & 255UL).to_int().to_byte())
  }
}

///|
fn read_u64(input : Bytes, offset : Int) -> UInt64 {
  let mut value = 0UL
  for i in 0..<8 {
    value = value | (input[offset + i].to_uint64() << (i * 8))
  }
  value
}

///|
/// Versioned bounded state, with a corruption checksum (not a signature).
pub fn CompactRange::checkpoint(self : CompactRange) -> Bytes {
  let output : Array[Byte] = []
  for b in b"MACR\x01" {
    output.push(b)
  }
  push_u64(output, self.start)
  push_u64(output, self.end)
  output.push(self.nodes.length().to_byte())
  for node in self.nodes {
    for b in node.bytes() {
      output.push(b)
    }
  }
  let payload = Bytes::from_array(output[:])
  payload + hash_leaf(payload).bytes()
}

///|
pub fn CompactRange::restore(input : Bytes) -> CompactRange raise AppendError {
  if input.length() < 54 || input.length() > 4086 {
    raise InvalidCheckpoint
  }
  if input[:5].to_owned() != b"MACR\x01" {
    raise InvalidCheckpoint
  }
  let count = input[21].to_int()
  if count > 126 || input.length() != 54 + count * 32 {
    raise InvalidCheckpoint
  }
  let payload = input[:input.length() - 32].to_owned()
  if hash_leaf(payload).bytes() != input[input.length() - 32:].to_owned() {
    raise InvalidCheckpoint
  }
  let nodes = []
  for i in 0..<count {
    nodes.push(Hash32::from_bytes(input[22 + i * 32:54 + i * 32].to_owned()))
  }
  CompactRange::new(read_u64(input, 5), read_u64(input, 13), nodes)
}
