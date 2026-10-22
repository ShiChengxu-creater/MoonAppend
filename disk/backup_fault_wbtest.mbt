///|
test "backup failure leaves its source usable and never opens a partial copy" {
  let parent = @env.get_env_var("MOONAPPEND_TEST_ROOT").unwrap_or("_build")
  if !@fs.path_exists(parent) {
    @fs.create_dir(parent)
  }
  let base = parent + "/backup-fault-" + @env.now().to_string()
  let source = DiskLog::create(base)
  defer source.close()
  let head = source.append_batch([b"a", b"b", b"c", b"d", b"e"])
  for stage in 1..<=5 {
    let destination = base + "-" + stage.to_string()
    let failed = try {
      ignore(source.backup_to(destination, fault=stage))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    assert_eq(source.audit(), head)
    let incomplete = try {
      let copy = DiskLog::open(destination)
      defer copy.close()
      assert_eq(copy.audit(), head)
      false
    } catch {
      _ => true
    }
    assert_eq(incomplete, stage != 5)
  }
  assert_eq(source.append(b"still usable"), 5UL)
  assert_eq(source.audit().size(), 6UL)
}
