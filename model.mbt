///|
pub const MAX_TREE_SIZE : UInt64 = 9223372036854775807UL

///|
/// An unsigned, unauthenticated commitment. Trust is supplied by the caller.
pub struct Snapshot {
  priv count : UInt64
  priv digest : Hash32
} derive(Eq, Debug)

///|
pub extend Snapshot with Eq::{equal, not_equal}

///|
pub extend Snapshot with @debug.Debug::{to_repr}

///|
pub fn Snapshot::new(
  size : UInt64,
  root : Hash32,
) -> Snapshot raise AppendError {
  if size > MAX_TREE_SIZE || (size == 0UL && root != empty_root()) {
    raise InvalidSize
  }
  { count: size, digest: root, }
}

///|
pub fn Snapshot::size(self : Snapshot) -> UInt64 {
  self.count
}

///|
pub fn Snapshot::root(self : Snapshot) -> Hash32 {
  self.digest
}

///|
/// Generation limits may only tighten the absolute alpha caps.
pub struct Limits {
  priv leaves : Int
  priv bytes : Int
}

///|
pub fn Limits::new(
  max_leaves? : Int = 65536,
  max_total_bytes? : Int = 67108864,
) -> Limits raise AppendError {
  if max_leaves <= 0 ||
    max_leaves > 65536 ||
    max_total_bytes < 0 ||
    max_total_bytes > 67108864 {
    raise InvalidLimits
  }
  { leaves: max_leaves, bytes: max_total_bytes, }
}

///|
pub fn Limits::max_leaves(self : Limits) -> Int {
  self.leaves
}

///|
pub fn Limits::max_total_bytes(self : Limits) -> Int {
  self.bytes
}
