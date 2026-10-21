///|
/// Single writer, append-only file log. Call close explicitly to release its OS lock.
pub struct DiskLog {
  priv path : String
  priv files : Array[Int]
  priv mut state : @tree.CompactRange
  priv mut payload_end : UInt64
  priv recovered : UInt64
  priv mut closed : Bool
  priv mut poisoned : Bool
}

///|
pub const MAX_DISK_LEAVES : UInt64 = 72057594037927935UL

///|
fn state_bytes(state : @tree.CompactRange, payload_end : UInt64) -> Bytes {
  let output : Array[Byte] = []
  for b in b"MADL\x01" {
    output.push(b)
  }
  put_u64(output, payload_end)
  let payload = Bytes::from_array(output[:]) + state.checkpoint()
  payload + @tree.hash_leaf(payload).bytes()
}

///|
fn commit_state(
  path : String,
  state : @tree.CompactRange,
  payload_end : UInt64,
) -> Unit raise Error {
  let fd = open_file(path + "/state.tmp", 3)
  {
    defer ignore(io_close(fd))
    write_at(fd, 0UL, state_bytes(state, payload_end))
    if io_sync(fd) != 0 {
      raise StorageError("STATE_SYNC_FAILED")
    }
  }
  if io_replace(
      path_bytes(path),
      path_bytes(path + "/state.tmp"),
      path_bytes(path + "/state"),
    ) !=
    0 {
    raise StorageError("STATE_COMMIT_UNCERTAIN")
  }
}

///|
fn open_files(path : String, create : Bool) -> Array[Int] raise Error {
  let opened = []
  errdefer (for fd in opened {
    ignore(io_close(fd))
  })
  opened.push(open_file(path + "/lock", 4))
  for name in ["nodes", "index", "payload"] {
    opened.push(open_file(path + "/" + name, if create { 1 } else { 2 }))
  }
  opened
}

///|
pub fn DiskLog::create(path : String) -> DiskLog raise Error {
  if io_mkdir(path_bytes(path)) != 0 {
    raise StorageError("DIRECTORY_EXISTS_OR_CREATE_FAILED")
  }
  let files = open_files(path, true)
  errdefer (for fd in files {
    ignore(io_close(fd))
  })
  let state = @tree.CompactRange::empty()
  commit_state(path, state, 0UL)
  {
    path,
    files,
    state,
    payload_end: 0UL,
    recovered: 0UL,
    closed: false,
    poisoned: false,
  }
}

///|
pub fn DiskLog::open(path : String) -> DiskLog raise Error {
  let files = open_files(path, false)
  errdefer (for fd in files {
    ignore(io_close(fd))
  })
  let fd = open_file(path + "/state", 0)
  let data = {
    defer ignore(io_close(fd))
    let length = io_size(fd)
    if length < 99L || length > 8192L {
      raise StorageError("INVALID_STATE_LENGTH")
    }
    read_at(fd, 0UL, length.to_int())
  }
  if data[:5].to_owned() != b"MADL\x01" {
    raise StorageError("INVALID_STATE_VERSION")
  }
  let payload = data[:data.length() - 32].to_owned()
  if @tree.hash_leaf(payload).bytes() != data[data.length() - 32:].to_owned() {
    raise StorageError("STATE_CHECKSUM")
  }
  let state = @tree.CompactRange::restore(
    data[13:data.length() - 32].to_owned(),
  )
  let end = get_u64(data, 5)
  if state.start() != 0UL ||
    state.end() > MAX_DISK_LEAVES ||
    end > 9223372036854775807UL {
    raise StorageError("STATE_LIMIT")
  }
  let expected = [node_count(state.end()) * 32UL, state.end() * 16UL, end]
  let mut recovered = 0UL
  // Inspect every size before truncating any tail. Short committed files fail closed.
  for i in 0..<3 {
    let actual = io_size(files[i + 1])
    if actual < 0L || actual.reinterpret_as_uint64() < expected[i] {
      raise StorageError("COMMITTED_FILE_TRUNCATED")
    }
    recovered = recovered + actual.reinterpret_as_uint64() - expected[i]
  }
  let log = {
    path,
    files,
    state,
    payload_end: end,
    recovered,
    closed: false,
    poisoned: false,
  }
  // Validate committed frontier before performing recovery writes.
  let actual = @tree.snapshot_from_reader(state.end(), (level, index) => {
    log.read_node(level, index)
  })
  if actual != state.snapshot() {
    raise StorageError("CHECKPOINT_NODE_MISMATCH")
  }
  for i in 0..<3 {
    if io_size(files[i + 1]).reinterpret_as_uint64() > expected[i] {
      if io_truncate(files[i + 1], expected[i].reinterpret_as_int64()) != 0 ||
        io_sync(files[i + 1]) != 0 {
        raise StorageError("TAIL_RECOVERY_FAILED")
      }
    }
  }
  log
}

