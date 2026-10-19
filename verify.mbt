///|
/// This result does not authenticate the supplied snapshots.
pub(all) enum Verification {
  Verified
  Rejected(String)
  NoPriorHistory
} derive(Eq, Debug)

///|
pub extend Verification with Eq::{equal, not_equal}

///|
pub extend Verification with @debug.Debug::{to_repr}

///|
pub fn Verification::is_verified(self : Verification) -> Bool {
  self is Verified
}

///|
pub fn Verification::code(self : Verification) -> String {
  match self {
    Verified => "VERIFIED"
    Rejected(code) => code
    NoPriorHistory => "NO_PRIOR_HISTORY"
  }
}

///|
/// The expected snapshot and index must come from the caller, not the proof.
pub fn verify_inclusion(
  trusted : Snapshot,
  index : UInt64,
  leaf : Bytes,
  proof : InclusionProof,
) -> Verification {
  if proof.count != trusted.count || proof.index != index {
    return Rejected("METADATA_MISMATCH")
  }
  if trusted.count == 0UL || index >= trusted.count {
    return Rejected("INDEX_OUT_OF_RANGE")
  }
  if leaf.length() > 67108864 {
    return Rejected("LEAF_TOO_LARGE")
  }
  let mut position = index
  let mut last = trusted.count - 1UL
  let mut current = hash_leaf(leaf)
  for sibling in proof.path {
    if last == 0UL {
      return Rejected("PATH_LENGTH")
    }
    if (position & 1UL) == 1UL || position == last {
      current = hash_node(sibling, current)
      while position != 0UL && (position & 1UL) == 0UL {
        position = position >> 1
        last = last >> 1
      }
    } else {
      current = hash_node(current, sibling)
    }
    position = position >> 1
    last = last >> 1
  }
  if last != 0UL {
    Rejected("PATH_LENGTH")
  } else if current != trusted.digest {
    Rejected("ROOT_MISMATCH")
  } else {
    Verified
  }
}
