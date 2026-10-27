///|
test "directory resolution accepts Unicode directories and rejects invalid paths" {
  let parent = @env.get_env_var("MOONAPPEND_TEST_ROOT").unwrap_or("_build")
  if !@fs.path_exists(parent) {
    @fs.create_dir(parent)
  }
  let path = parent + "/路径-" + @env.now().to_string()
  assert_eq(io_mkdir(path_bytes(path)), 0)
  let resolved = absolute_directory(path)
  assert_true(resolved.length() >= path.length())
  assert_eq(absolute_directory(resolved), resolved)
  write_new_file(path + "/file", b"not a directory")
  for candidate in ["", "\u0000", path + "/missing", path + "/file"] {
    let rejected = try {
      ignore(absolute_directory(candidate))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
