///|
fn backup_path(tag : String) -> String raise Error {
  let parent = @env.get_env_var("MOONAPPEND_TEST_ROOT").unwrap_or("_build")
  if !@fs.path_exists(parent) {
    @fs.create_dir(parent)
  }
  parent + "/backup-" + tag + "-" + @env.now().to_string()
}

///|
test "audited backup preserves history and branches independently after restore" {
  let source = @disk.DiskLog::create(backup_path("source"))
  defer source.close()
  let old = source.append_batch([b"one", b"two", b""])
  let large = Bytes::from_array(Array::make(1048576, b'\xa5')[:])
  let head = source.append_batch([large, large, b"last"])
  let target = backup_path("副本")
  assert_eq(source.backup(target), head)
  let restored = @disk.DiskLog::open(target)
  defer restored.close()
  assert_eq(restored.audit(), head)
  assert_eq(restored.snapshot_at(3UL), old)
  assert_eq(restored.read_entry(2UL), b"")
  assert_eq(restored.read_entry(4UL), large)
  assert_eq(
    restored.prove_consistency(3UL, 6UL),
    source.prove_consistency(3UL, 6UL),
  )
  assert_eq(
    restored.prove_range(1UL, 3UL, 6UL),
    source.prove_range(1UL, 3UL, 6UL),
  )
  assert_eq(
    restored.prove_inclusion(3UL, 6UL),
    source.prove_inclusion(3UL, 6UL),
  )
  ignore(source.append(b"source-only"))
  assert_eq(restored.snapshot(), head)
  ignore(restored.append(b"restored-only"))
  assert_eq(source.read_entry(6UL), b"source-only")
  assert_eq(restored.read_entry(6UL), b"restored-only")
  assert_true(source.audit() != restored.audit())
  let refused = try {
    ignore(source.backup(target))
    false
  } catch {
    @disk.StorageError("BACKUP_DESTINATION_EXISTS") => true
    _ => false
  }
  assert_true(refused)
  assert_eq(restored.read_entry(6UL), b"restored-only")
}

///|
test "empty backup is writable and a closed source cannot create a destination" {
  let source = @disk.DiskLog::create(backup_path("empty"))
  let target = backup_path("empty-copy")
  assert_eq(source.backup(target).size(), 0UL)
  source.close()
  let restored = @disk.DiskLog::open(target)
  defer restored.close()
  assert_eq(restored.append(b"first"), 0UL)
  assert_eq(restored.audit().size(), 1UL)
  let refused_target = backup_path("closed")
  let refused = try {
    ignore(source.backup(refused_target))
    false
  } catch {
    @disk.StorageError("CLOSED") => true
    _ => false
  }
  assert_true(refused)
  assert_false(@disk.path_exists(refused_target))
}

///|
test "backup audits hidden historical corruption before creating a destination" {
  let path = backup_path("corrupt")
  let source = @disk.DiskLog::create(path)
  ignore(source.append_batch([b"a", b"b", b"c", b"d"]))
  source.close()
  let nodes = @fs.read_file_to_bytes(path + "/nodes").to_array()
  nodes[0] = nodes[0] ^ 1
  @fs.write_bytes_to_file(path + "/nodes", Bytes::from_array(nodes[:]))
  let reopened = @disk.DiskLog::open(path)
  defer reopened.close()
  let target = backup_path("rejected-corrupt-copy")
  let rejected = try {
    ignore(reopened.backup(target))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_false(@disk.path_exists(target))
}

///|
test "an incomplete destination without a committed checkpoint fails closed" {
  let target = backup_path("incomplete")
  @fs.create_dir(target)
  for name in ["nodes", "index", "payload"] {
    @fs.write_bytes_to_file(target + "/" + name, b"partial")
  }
  @fs.write_bytes_to_file(target + "/state.tmp", b"not committed")
  let rejected = try {
    let log = @disk.DiskLog::open(target)
    log.close()
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
