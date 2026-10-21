///|
pub(all) suberror StorageError {
  StorageError(String)
} derive(Debug)

///|
pub extend StorageError with @debug.Debug::{to_repr}

///|
#borrow(path)
extern "C" fn io_mkdir(path : Bytes) -> Int = "ma_mkdir"

///|
#borrow(path)
extern "C" fn io_exists(path : Bytes) -> Int = "ma_exists"

///|
#borrow(path)
extern "C" fn io_open(path : Bytes, mode : Int) -> Int = "ma_open"

///|
extern "C" fn io_close(fd : Int) -> Int = "ma_close"

///|
extern "C" fn io_size(fd : Int) -> Int64 = "ma_size"

///|
extern "C" fn io_sync(fd : Int) -> Int = "ma_sync"

///|
extern "C" fn io_truncate(fd : Int, size : Int64) -> Int = "ma_truncate"

///|
#borrow(data)
extern "C" fn io_read(
  fd : Int,
  offset : Int64,
  data : FixedArray[Byte],
  length : Int,
) -> Int = "ma_read"

///|
#borrow(data)
extern "C" fn io_write(
  fd : Int,
  offset : Int64,
  data : Bytes,
  length : Int,
) -> Int = "ma_write"

///|
#borrow(dir, from, to)
extern "C" fn io_replace(dir : Bytes, from : Bytes, to : Bytes) -> Int = "ma_replace"

///|
fn path_bytes(path : String) -> Bytes raise StorageError {
  if path.is_empty() || path.contains("\u0000") {
    raise StorageError("INVALID_PATH")
  }
  @utf8.encode(path) + b"\x00"
}

///|
fn open_file(path : String, mode : Int) -> Int raise StorageError {
  let fd = io_open(path_bytes(path), mode)
  if fd < 0 {
    raise StorageError("OPEN_OR_LOCK_FAILED: \{path}")
  }
  fd
}

///|
fn read_at(fd : Int, offset : UInt64, length : Int) -> Bytes raise StorageError {
  if offset > 9223372036854775807UL || length < 0 || length > 16777216 {
    raise StorageError("READ_LIMIT")
  }
  let output = FixedArray::make(length, b'\x00')
  if io_read(fd, offset.reinterpret_as_int64(), output, length) != 0 {
    raise StorageError("READ_FAILED")
  }
  Bytes::from_array(output[:])
}

///|
fn write_at(
  fd : Int,
  offset : UInt64,
  value : Bytes,
) -> Unit raise StorageError {
  if offset > 9223372036854775807UL - value.length().to_uint64() {
    raise StorageError("OFFSET_LIMIT")
  }
  if io_write(fd, offset.reinterpret_as_int64(), value, value.length()) != 0 {
    raise StorageError("WRITE_FAILED")
  }
}

///|
fn put_u64(output : Array[Byte], value : UInt64) -> Unit {
  for i in 0..<8 {
    output.push(((value >> (i * 8)) & 255UL).to_int().to_byte())
  }
}

///|
fn get_u64(data : Bytes, offset : Int) -> UInt64 {
  let mut value = 0UL
  for i in 0..<8 {
    value = value | (data[offset + i].to_uint64() << (i * 8))
  }
  value
}

///|
fn popcount(value : UInt64) -> UInt64 {
  let mut n = value
  let mut total = 0UL
  while n != 0UL {
    n = n & (n - 1UL)
    total = total + 1UL
  }
  total
}

///|
fn node_count(leaves : UInt64) -> UInt64 {
  leaves * 2UL - popcount(leaves)
}
