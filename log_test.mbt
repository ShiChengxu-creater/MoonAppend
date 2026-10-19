///|
test "incremental roots match batch construction after every append" {
  let log = @moonappend.MemoryLog::new()
  assert_eq(log.snapshot().root(), @moonappend.empty_root())
  let leaves : Array[Bytes] = []
  for i in 0..<130 {
    let leaf = Bytes::from_array([i.to_byte(), (i / 2).to_byte()][:])
    leaves.push(leaf)
    assert_eq(log.append(leaf), i.to_uint64())
    assert_eq(log.snapshot().root(), @moonappend.tree_root(leaves))
    assert_eq(log.size(), (i + 1).to_uint64())
  }
  assert_eq(log.input_bytes(), 260)
}

///|
test "failed append does not alter size root or byte accounting" {
  let log = @moonappend.MemoryLog::new(
    limits=@moonappend.Limits::new(max_leaves=2, max_total_bytes=3),
  )
  ignore(log.append(b"abc"))
  let before = log.snapshot()
  let rejected = try {
    ignore(log.append(b"x"))
    false
  } catch {
    @moonappend.AppendError::ByteLimit => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(log.snapshot(), before)
  assert_eq(log.input_bytes(), 3)
  ignore(log.append(b""))
  let before = log.snapshot()
  let rejected = try {
    ignore(log.append(b""))
    false
  } catch {
    @moonappend.AppendError::LeafLimit => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(log.snapshot(), before)
}