///|
fn DiskLog::ready(self : DiskLog) -> Unit raise StorageError {
  if self.closed {
    raise StorageError("CLOSED")
  }
  if self.poisoned {
    raise StorageError("COMMIT_FAILED_REOPEN_REQUIRED")
  }
}

///|
pub fn DiskLog::close(self : DiskLog) -> Unit {
  if !self.closed {
    // The lock is released last; closing the process also releases this OS lock.
    for i in 1..<self.files.length() {
      ignore(io_close(self.files[i]))
    }
    ignore(io_close(self.files[0]))
    self.closed = true
  }
}

///|
pub fn DiskLog::snapshot(self : DiskLog) -> @tree.Snapshot raise Error {
  self.ready()
  self.state.snapshot()
}

///|
pub fn DiskLog::recovered_bytes(self : DiskLog) -> UInt64 {
  self.recovered
}

///|
pub fn DiskLog::read_node(
  self : DiskLog,
  level : Int,
  index : UInt64,
) -> @tree.Hash32 raise Error {
  self.ready()
  if level < 0 || level > 55 {
    raise StorageError("INVALID_NODE")
  }
  let width = 1UL << level
  if index >= self.state.end() / width {
    raise StorageError("NODE_OUT_OF_RANGE")
  }
  let last = (index + 1UL) * width
  let ordinal = node_count(last - 1UL) + level.to_uint64()
  @tree.Hash32::from_bytes(read_at(self.files[1], ordinal * 32UL, 32))
}

///|
pub fn DiskLog::snapshot_at(
  self : DiskLog,
  size : UInt64,
) -> @tree.Snapshot raise Error {
  self.ready()
  if size > self.state.end() {
    raise StorageError("SIZE_OUT_OF_RANGE")
  }
  @tree.snapshot_from_reader(size, (level, index) => {
    self.read_node(level, index)
  })
}

///|
pub fn DiskLog::read_entry(self : DiskLog, index : UInt64) -> Bytes raise Error {
  self.ready()
  if index >= self.state.end() {
    raise StorageError("INDEX_OUT_OF_RANGE")
  }
  let record = read_at(self.files[2], index * 16UL, 16)
  let offset = get_u64(record, 0)
  let length = get_u64(record, 8)
  if offset > self.payload_end ||
    length > 1048576UL ||
    length > self.payload_end - offset {
    raise StorageError("CORRUPT_INDEX")
  }
  let entry = read_at(self.files[3], offset, length.to_int())
  if @tree.hash_leaf(entry) != self.read_node(0, index) {
    raise StorageError("CORRUPT_ENTRY")
  }
  entry
}

