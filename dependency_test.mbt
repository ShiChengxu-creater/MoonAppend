///|
test "pinned SHA-256 dependency returns a 32-byte digest" {
  assert_eq(@crypto.sha256(b"").length(), 32)
}
