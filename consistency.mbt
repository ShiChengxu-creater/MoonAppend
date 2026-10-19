///|
pub struct ConsistencyProof {
  priv first : UInt64
  priv second : UInt64
  priv path : Array[Hash32]
} derive(Eq, Debug)

///|
pub extend ConsistencyProof with Eq::{equal, not_equal}

///|
pub extend ConsistencyProof with @debug.Debug::{to_repr}

///|
pub fn ConsistencyProof::new(
  old_size : UInt64,
  new_size : UInt64,
  nodes : Array[Hash32],
) -> ConsistencyProof raise AppendError {
  if old_size > new_size || new_size > MAX_TREE_SIZE {
    raise InvalidSize
  }
  if nodes.length() > 128 {
    raise InvalidProofLength
  }
  { first: old_size, second: new_size, path: nodes[:].to_owned(), }
}

///|
pub fn ConsistencyProof::old_size(self : ConsistencyProof) -> UInt64 {
  self.first
}

///|
pub fn ConsistencyProof::new_size(self : ConsistencyProof) -> UInt64 {
  self.second
}

///|
pub fn ConsistencyProof::nodes(self : ConsistencyProof) -> Array[Hash32] {
  self.path[:].to_owned()
}

///|
fn MemoryLog::consistency_path(
  self : MemoryLog,
  start : Int,
  old_size : Int,
  new_size : Int,
  known_root : Bool,
  path : Array[Hash32],
) -> Unit {
  if old_size == new_size {
    if !known_root {
      path.push(self.range_root(start, new_size))
    }
    return
  }
  let k = split_size(new_size)
  if old_size <= k {
    self.consistency_path(start, old_size, k, known_root, path)
    path.push(self.range_root(start + k, new_size - k))
  } else {
    self.consistency_path(start + k, old_size - k, new_size - k, false, path)
    path.push(self.range_root(start, k))
  }
}

///|
pub fn MemoryLog::prove_consistency(
  self : MemoryLog,
  old_size : UInt64,
  new_size : UInt64,
) -> ConsistencyProof raise AppendError {
  if old_size > new_size || new_size > self.size() {
    raise InvalidSize
  }
  let path = []
  if old_size != 0UL && old_size != new_size {
    self.consistency_path(0, old_size.to_int(), new_size.to_int(), true, path)
  }
  { first: old_size, second: new_size, path, }
}
