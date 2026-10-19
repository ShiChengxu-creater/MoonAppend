///|
pub struct InclusionProof {
  priv index : UInt64
  priv count : UInt64
  priv path : Array[Hash32]
} derive(Eq, Debug)

///|
pub extend InclusionProof with Eq::{equal, not_equal}

///|
pub extend InclusionProof with @debug.Debug::{to_repr}

///|
/// Copy the caller's array so later mutation cannot alter this proof.
pub fn InclusionProof::new(
  index : UInt64,
  size : UInt64,
  nodes : Array[Hash32],
) -> InclusionProof raise AppendError {
  if size == 0UL || size > MAX_TREE_SIZE || index >= size {
    raise InvalidIndex
  }
  if nodes.length() > 128 {
    raise InvalidProofLength
  }
  { index, count: size, path: nodes[:].to_owned(), }
}

///|
pub fn InclusionProof::leaf_index(self : InclusionProof) -> UInt64 {
  self.index
}

///|
pub fn InclusionProof::tree_size(self : InclusionProof) -> UInt64 {
  self.count
}

///|
pub fn InclusionProof::nodes(self : InclusionProof) -> Array[Hash32] {
  self.path[:].to_owned()
}

///|
fn MemoryLog::inclusion_path(
  self : MemoryLog,
  start : Int,
  count : Int,
  index : Int,
  path : Array[Hash32],
) -> Unit {
  if count == 1 {
    return
  }
  let k = split_size(count)
  if index < k {
    self.inclusion_path(start, k, index, path)
    path.push(self.range_root(start + k, count - k))
  } else {
    self.inclusion_path(start + k, count - k, index - k, path)
    path.push(self.range_root(start, k))
  }
}

///|
pub fn MemoryLog::prove_inclusion(
  self : MemoryLog,
  index : UInt64,
  size : UInt64,
) -> InclusionProof raise AppendError {
  if size > self.size() {
    raise InvalidSize
  }
  if index >= size {
    raise InvalidIndex
  }
  let path = []
  self.inclusion_path(0, size.to_int(), index.to_int(), path)
  { index, count: size, path, }
}
