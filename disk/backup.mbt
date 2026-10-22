///|
/// Audit and copy the committed log to a new directory. The copy is independent
/// and can be opened and appended to. No lock or uncommitted tail is copied.
/// Failure can leave an incomplete destination; existing paths are never reused.
pub fn DiskLog::backup(
  self : DiskLog,
  destination : String,
) -> @tree.Snapshot raise Error {
  self.backup_to(destination)
}

///|
fn DiskLog::backup_to(
  self : DiskLog,
  destination : String,
  fault? : Int = 0,
) -> @tree.Snapshot raise Error {
  self.ready()
  if path_exists(destination) {
    raise StorageError("BACKUP_DESTINATION_EXISTS")
  }
  let head = self.audit()
  if io_mkdir(path_bytes(destination)) != 0 {
    raise StorageError("BACKUP_DIRECTORY_CREATE_FAILED")
  }
  let files = open_files(destination, true)
  defer {
    for i in 1..<files.length() {
      ignore(io_close(files[i]))
    }
    ignore(io_close(files[0]))
  }
  let lengths = [
    node_count(head.size()) * 32UL,
    head.size() * 16UL,
    self.payload_end,
  ]
  for i in 0..<3 {
    let mut offset = 0UL
    while offset < lengths[i] {
      let remaining = lengths[i] - offset
      let count = if remaining > 1048576UL {
        1048576
      } else {
        remaining.to_int()
      }
      write_at(files[i + 1], offset, read_at(self.files[i + 1], offset, count))
      offset = offset + count.to_uint64()
    }
    if io_sync(files[i + 1]) != 0 {
      raise StorageError("BACKUP_SYNC_FAILED")
    }
    if fault == i + 1 {
      raise StorageError("INJECTED_BACKUP_AFTER_FILE")
    }
  }
  // Publish the checkpoint only after all committed data has been copied/synced.
  if fault == 4 {
    raise StorageError("INJECTED_BACKUP_BEFORE_COMMIT")
  }
  commit_state(destination, self.state, self.payload_end)
  if fault == 5 {
    raise StorageError("INJECTED_BACKUP_AFTER_COMMIT")
  }
  head
}
