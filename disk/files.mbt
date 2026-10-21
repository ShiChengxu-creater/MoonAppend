///|
/// Unicode-aware preflight; permission/lookup errors fail rather than mean absent.
pub fn path_exists(path : String) -> Bool raise StorageError {
  let result = io_exists(path_bytes(path))
  if result < 0 {
    raise StorageError("PATH_LOOKUP_FAILED")
  }
  result == 1
}

///|
/// Bounded file input for interchange tools; no whole-file read before size check.
pub fn read_file(path : String, limit? : Int = 16777216) -> Bytes raise Error {
  if limit < 0 || limit > 16777216 {
    raise StorageError("READ_LIMIT")
  }
  let fd = open_file(path, 0)
  defer ignore(io_close(fd))
  let size = io_size(fd)
  if size < 0L || size > limit.to_int64() {
    raise StorageError("INPUT_FILE_LIMIT")
  }
  read_at(fd, 0UL, size.to_int())
}

///|
/// Existing destinations are refused. A failed write may leave a partial new file.
pub fn write_new_file(path : String, value : Bytes) -> Unit raise Error {
  if value.length() > 16777216 {
    raise StorageError("OUTPUT_FILE_LIMIT")
  }
  let fd = open_file(path, 1)
  defer ignore(io_close(fd))
  write_at(fd, 0UL, value)
  if io_sync(fd) != 0 {
    raise StorageError("OUTPUT_SYNC_FAILED")
  }
}
