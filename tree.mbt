///|
fn split_size(count : Int) -> Int {
  let mut k = 1
  while k * 2 < count {
    k = k * 2
  }
  k
}

///|
fn root_from_hashes(leaves : ArrayView[Hash32]) -> Hash32 {
  match leaves.length() {
    0 => empty_root()
    1 => leaves[0]
    n => {
      let k = split_size(n)
      hash_node(root_from_hashes(leaves[:k]), root_from_hashes(leaves[k:]))
    }
  }
}

///|
/// Bounded reference-style construction. Leaf order is never sorted or padded.
pub fn tree_root(
  leaves : Array[Bytes],
  limits? : Limits = { leaves: 65536, bytes: 67108864, },
) -> Hash32 raise AppendError {
  if leaves.length() > limits.leaves {
    raise LeafLimit
  }
  let mut total = 0
  for leaf in leaves {
    if leaf.length() > limits.bytes - total {
      raise ByteLimit
    }
    total = total + leaf.length()
  }
  let hashes = leaves.map(hash_leaf)
  root_from_hashes(hashes[:])
}
