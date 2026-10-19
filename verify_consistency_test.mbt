///|
test "all 2080 nonempty old-new pairs through size 64 verify" {
  let log = @moonappend.MemoryLog::new()
  for i in 0..<64 {
    ignore(log.append(Bytes::from_array([i.to_byte()][:])))
  }
  let mut count = 0
  for new_size in 1..<=64 {
    for old_size in 1..<=new_size {
      let proof = log.prove_consistency(
        old_size.to_uint64(),
        new_size.to_uint64(),
      )
      assert_true(
        @moonappend.verify_consistency(
          log.snapshot_at(old_size.to_uint64()),
          log.snapshot_at(new_size.to_uint64()),
          proof,
        ).is_verified(),
      )
      count = count + 1
    }
  }
  assert_eq(count, 2080)
}

///|
test "rebuilding a rewritten history cannot validate against the saved old root" {
  let original = @moonappend.MemoryLog::new()
  let rewritten = @moonappend.MemoryLog::new()
  for leaf in [b"a", b"b", b"c", b"d", b"e", b"f", b"g"] {
    ignore(original.append(leaf))
  }
  for leaf in [b"a", b"CHANGED", b"c", b"d", b"e", b"f", b"g"] {
    ignore(rewritten.append(leaf))
  }
  let old = original.snapshot_at(3UL)
  let proof = rewritten.prove_consistency(3UL, 7UL)
  assert_eq(
    @moonappend.verify_consistency(old, rewritten.snapshot(), proof).code(),
    "ROOT_MISMATCH",
  )
  let good = original.prove_consistency(3UL, 7UL)
  assert_eq(
    @moonappend.verify_consistency(old, original.snapshot_at(6UL), good).code(),
    "METADATA_MISMATCH",
  )
  assert_eq(
    @moonappend.verify_consistency(original.snapshot(), old, good).code(),
    "SIZE_REVERSED",
  )
}

///|
test "empty origin equal sizes and extra nodes have explicit outcomes" {
  let log = @moonappend.MemoryLog::new()
  ignore(log.append(b"a"))
  ignore(log.append(b"b"))
  let empty = log.snapshot_at(0UL)
  assert_eq(
    @moonappend.verify_consistency(
      empty,
      log.snapshot(),
      log.prove_consistency(0UL, 2UL),
    ).code(),
    "NO_PRIOR_HISTORY",
  )
  assert_eq(
    @moonappend.verify_consistency(
      log.snapshot(),
      log.snapshot(),
      log.prove_consistency(2UL, 2UL),
    ).code(),
    "VERIFIED",
  )
  let wrong = @moonappend.Snapshot::new(2UL, @moonappend.hash_leaf(b"x"))
  assert_eq(
    @moonappend.verify_consistency(
      log.snapshot(),
      wrong,
      log.prove_consistency(2UL, 2UL),
    ).code(),
    "ROOT_MISMATCH",
  )
  let extra = @moonappend.ConsistencyProof::new(2UL, 2UL, [
    @moonappend.empty_root(),
  ])
  assert_eq(
    @moonappend.verify_consistency(log.snapshot(), log.snapshot(), extra).code(),
    "PATH_LENGTH",
  )
  let short = @moonappend.ConsistencyProof::new(1UL, 2UL, [])
  assert_eq(
    @moonappend.verify_consistency(log.snapshot_at(1UL), log.snapshot(), short).code(),
    "PATH_LENGTH",
  )
}
