///|
/// Validate the entire batch before changing the log (allocation failures excluded).
pub fn MemoryLog::append_batch(
  self : MemoryLog,
  leaves : Array[Bytes],
) -> Snapshot raise AppendError {
  if leaves.length() > self.limits.leaves - self.count {
    raise LeafLimit
  }
  let mut total = self.total_bytes
  for leaf in leaves {
    if leaf.length() > self.limits.bytes - total {
      raise ByteLimit
    }
    total = total + leaf.length()
  }
  for leaf in leaves {
    ignore(self.append(leaf))
  }
  self.snapshot()
}
