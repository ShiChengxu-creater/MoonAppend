///|
test "all small shard splits merge into the same canonical range and root" {
  let leaves = Array::makei(32, i => Bytes::from_array([i.to_byte()][:]))
  for end in 0..<=32 {
    let whole = @moonappend.CompactRange::from_leaves(
      0UL,
      leaves[:end].to_owned(),
    )
    assert_eq(
      whole.snapshot().root(),
      @moonappend.tree_root(leaves[:end].to_owned()),
    )
    for start in 0..<=end {
      for middle in start..<=end {
        let left = @moonappend.CompactRange::from_leaves(
          start.to_uint64(),
          leaves[start:middle].to_owned(),
        )
        let right = @moonappend.CompactRange::from_leaves(
          middle.to_uint64(),
          leaves[middle:end].to_owned(),
        )
        let expected = @moonappend.CompactRange::from_leaves(
          start.to_uint64(),
          leaves[start:end].to_owned(),
        )
        assert_eq(left.merge(right), expected)
      }
    }
  }
}

///|
test "checkpoint restores exact state and rejects damage truncation and wrong shapes" {
  let original = @moonappend.CompactRange::from_leaves(0UL, [
    b"a", b"b", b"c", b"d", b"e",
  ])
  let encoded = original.checkpoint()
  let recovered = @moonappend.CompactRange::restore(encoded)
  assert_eq(recovered.append(b"f"), original.append(b"f"))
  for i in 0..<encoded.length() {
    let damaged = encoded.to_array()
    damaged[i] = damaged[i] ^ 1
    let rejected = try {
      ignore(@moonappend.CompactRange::restore(Bytes::from_array(damaged[:])))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let rejected = try {
    ignore(
      @moonappend.CompactRange::restore(
        encoded[:encoded.length() - 1].to_owned(),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let gap = try {
    ignore(original.merge(@moonappend.CompactRange::empty(start=6UL)))
    false
  } catch {
    _ => true
  }
  assert_true(gap)
}

///|
test "streaming tree crosses original generation limit with bounded frontier" {
  let mut state = @moonappend.CompactRange::empty()
  for _ in 0..<70000 {
    state = state.append(b"record")
  }
  assert_eq(state.end(), 70000UL)
  assert_true(state.nodes().length() <= 17)
  assert_eq(
    @moonappend.CompactRange::restore(state.checkpoint()).snapshot(),
    state.snapshot(),
  )
}

///|
test "memory batch validates before any mutation" {
  let log = @moonappend.MemoryLog::new(
    limits=@moonappend.Limits::new(max_leaves=3, max_total_bytes=4),
  )
  ignore(log.append_batch([b"a", b"b"]))
  let saved = log.snapshot()
  let rejected = try {
    ignore(log.append_batch([b"c", b"d"]))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(log.snapshot(), saved)
  let bytes_rejected = try {
    ignore(log.append_batch([b"xxx"]))
    false
  } catch {
    _ => true
  }
  assert_true(bytes_rejected)
  assert_eq(log.snapshot(), saved)
  assert_eq(log.append_batch([]), saved)
}
