///|
test "failure at each commit boundary requires reopen and recovers an entire batch" {
  let parent = @env.get_env_var("MOONAPPEND_TEST_ROOT").unwrap_or("_build")
  if !@fs.path_exists(parent) {
    @fs.create_dir(parent)
  }
  for stage in 1..<=6 {
    let path = parent +
      "/disk-fault-" +
      stage.to_string() +
      "-" +
      @env.now().to_string()
    let log = DiskLog::create(path)
    let old = log.append_batch([b"old"])
    log.fault_stage.val = stage
    let failed = try {
      ignore(log.append_batch([b"new-1", b"new-2"]))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    let poisoned = try {
      ignore(log.append(b"cannot continue"))
      false
    } catch {
      _ => true
    }
    assert_true(poisoned)
    log.close()
    let restored = DiskLog::open(path)
    assert_eq(
      restored.audit().size(),
      if stage == 6 {
        3UL
      } else {
        old.size()
      },
    )
    ignore(restored.append(b"after recovery"))
    assert_eq(restored.audit().size(), if stage == 6 { 4UL } else { 2UL })
    restored.close()
  }
}
