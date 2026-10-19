///|
test "consistency generator includes unknown old subtree roots in RFC order" {
  let log = @moonappend.MemoryLog::new()
  for leaf in [b"a", b"b", b"c", b"d"] {
    ignore(log.append(leaf))
  }
  assert_eq(log.prove_consistency(2UL, 3UL).nodes(), [
    @moonappend.hash_leaf(b"c"),
  ])
  let proof = log.prove_consistency(3UL, 4UL)
  assert_eq(proof.old_size(), 3UL)
  assert_eq(proof.new_size(), 4UL)
  assert_eq(proof.nodes(), [
    @moonappend.hash_leaf(b"c"),
    @moonappend.hash_leaf(b"d"),
    @moonappend.hash_node(
      @moonappend.hash_leaf(b"a"),
      @moonappend.hash_leaf(b"b"),
    ),
  ])
  assert_eq(log.prove_consistency(3UL, 3UL).nodes().length(), 0)
  assert_eq(log.prove_consistency(0UL, 4UL).nodes().length(), 0)
}

///|
test "growth proof storage is isolated and invalid size ordering is rejected" {
  let nodes = [@moonappend.empty_root()]
  let proof = @moonappend.ConsistencyProof::new(1UL, 2UL, nodes)
  nodes.clear()
  proof.nodes().clear()
  assert_eq(proof.nodes().length(), 1)
  let rejected = try {
    ignore(@moonappend.MemoryLog::new().prove_consistency(2UL, 1UL))
    false
  } catch {
    @moonappend.AppendError::InvalidSize => true
    _ => false
  }
  assert_true(rejected)
}
