///|
fn fresh_path(tag : String) -> String raise Error {
  let parent = @env.get_env_var("MOONAPPEND_TEST_ROOT").unwrap_or("_build")
  if !@fs.path_exists(parent) {
    @fs.create_dir(parent)
  }
  parent + "/disk-" + tag + "-" + @env.now().to_string()
}

///|
test "disk batches survive reopen and generate all three proof types" {
  let path = fresh_path("restart")
  let log = @disk.DiskLog::create(path)
  let empty = log.snapshot()
  assert_eq(empty.size(), 0UL)
  let locked = try {
    let other = @disk.DiskLog::open(path)
    other.close()
    false
  } catch {
    _ => true
  }
  assert_true(locked)
  let saved = log.append_batch([b"one", b"two", b"three"])
  log.close()
  log.close()
  let closed = try {
    ignore(log.snapshot())
    false
  } catch {
    _ => true
  }
  assert_true(closed)
  let reopened = @disk.DiskLog::open(path)
  defer reopened.close()
  assert_eq(reopened.snapshot(), saved)
  let head = reopened.append_batch([b"four", b"five"])
  assert_eq(reopened.audit(), head)
  assert_eq(reopened.read_entry(2UL), b"three")
  assert_true(
    @tree.verify_consistency(saved, head, reopened.prove_consistency(3UL, 5UL)).is_verified(),
  )
  assert_true(
    @tree.verify_inclusion(
      saved,
      1UL,
      b"two",
      reopened.prove_inclusion(1UL, 3UL),
    ).is_verified(),
  )
  assert_true(
    @tree.verify_range(
      head,
      1UL,
      [b"two", b"three", b"four"],
      reopened.prove_range(1UL, 4UL, 5UL),
    ).is_verified(),
  )
  let memory = @tree.MemoryLog::new()
  assert_eq(
    memory.append_batch([b"one", b"two", b"three", b"four", b"five"]),
    head,
  )
  for size in 1..<=5 {
    let n = size.to_uint64()
    assert_eq(reopened.snapshot_at(n), memory.snapshot_at(n))
    for i in 0..<size {
      assert_eq(
        reopened.prove_inclusion(i.to_uint64(), n),
        memory.prove_inclusion(i.to_uint64(), n),
      )
    }
    for old in 0..<=size {
      assert_eq(
        reopened.prove_consistency(old.to_uint64(), n),
        memory.prove_consistency(old.to_uint64(), n),
      )
    }
  }
}

///|
test "invalid disk batch leaves committed state usable and unchanged" {
  let log = @disk.DiskLog::create(fresh_path("limits"))
  defer log.close()
  let saved = log.append_batch([b"a", b"b"])
  let count_rejected = try {
    ignore(log.append_batch(Array::make(4097, b"")))
    false
  } catch {
    _ => true
  }
  assert_true(count_rejected)
  let big = Bytes::from_array(Array::make(1048577, b'\x01')[:])
  let bytes_rejected = try {
    ignore(log.append_batch([b"okay", big]))
    false
  } catch {
    _ => true
  }
  assert_true(bytes_rejected)
  assert_eq(log.snapshot(), saved)
  assert_eq(log.append_batch([]), saved)
  assert_eq(log.append(b"c"), 2UL)
  assert_eq(log.audit().size(), 3UL)
}

///|
test "recovery trims only uncommitted tails and ignores stale temp checkpoint" {
  let path = fresh_path("tail")
  let log = @disk.DiskLog::create(path)
  let saved = log.append_batch([b"a", b"b", b"c"])
  log.close()
  let lengths = []
  for name in ["nodes", "index", "payload"] {
    let filename = path + "/" + name
    let original = @fs.read_file_to_bytes(filename)
    lengths.push(original.length())
    @fs.write_bytes_to_file(filename, original + b"partial")
  }
  @fs.write_bytes_to_file(path + "/state.tmp", b"interrupted checkpoint write")
  let restored = @disk.DiskLog::open(path)
  defer restored.close()
  assert_eq(restored.snapshot(), saved)
  assert_eq(restored.recovered_bytes(), 21UL)
  assert_eq(restored.audit(), saved)
  for i, name in ["nodes", "index", "payload"] {
    assert_eq(@fs.read_file_to_bytes(path + "/" + name).length(), lengths[i])
  }
  ignore(restored.append(b"d"))
  assert_eq(restored.audit().size(), 4UL)
}

///|
test "damaged checkpoint and truncated committed nodes fail closed" {
  let checkpoint_path = fresh_path("checksum")
  let log = @disk.DiskLog::create(checkpoint_path)
  ignore(log.append(b"a"))
  log.close()
  let state = @fs.read_file_to_bytes(checkpoint_path + "/state").to_array()
  state[20] = state[20] ^ 1
  @fs.write_bytes_to_file(
    checkpoint_path + "/state",
    Bytes::from_array(state[:]),
  )
  let bad_state = try {
    let other = @disk.DiskLog::open(checkpoint_path)
    other.close()
    false
  } catch {
    _ => true
  }
  assert_true(bad_state)
  let short_path = fresh_path("short")
  let log2 = @disk.DiskLog::create(short_path)
  ignore(log2.append(b"a"))
  log2.close()
  @fs.write_bytes_to_file(short_path + "/nodes", b"")
  let short = try {
    let other = @disk.DiskLog::open(short_path)
    other.close()
    false
  } catch {
    _ => true
  }
  assert_true(short)
}

///|
test "full audit detects historical corruption outside the checkpoint frontier" {
  let path = fresh_path("audit")
  let log = @disk.DiskLog::create(path)
  ignore(log.append_batch([b"a", b"b", b"c", b"d"]))
  log.close()
  let nodes = @fs.read_file_to_bytes(path + "/nodes").to_array()
  nodes[0] = nodes[0] ^ 1
  @fs.write_bytes_to_file(path + "/nodes", Bytes::from_array(nodes[:]))
  let restored = @disk.DiskLog::open(path)
  defer restored.close()
  let bad = try {
    ignore(restored.audit())
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}
