///|
test "snapshots preserve all 63 size bits and validate empty state" {
  let digest = @moonappend.hash_leaf(b"x")
  let size = 9007199254740993UL
  let snapshot = @moonappend.Snapshot::new(size, digest)
  assert_eq(snapshot.size(), size)
  assert_eq(snapshot.root(), digest)
  assert_eq(
    @moonappend.Snapshot::new(0UL, @moonappend.empty_root()).size(),
    0UL,
  )
  for invalid in [0UL, 9223372036854775808UL] {
    let rejected = try {
      ignore(@moonappend.Snapshot::new(invalid, digest))
      false
    } catch {
      @moonappend.AppendError::InvalidSize => true
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "generation limits cannot silently exceed the supported bounds" {
  let limits = @moonappend.Limits::new(max_leaves=2, max_total_bytes=0)
  assert_eq(limits.max_leaves(), 2)
  assert_eq(limits.max_total_bytes(), 0)
  for cap in [-1, 0, 65537] {
    let rejected = try {
      ignore(@moonappend.Limits::new(max_leaves=cap))
      false
    } catch {
      @moonappend.AppendError::InvalidLimits => true
      _ => false
    }
    assert_true(rejected)
  }
}