///|
pub fn DiskLog::append_batch(
  self : DiskLog,
  entries : Array[Bytes],
) -> @tree.Snapshot raise Error {
  self.ready()
  if entries.is_empty() {
    return self.snapshot()
  }
  if entries.length() > 4096 ||
    entries.length().to_uint64() > MAX_DISK_LEAVES - self.state.end() {
    raise StorageError("BATCH_LEAF_LIMIT")
  }
  let mut bytes = 0
  for entry in entries {
    if entry.length() > 1048576 || entry.length() > 16777216 - bytes {
      raise StorageError("BATCH_BYTE_LIMIT")
    }
    bytes = bytes + entry.length()
  }
  if bytes.to_uint64() > 9223372036854775807UL - self.payload_end {
    raise StorageError("PAYLOAD_LIMIT")
  }
  let old_size = self.state.end()
  let mut size = old_size
  let frontier = self.state.nodes()
  let nodes : Array[Byte] = []
  let index : Array[Byte] = []
  let payload : Array[Byte] = []
  for entry in entries {
    put_u64(index, self.payload_end + payload.length().to_uint64())
    put_u64(index, entry.length().to_uint64())
    for b in entry {
      payload.push(b)
    }
    let mut hash = @tree.hash_leaf(entry)
    for b in hash.bytes() {
      nodes.push(b)
    }
    let mut position = size
    while (position & 1UL) == 1UL {
      hash = @tree.hash_node(frontier.pop().unwrap(), hash)
      for b in hash.bytes() {
        nodes.push(b)
      }
      position = position >> 1
    }
    frontier.push(hash)
    size = size + 1UL
  }
  let state = @tree.CompactRange::new(0UL, size, frontier)
  let end = self.payload_end + bytes.to_uint64()
  {
    errdefer {
      self.poisoned = true
    }
    write_at(
      self.files[1],
      node_count(old_size) * 32UL,
      Bytes::from_array(nodes[:]),
    )
    write_at(self.files[2], old_size * 16UL, Bytes::from_array(index[:]))
    write_at(self.files[3], self.payload_end, Bytes::from_array(payload[:]))
    for i in 1..<4 {
      if io_sync(self.files[i]) != 0 {
        raise StorageError("DATA_SYNC_FAILED")
      }
    }
    commit_state(self.path, state, end)
  }
  self.state = state
  self.payload_end = end
  self.snapshot()
}

///|
pub fn DiskLog::append(self : DiskLog, entry : Bytes) -> UInt64 raise Error {
  let index = self.snapshot().size()
  ignore(self.append_batch([entry]))
  index
}

///|
pub fn DiskLog::prove_inclusion(
  self : DiskLog,
  index : UInt64,
  size : UInt64,
) -> @tree.InclusionProof raise Error {
  ignore(self.snapshot_at(size))
  @tree.inclusion_from_reader(index, size, (level, index) => {
    self.read_node(level, index)
  })
}

///|
pub fn DiskLog::prove_consistency(
  self : DiskLog,
  old : UInt64,
  size : UInt64,
) -> @tree.ConsistencyProof raise Error {
  ignore(self.snapshot_at(size))
  @tree.consistency_from_reader(old, size, (level, index) => {
    self.read_node(level, index)
  })
}

///|
pub fn DiskLog::prove_range(
  self : DiskLog,
  start : UInt64,
  end : UInt64,
  size : UInt64,
) -> @tree.RangeProof raise Error {
  ignore(self.snapshot_at(size))
  @tree.range_from_reader(start, end, size, (level, index) => {
    self.read_node(level, index)
  })
}

///|
/// Full audit reads all payloads, offsets and completed node hashes in bounded memory.
pub fn DiskLog::audit(self : DiskLog) -> @tree.Snapshot raise Error {
  self.ready()
  let mut expected_offset = 0UL
  let frontier : Array[@tree.Hash32] = []
  let mut ordinal = 0UL
  for index = 0UL; index < self.state.end(); index = index + 1UL {
    let metadata = read_at(self.files[2], index * 16UL, 16)
    if get_u64(metadata, 0) != expected_offset {
      raise StorageError("INDEX_SEQUENCE_MISMATCH")
    }
    let entry = self.read_entry(index)
    expected_offset = expected_offset + entry.length().to_uint64()
    let mut hash = @tree.hash_leaf(entry)
    if hash.bytes() != read_at(self.files[1], ordinal * 32UL, 32) {
      raise StorageError("NODE_MISMATCH")
    }
    ordinal = ordinal + 1UL
    let mut position = index
    while (position & 1UL) == 1UL {
      hash = @tree.hash_node(frontier.pop().unwrap(), hash)
      if hash.bytes() != read_at(self.files[1], ordinal * 32UL, 32) {
        raise StorageError("NODE_MISMATCH")
      }
      ordinal = ordinal + 1UL
      position = position >> 1
    }
    frontier.push(hash)
  }
  let snapshot = @tree.CompactRange::new(0UL, self.state.end(), frontier).snapshot()
  if expected_offset != self.payload_end || snapshot != self.state.snapshot() {
    raise StorageError("AUDIT_ROOT_MISMATCH")
  }
  snapshot
}
