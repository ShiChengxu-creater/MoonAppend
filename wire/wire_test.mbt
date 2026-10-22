///|
test "all wire objects round trip exact decimal sizes and bytes" {
  let records = [b"", b"\x00\xff", b"three"]
  assert_eq(@wire.decode_records(@wire.encode_records(records)), records)
  let log = @tree.MemoryLog::new()
  let head = log.append_batch(records)
  assert_eq(@wire.decode_snapshot(@wire.encode_snapshot(head)), head)
  let inclusion = log.prove_inclusion(1UL, 3UL)
  assert_eq(
    @wire.decode_inclusion(@wire.encode_inclusion(inclusion)),
    inclusion,
  )
  let consistency = log.prove_consistency(1UL, 3UL)
  assert_eq(
    @wire.decode_consistency(@wire.encode_consistency(consistency)),
    consistency,
  )
  let range = log.prove_range(1UL, 3UL, 3UL)
  assert_eq(@wire.decode_range(@wire.encode_range(range)), range)
  let big = @tree.Snapshot::new(9223372036854775807UL, @tree.hash_leaf(b"root"))
  assert_eq(@wire.decode_snapshot(@wire.encode_snapshot(big)), big)
}

///|
test "duplicate decoded keys extra fields numeric sizes and trailing input fail" {
  let root = @tree.empty_root().hex()
  let base = "{\"format\":\"moonappend/1\",\"kind\":\"snapshot\",\"size\":\"0\",\"root\":\"" +
    root +
    "\""
  for
    input in [
      base + ",\"size\":\"0\"}",
      base + ",\"si\\u007ae\":\"0\"}",
      base + ",\"extra\":\"x\"}",
      base + "} false",
      base + ",}",
      "{\"format\":\"moonappend/1\",\"kind\":\"snapshot\",\"size\":0,\"root\":\"" +
      root +
      "\"}",
    ] {
    let rejected = try {
      ignore(@wire.decode_snapshot(input))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  for
    value in [
      "", "01", "+1", "-1", "1.0", "9223372036854775808", "18446744073709551615",
    ] {
    let rejected = try {
      ignore(@wire.parse_size(value))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  for value in ["0", "gg", "FF"] {
    let rejected = try {
      ignore(@wire.hex_bytes(value))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "record decoding enforces the aggregate byte limit below the JSON input cap" {
  let mut block = "00"
  for _ in 0..<20 {
    block = block + block
  }
  // Seven 1 MiB records plus a final record reach exactly the shared raw limit.
  let tail = block[:2064384].to_owned()
  let prefix = "{\"format\":\"moonappend/1\",\"kind\":\"records\",\"entries\":["
  let fields = Array::make(7, "\"" + block + "\"").join(",")
  let accepted = prefix + fields + ",\"" + tail + "\"]}"
  let entries = @wire.decode_records(accepted)
  assert_eq(entries.length(), 8)
  assert_eq(entries[7].length(), 1032192)
  let too_large = prefix + fields + ",\"" + tail + "00\"]}"
  assert_true(too_large.length() < 16777216)
  let rejected = try {
    ignore(@wire.decode_records(too_large))
    false
  } catch {
    @wire.WireError("RECORD_BYTE_LIMIT") => true
    _ => false
  }
  assert_true(rejected)
}
