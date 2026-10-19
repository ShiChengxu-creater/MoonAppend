///|
/// Verify preservation of an old committed prefix. Snapshots are not signed here.
pub fn verify_consistency(
  trusted_old : Snapshot,
  trusted_new : Snapshot,
  proof : ConsistencyProof,
) -> Verification {
  let first = trusted_old.count
  let second = trusted_new.count
  if first > second {
    return Rejected("SIZE_REVERSED")
  }
  if proof.first != first || proof.second != second {
    return Rejected("METADATA_MISMATCH")
  }
  if first == 0UL {
    return if proof.path.is_empty() {
      NoPriorHistory
    } else {
      Rejected("PATH_LENGTH")
    }
  }
  if first == second {
    return if !proof.path.is_empty() {
      Rejected("PATH_LENGTH")
    } else if trusted_old.digest != trusted_new.digest {
      Rejected("ROOT_MISMATCH")
    } else {
      Verified
    }
  }
  if proof.path.is_empty() {
    return Rejected("PATH_LENGTH")
  }
  let mut old_position = first - 1UL
  let mut new_position = second - 1UL
  while (old_position & 1UL) == 1UL {
    old_position = old_position >> 1
    new_position = new_position >> 1
  }
  let mut cursor = 0
  let initial = if old_position == 0UL {
    trusted_old.digest
  } else {
    cursor = 1
    proof.path[0]
  }
  let mut old_root = initial
  let mut new_root = initial
  while cursor < proof.path.length() {
    if new_position == 0UL {
      return Rejected("PATH_LENGTH")
    }
    let node = proof.path[cursor]
    if (old_position & 1UL) == 1UL || old_position == new_position {
      old_root = hash_node(node, old_root)
      new_root = hash_node(node, new_root)
      while old_position != 0UL && (old_position & 1UL) == 0UL {
        old_position = old_position >> 1
        new_position = new_position >> 1
      }
    } else {
      new_root = hash_node(new_root, node)
    }
    old_position = old_position >> 1
    new_position = new_position >> 1
    cursor = cursor + 1
  }
  if new_position != 0UL {
    Rejected("PATH_LENGTH")
  } else if old_root != trusted_old.digest || new_root != trusted_new.digest {
    Rejected("ROOT_MISMATCH")
  } else {
    Verified
  }
}
