///|
test "all historical prefix roots remain stable after later appends" {
  let log = @moonappend.MemoryLog::new()
  let snapshots = [log.snapshot()]
  let leaves : Array[Bytes] = []
  for i in 0..<65 {
    let leaf = Bytes::from_array([i.to_byte()][:])
    leaves.push(leaf)
    ignore(log.append(leaf))
    snapshots.push(log.snapshot())
  }
  for size in 0..<=65 {
    assert_eq(log.snapshot_at(size.to_uint64()), snapshots[size])
    assert_eq(
      log.snapshot_at(size.to_uint64()).root(),
      @moonappend.tree_root(leaves[:size].to_owned()),
    )
  }
  let rejected = try {
    ignore(log.snapshot_at(66UL))
    false
  } catch {
    @moonappend.AppendError::InvalidSize => true
    _ => false
  }
  assert_true(rejected)
  let rejected = try {
    ignore(log.snapshot_at(18446744073709551615UL))
    false
  } catch {
    @moonappend.AppendError::InvalidSize => true
    _ => false
  }
  assert_true(rejected)
}
