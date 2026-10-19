///|
test "empty root and empty leaf use distinct domain-separated SHA-256 inputs" {
  assert_eq(
    @moonappend.empty_root().hex(),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
  assert_eq(
    @moonappend.hash_leaf(b"").hex(),
    "6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d",
  )
  assert_not_eq(@moonappend.hash_leaf(b""), @moonappend.empty_root())
}

///|
test "validated hash encoding round trips and rejects ambiguous representations" {
  let digest = @moonappend.hash_leaf(b"abc")
  assert_eq(@moonappend.Hash32::from_hex(digest.hex()), digest)
  assert_eq(@moonappend.Hash32::from_bytes(digest.bytes()), digest)
  let bad_length = try {
    ignore(@moonappend.Hash32::from_bytes(b"short"))
    false
  } catch {
    @moonappend.AppendError::InvalidHashLength(5) => true
    _ => false
  }
  assert_true(bad_length)
  for
    text in [
      "abc", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    ] {
    let rejected = try {
      ignore(@moonappend.Hash32::from_hex(text))
      false
    } catch {
      @moonappend.AppendError::InvalidHex => true
      _ => false
    }
    assert_true(rejected)
  }
}
