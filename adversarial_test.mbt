///|
test "every altered inclusion sibling is rejected across irregular tree shapes" {
  let log = @moonappend.MemoryLog::new()
  let leaves : Array[Bytes] = []
  for i in 0..<33 {
    let leaf = Bytes::from_array([i.to_byte(), 0xff][:])
    leaves.push(leaf)
    ignore(log.append(leaf))
  }
  for size in 2..<=33 {
    let head = log.snapshot_at(size.to_uint64())
    for index in 0..<size {
      let good = log.prove_inclusion(index.to_uint64(), size.to_uint64())
      for position in 0..<good.nodes().length() {
        let nodes = good.nodes()
        nodes[position] = @moonappend.hash_leaf(b"tampered sibling")
        let bad = @moonappend.InclusionProof::new(
          index.to_uint64(),
          size.to_uint64(),
          nodes,
        )
        assert_false(
          @moonappend.verify_inclusion(
            head,
            index.to_uint64(),
            leaves[index],
            bad,
          ).is_verified(),
        )
      }
      let nodes = good.nodes()
      nodes.push(@moonappend.hash_leaf(b"extra"))
      let extra = @moonappend.InclusionProof::new(
        index.to_uint64(),
        size.to_uint64(),
        nodes,
      )
      assert_eq(
        @moonappend.verify_inclusion(
          head,
          index.to_uint64(),
          leaves[index],
          extra,
        ).code(),
        "PATH_LENGTH",
      )
    }
  }
}

///|
test "every altered consistency sibling and path truncation is rejected" {
  let log = @moonappend.MemoryLog::new()
  for i in 0..<33 {
    ignore(log.append(Bytes::from_array([i.to_byte()][:])))
  }
  for new_size in 2..<=33 {
    for old_size in 1..<new_size {
      let first = old_size.to_uint64()
      let second = new_size.to_uint64()
      let old = log.snapshot_at(first)
      let head = log.snapshot_at(second)
      let good = log.prove_consistency(first, second)
      let original = good.nodes()
      for position in 0..<original.length() {
        let nodes = good.nodes()
        nodes[position] = @moonappend.hash_leaf(b"tampered sibling")
        assert_false(
          @moonappend.verify_consistency(
            old,
            head,
            @moonappend.ConsistencyProof::new(first, second, nodes),
          ).is_verified(),
        )
      }
      let short = original[:original.length() - 1].to_owned()
      assert_false(
        @moonappend.verify_consistency(
          old,
          head,
          @moonappend.ConsistencyProof::new(first, second, short),
        ).is_verified(),
      )
      let extra = good.nodes()
      extra.push(@moonappend.empty_root())
      assert_eq(
        @moonappend.verify_consistency(
          old,
          head,
          @moonappend.ConsistencyProof::new(first, second, extra),
        ).code(),
        "PATH_LENGTH",
      )
    }
  }
}

///|
test "oversized paths invalid public construction and empty proofs fail explicitly" {
  let too_many = Array::make(129, @moonappend.empty_root())
  let inclusion_rejected = try {
    ignore(@moonappend.InclusionProof::new(0UL, 1UL, too_many))
    false
  } catch {
    @moonappend.AppendError::InvalidProofLength => true
    _ => false
  }
  let consistency_rejected = try {
    ignore(@moonappend.ConsistencyProof::new(1UL, 2UL, too_many))
    false
  } catch {
    @moonappend.AppendError::InvalidProofLength => true
    _ => false
  }
  assert_true(inclusion_rejected && consistency_rejected)
  let empty = @moonappend.Snapshot::new(0UL, @moonappend.empty_root())
  let malformed = @moonappend.ConsistencyProof::new(0UL, 0UL, [
    @moonappend.empty_root(),
  ])
  assert_eq(
    @moonappend.verify_consistency(empty, empty, malformed).code(),
    "PATH_LENGTH",
  )
  for size in [0UL, 9223372036854775808UL, 18446744073709551615UL] {
    let rejected = try {
      ignore(@moonappend.InclusionProof::new(0UL, size, []))
      false
    } catch {
      @moonappend.AppendError::InvalidIndex => true
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "duplicate empty records preserve count and old commitment semantics" {
  let log = @moonappend.MemoryLog::new(
    limits=@moonappend.Limits::new(max_total_bytes=0),
  )
  for _ in 0..<17 {
    ignore(log.append(b""))
  }
  let old = log.snapshot_at(7UL)
  let head = log.snapshot()
  assert_true(
    @moonappend.verify_consistency(old, head, log.prove_consistency(7UL, 17UL)).is_verified(),
  )
  assert_true(
    @moonappend.verify_inclusion(
      head,
      16UL,
      b"",
      log.prove_inclusion(16UL, 17UL),
    ).is_verified(),
  )
  assert_eq(log.input_bytes(), 0)
  assert_not_eq(old.root(), head.root())
}
