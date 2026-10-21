///|
test "every interval of every prefix through 25 binds all records and shared nodes" {
  let leaves = Array::makei(25, i => Bytes::from_array([i.to_byte()][:]))
  let log = @moonappend.MemoryLog::new()
  ignore(log.append_batch(leaves))
  for size in 1..<=25 {
    let snapshot = log.snapshot_at(size.to_uint64())
    for start in 0..<size {
      for end in (start + 1)..<=size {
        let proof = log.prove_range(
          start.to_uint64(),
          end.to_uint64(),
          size.to_uint64(),
        )
        let records = leaves[start:end].to_owned()
        assert_true(
          @moonappend.verify_range(snapshot, start.to_uint64(), records, proof).is_verified(),
        )
        records[0] = b"changed"
        assert_false(
          @moonappend.verify_range(snapshot, start.to_uint64(), records, proof).is_verified(),
        )
        for position in 0..<proof.nodes().length() {
          let nodes = proof.nodes()
          nodes[position] = @moonappend.hash_leaf(b"changed sibling")
          let bad = @moonappend.RangeProof::new(
            start.to_uint64(),
            end.to_uint64(),
            size.to_uint64(),
            nodes,
          )
          assert_false(
            @moonappend.verify_range(
              snapshot,
              start.to_uint64(),
              leaves[start:end].to_owned(),
              bad,
            ).is_verified(),
          )
        }
      }
    }
  }
}

///|
test "reader-backed RFC proofs equal the existing in-memory generator" {
  let log = @moonappend.MemoryLog::new()
  for i in 0..<40 {
    ignore(log.append(Bytes::from_array([i.to_byte()][:])))
  }
  let reader : (Int, UInt64) -> @moonappend.Hash32 raise Error = (level, index) => {
    log.read_node(level, index)
  }
  for size in 1..<=40 {
    let n = size.to_uint64()
    assert_eq(@moonappend.snapshot_from_reader(n, reader), log.snapshot_at(n))
    for i in 0..<size {
      assert_eq(
        @moonappend.inclusion_from_reader(i.to_uint64(), n, reader),
        log.prove_inclusion(i.to_uint64(), n),
      )
    }
    for old in 0..<=size {
      assert_eq(
        @moonappend.consistency_from_reader(old.to_uint64(), n, reader),
        log.prove_consistency(old.to_uint64(), n),
      )
    }
  }
}

///|
test "range proof boundaries exact path counts and copied arrays are enforced" {
  let log = @moonappend.MemoryLog::new()
  ignore(log.append_batch([b"a", b"b", b"c", b"d", b"e"]))
  let good = log.prove_range(1UL, 4UL, 5UL)
  assert_false(
    @moonappend.verify_range(log.snapshot(), 0UL, [b"b", b"c", b"d"], good).is_verified(),
  )
  assert_false(
    @moonappend.verify_range(log.snapshot(), 1UL, [b"b", b"c"], good).is_verified(),
  )
  assert_false(
    @moonappend.verify_range(log.snapshot(), 1UL, [b"d", b"c", b"b"], good).is_verified(),
  )
  let nodes = good.nodes()
  let copied = @moonappend.RangeProof::new(1UL, 4UL, 5UL, nodes)
  nodes[0] = @moonappend.empty_root()
  assert_eq(copied, good)
  for tuple in [(1UL, 1UL, 5UL), (4UL, 3UL, 5UL), (0UL, 6UL, 5UL)] {
    let rejected = try {
      ignore(@moonappend.RangeProof::new(tuple.0, tuple.1, tuple.2, []))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let extra = good.nodes()
  extra.push(@moonappend.empty_root())
  let rejected = try {
    ignore(@moonappend.RangeProof::new(1UL, 4UL, 5UL, extra))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
