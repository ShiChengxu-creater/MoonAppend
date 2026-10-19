///|
test "ordered three-leaf tree uses the largest strict power-of-two split" {
  let a = @moonappend.hash_leaf(b"a")
  let b = @moonappend.hash_leaf(b"b")
  let c = @moonappend.hash_leaf(b"c")
  let actual = @moonappend.tree_root([b"a", b"b", b"c"])
  assert_eq(actual, @moonappend.hash_node(@moonappend.hash_node(a, b), c))
  assert_not_eq(
    actual,
    @moonappend.hash_node(
      @moonappend.hash_node(a, b),
      @moonappend.hash_node(c, c),
    ),
  )
  assert_not_eq(actual, @moonappend.tree_root([b"b", b"a", b"c"]))
  assert_eq(@moonappend.tree_root([]), @moonappend.empty_root())
  assert_eq(@moonappend.tree_root([b"a"]), a)
}

///|
test "batch construction checks byte and leaf budgets before hashing" {
  let rejected = try {
    ignore(
      @moonappend.tree_root(
        [b"abc", b"d"],
        limits=@moonappend.Limits::new(max_total_bytes=3),
      ),
    )
    false
  } catch {
    @moonappend.AppendError::ByteLimit => true
    _ => false
  }
  assert_true(rejected)
  let rejected = try {
    ignore(
      @moonappend.tree_root(
        [b"", b""],
        limits=@moonappend.Limits::new(max_leaves=1),
      ),
    )
    false
  } catch {
    @moonappend.AppendError::LeafLimit => true
    _ => false
  }
  assert_true(rejected)
}
