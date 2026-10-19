///|
fn main {
  let log = @moonappend.MemoryLog::new()
  let rewritten = @moonappend.MemoryLog::new()
  let leaves = [
    b"release-1", b"release-2", b"release-3", b"release-4", b"release-5", b"release-6",
    b"release-7",
  ]
  for i in 0..<leaves.length() {
    ignore(try! log.append(leaves[i]))
    ignore(
      try! rewritten.append(
        if i == 1 {
          b"rewritten-release"
        } else {
          leaves[i]
        },
      ),
    )
  }
  let saved = try! log.snapshot_at(3UL)
  let grown = log.snapshot()
  let growth = try! log.prove_consistency(3UL, 7UL)
  let inclusion = try! log.prove_inclusion(1UL, 7UL)
  let forged_growth = try! rewritten.prove_consistency(3UL, 7UL)
  println(
    "growth 3 -> 7: " +
    @moonappend.verify_consistency(saved, grown, growth).code(),
  )
  println(
    "rewritten history: " +
    @moonappend.verify_consistency(saved, rewritten.snapshot(), forged_growth).code(),
  )
  println(
    "release-2 inclusion: " +
    @moonappend.verify_inclusion(grown, 1UL, leaves[1], inclusion).code(),
  )
  println(
    "changed leaf: " +
    @moonappend.verify_inclusion(grown, 1UL, b"changed", inclusion).code(),
  )
}
