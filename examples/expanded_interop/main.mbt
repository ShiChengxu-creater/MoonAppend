///|
fn main {
  let leaves = Array::makei(33, i => {
    Bytes::from_array([i.to_byte(), 0x00, 0xff][:])
  })
  let log = @tree.MemoryLog::new()
  ignore(try! log.append_batch(leaves))
  for end in 0..<=33 {
    for start in 0..<=end {
      let range = try! @tree.CompactRange::from_leaves(
        start.to_uint64(),
        leaves[start:end].to_owned(),
      )
      println(
        "K\t\{start}\t\{end}\t" + range.nodes().map(n => n.hex()).join(","),
      )
    }
  }
  for size in 1..<=33 {
    for start in 0..<size {
      for end in (start + 1)..<=size {
        let proof = try! log.prove_range(
          start.to_uint64(),
          end.to_uint64(),
          size.to_uint64(),
        )
        println(
          "Q\t\{start}\t\{end}\t\{size}\t" +
          proof.nodes().map(n => n.hex()).join(","),
        )
      }
    }
  }
}
