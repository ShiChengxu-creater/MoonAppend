///|
test "every leaf at every prefix through 64 verifies against the caller snapshot" {
  let log = @moonappend.MemoryLog::new()
  let leaves : Array[Bytes] = []
  for i in 0..<64 {
    let leaf = Bytes::from_array([i.to_byte()][:])
    leaves.push(leaf)
    ignore(log.append(leaf))
  }
  for size in 1..<=64 {
    let head = log.snapshot_at(size.to_uint64())
    for index in 0..<size {
      let proof = log.prove_inclusion(index.to_uint64(), size.to_uint64())
      assert_true(
        @moonappend.verify_inclusion(
          head,
          index.to_uint64(),
          leaves[index],
          proof,
        ).is_verified(),
      )
      assert_eq(
        @moonappend.verify_inclusion(head, index.to_uint64(), b"changed", proof).code(),
        "ROOT_MISMATCH",
      )
    }
  }
}

///|
test "inclusion rejects missing extra paths wrong sizes indices and roots" {
  let log = @moonappend.MemoryLog::new()
  for leaf in [b"a", b"b", b"c"] {
    ignore(log.append(leaf))
  }
  let head = log.snapshot()
  let proof = log.prove_inclusion(0UL, 3UL)
  assert_eq(
    @moonappend.verify_inclusion(head, 1UL, b"a", proof).code(),
    "METADATA_MISMATCH",
  )
  assert_eq(
    @moonappend.verify_inclusion(log.snapshot_at(2UL), 0UL, b"a", proof).code(),
    "METADATA_MISMATCH",
  )
  let wrong_root = @moonappend.Snapshot::new(
    3UL,
    @moonappend.hash_leaf(b"wrong"),
  )
  assert_eq(
    @moonappend.verify_inclusion(wrong_root, 0UL, b"a", proof).code(),
    "ROOT_MISMATCH",
  )
  let short = @moonappend.InclusionProof::new(
    0UL,
    3UL,
    proof.nodes()[:1].to_owned(),
  )
  assert_eq(
    @moonappend.verify_inclusion(head, 0UL, b"a", short).code(),
    "PATH_LENGTH",
  )
  let nodes = proof.nodes()
  nodes.push(@moonappend.empty_root())
  let long = @moonappend.InclusionProof::new(0UL, 3UL, nodes)
  assert_eq(
    @moonappend.verify_inclusion(head, 0UL, b"a", long).code(),
    "PATH_LENGTH",
  )
}
