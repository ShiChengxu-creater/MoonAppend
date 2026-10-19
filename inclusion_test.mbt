///|
test "three-leaf inclusion paths are bottom-up and preserve history" {
  let log = @moonappend.MemoryLog::new()
  for leaf in [b"a", b"b", b"c", b"d"] {
    ignore(log.append(leaf))
  }
  let proof = log.prove_inclusion(2UL, 3UL)
  assert_eq(proof.leaf_index(), 2UL)
  assert_eq(proof.tree_size(), 3UL)
  assert_eq(proof.nodes(), [
    @moonappend.hash_node(
      @moonappend.hash_leaf(b"a"),
      @moonappend.hash_leaf(b"b"),
    ),
  ])
  assert_eq(log.prove_inclusion(0UL, 3UL).nodes(), [
    @moonappend.hash_leaf(b"b"),
    @moonappend.hash_leaf(b"c"),
  ])
  assert_eq(log.prove_inclusion(0UL, 1UL).nodes().length(), 0)
}

///|
test "proof paths do not alias caller-owned arrays" {
  let nodes = [@moonappend.hash_leaf(b"x")]
  let proof = @moonappend.InclusionProof::new(0UL, 2UL, nodes)
  nodes.clear()
  let copy = proof.nodes()
  copy.clear()
  assert_eq(proof.nodes().length(), 1)
}
