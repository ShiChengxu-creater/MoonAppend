///|
/// Deterministic TSV fixture producer; not the final interchange CLI.
fn main {
  let log = @moonappend.MemoryLog::new()
  for i in 0..<129 {
    let leaf = Bytes::from_array([i.to_byte(), 0x00, 0xff][:])
    ignore(try! log.append(leaf))
  }
  let sizes = Array::makei(65, i => i)
  for size in [65, 127, 128, 129] {
    sizes.push(size)
  }
  for size in sizes {
    let snapshot = try! log.snapshot_at(size.to_uint64())
    println("R\t" + size.to_string() + "\t" + snapshot.root().hex())
    if size > 0 {
      for index in 0..<size {
        let proof = try! log.prove_inclusion(
          index.to_uint64(),
          size.to_uint64(),
        )
        println(
          "I\t" +
          size.to_string() +
          "\t" +
          index.to_string() +
          "\t" +
          proof.nodes().map(n => n.hex()).join(","),
        )
      }
      for old in 1..<=size {
        let proof = try! log.prove_consistency(
          old.to_uint64(),
          size.to_uint64(),
        )
        println(
          "C\t" +
          old.to_string() +
          "\t" +
          size.to_string() +
          "\t" +
          proof.nodes().map(n => n.hex()).join(","),
        )
      }
    }
  }
}
