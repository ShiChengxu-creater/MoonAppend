///|
/// Invalid construction, bounds or resource request. Proof mismatch is a result.
pub(all) suberror AppendError {
  InvalidHashLength(Int)
  InvalidHex
  InvalidSize
  InvalidIndex
  InvalidLimits
  LeafLimit
  ByteLimit
  InvalidProofLength
} derive(Eq, Debug)

///|
pub extend AppendError with Eq::{equal, not_equal}

///|
pub extend AppendError with @debug.Debug::{to_repr}

///|
/// A validated SHA-256 digest. Internal byte storage is not exposed.
pub struct Hash32 {
  priv value : Bytes
} derive(Eq, Debug)

///|
pub extend Hash32 with Eq::{equal, not_equal}

///|
pub extend Hash32 with @debug.Debug::{to_repr}

///|
pub fn Hash32::from_bytes(value : Bytes) -> Hash32 raise AppendError {
  if value.length() != 32 {
    raise InvalidHashLength(value.length())
  }
  { value, }
}

///|
pub fn Hash32::bytes(self : Hash32) -> Bytes {
  self.value
}

///|
pub fn Hash32::hex(self : Hash32) -> String {
  @crypto.bytes_to_hex_string(self.value)
}

///|
fn hex_digit(unit : UInt16) -> Int {
  let n = unit.to_int()
  if n >= 48 && n <= 57 {
    n - 48
  } else if n >= 97 && n <= 102 {
    n - 87
  } else {
    -1
  }
}

///|
/// Strict lowercase 64-digit hexadecimal encoding.
pub fn Hash32::from_hex(value : String) -> Hash32 raise AppendError {
  if value.length() != 64 {
    raise InvalidHex
  }
  let data = Array::make(32, b'\x00')
  for i in 0..<32 {
    let high = hex_digit(value[i * 2])
    let low = hex_digit(value[i * 2 + 1])
    if high < 0 || low < 0 {
      raise InvalidHex
    }
    data[i] = (high * 16 + low).to_byte()
  }
  { value: Bytes::from_array(data[:]), }
}

///|
/// HASH(empty); distinct from the hash of an empty leaf.
pub fn empty_root() -> Hash32 {
  { value: Bytes::from_array(@crypto.sha256(b"")[:]), }
}

///|
pub fn hash_leaf(data : Bytes) -> Hash32 {
  let ctx = @crypto.SHA256::new()
  ctx.update(b"\x00")
  ctx.update(data)
  { value: Bytes::from_array(ctx.finalize()[:]), }
}

///|
pub fn hash_node(left : Hash32, right : Hash32) -> Hash32 {
  let ctx = @crypto.SHA256::new()
  ctx.update(b"\x01")
  ctx.update(left.value)
  ctx.update(right.value)
  { value: Bytes::from_array(ctx.finalize()[:]), }
}
