///|
extern "C" fn exit_process(code : Int) -> Unit = "ma_cli_exit"

///|
suberror CliError {
  CliError(String)
}

///|
fn read_text(path : String) -> String raise Error {
  @utf8.decode(@disk.read_file(path)[:], ignore_bom=false)
}

///|
fn snapshot(path : String) -> @tree.Snapshot raise Error {
  @wire.decode_snapshot(read_text(path))
}

///|
fn records(path : String) -> Array[Bytes] raise Error {
  @wire.decode_records(read_text(path))
}

///|
fn result(value : @tree.Verification) -> Unit {
  let output : Json = {
    "status": value.code(),
    "verified": value.is_verified(),
  }
  println(output.stringify())
  if !value.is_verified() {
    exit_process(1)
  }
}

///|
fn require_args(args : Array[String], count : Int) -> Unit raise CliError {
  if args.length() != count {
    raise CliError("ARGUMENT_COUNT: use --help")
  }
}

///|
fn run(args : Array[String]) -> Unit raise Error {
  if args.length() == 1 || args[1] == "--help" {
    println(
      "MoonAppend 0.2.0-alpha.1 native CLI; all indices are zero-based, ranges are [start,end)",
    )
    println(
      "init DIR | append DIR RECORDS.json | snapshot DIR SIZE | audit DIR",
    )
    println(
      "inclusion DIR INDEX SIZE | consistency DIR OLD_SIZE NEW_SIZE | range DIR START END SIZE",
    )
    println(
      "export DIR START END | verify-range TRUSTED.json START RECORDS.json PROOF.json",
    )
    println(
      "verify-inclusion TRUSTED.json INDEX RECORDS.json PROOF.json | verify-consistency OLD.json NEW.json PROOF.json",
    )
    println(
      "shard START RECORDS.json OUT.bin | merge LEFT.bin RIGHT.bin OUT.bin | resume STATE.bin RECORDS.json OUT.bin | root STATE.bin",
    )
    println(
      "generate DIR COUNT BATCH_SIZE (deterministic fixture; COUNT <= 1000000)",
    )
    println(
      "JSON to stdout; redirect to a new file using your shell. Binary outputs refuse existing paths.",
    )
    return
  }
  match args[1] {
    "init" => {
      require_args(args, 3)
      let log = @disk.DiskLog::create(args[2])
      defer log.close()
      println(@wire.encode_snapshot(log.snapshot()))
    }
    "append" => {
      require_args(args, 4)
      let entries = records(args[3])
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      println(@wire.encode_snapshot(log.append_batch(entries)))
    }
    "snapshot" => {
      require_args(args, 4)
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      println(@wire.encode_snapshot(log.snapshot_at(@wire.parse_size(args[3]))))
    }
    "audit" => {
      require_args(args, 3)
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      let head = log.audit()
      println(@wire.encode_snapshot(head))
    }
    "inclusion" => {
      require_args(args, 5)
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      println(
        @wire.encode_inclusion(
          log.prove_inclusion(
            @wire.parse_size(args[3]),
            @wire.parse_size(args[4]),
          ),
        ),
      )
    }
    "consistency" => {
      require_args(args, 5)
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      println(
        @wire.encode_consistency(
          log.prove_consistency(
            @wire.parse_size(args[3]),
            @wire.parse_size(args[4]),
          ),
        ),
      )
    }
    "range" => {
      require_args(args, 6)
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      println(
        @wire.encode_range(
          log.prove_range(
            @wire.parse_size(args[3]),
            @wire.parse_size(args[4]),
            @wire.parse_size(args[5]),
          ),
        ),
      )
    }
    "export" => {
      require_args(args, 5)
      let start = @wire.parse_size(args[3])
      let end = @wire.parse_size(args[4])
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      if end < start || end > log.snapshot().size() || end - start > 4096UL {
        raise CliError("EXPORT_RANGE_LIMIT")
      }
      let entries = []
      let mut total = 0
      for i = start; i < end; i = i + 1UL {
        let entry = log.read_entry(i)
        if entry.length() > 8372224 - total {
          raise CliError("EXPORT_BYTE_LIMIT")
        }
        total = total + entry.length()
        entries.push(entry)
      }
      let encoded = @wire.encode_records(entries)
      if @utf8.encode(encoded).length() > 16777216 {
        raise CliError("EXPORT_BYTE_LIMIT")
      }
      println(encoded)
    }
    "verify-range" => {
      require_args(args, 6)
      result(
        @tree.verify_range(
          snapshot(args[2]),
          @wire.parse_size(args[3]),
          records(args[4]),
          @wire.decode_range(read_text(args[5])),
        ),
      )
    }
    "verify-inclusion" => {
      require_args(args, 6)
      let entries = records(args[4])
      if entries.length() != 1 {
        raise CliError("EXPECTED_ONE_RECORD")
      }
      result(
        @tree.verify_inclusion(
          snapshot(args[2]),
          @wire.parse_size(args[3]),
          entries[0],
          @wire.decode_inclusion(read_text(args[5])),
        ),
      )
    }
    "verify-consistency" => {
      require_args(args, 5)
      result(
        @tree.verify_consistency(
          snapshot(args[2]),
          snapshot(args[3]),
          @wire.decode_consistency(read_text(args[4])),
        ),
      )
    }
    "shard" => {
      require_args(args, 5)
      let state = @tree.CompactRange::from_leaves(
        @wire.parse_size(args[2]),
        records(args[3]),
      )
      @disk.write_new_file(args[4], state.checkpoint())
      println("SHARD_WRITTEN")
    }
    "merge" => {
      require_args(args, 5)
      let left = @tree.CompactRange::restore(
        @disk.read_file(args[2], limit=4096),
      )
      let right = @tree.CompactRange::restore(
        @disk.read_file(args[3], limit=4096),
      )
      let merged = left.merge(right)
      @disk.write_new_file(args[4], merged.checkpoint())
      println("SHARDS_MERGED")
    }
    "resume" => {
      require_args(args, 5)
      let mut state = @tree.CompactRange::restore(
        @disk.read_file(args[2], limit=4096),
      )
      for entry in records(args[3]) {
        state = state.append(entry)
      }
      @disk.write_new_file(args[4], state.checkpoint())
      println("STATE_RESUMED")
    }
    "root" => {
      require_args(args, 3)
      println(
        @wire.encode_snapshot(
          @tree.CompactRange::restore(@disk.read_file(args[2], limit=4096)).snapshot(),
        ),
      )
    }
    "generate" => {
      require_args(args, 5)
      let count = @wire.parse_size(args[3])
      let batch = @wire.parse_size(args[4])
      if count > 1000000UL || batch == 0UL || batch > 4096UL {
        raise CliError("FIXTURE_LIMIT")
      }
      let log = @disk.DiskLog::create(args[2])
      defer log.close()
      let mut remaining = count
      while remaining != 0UL {
        let n = if remaining < batch { remaining } else { batch }
        ignore(log.append_batch(Array::make(n.to_int(), b"benchmark-record")))
        remaining = remaining - n
      }
      println(@wire.encode_snapshot(log.snapshot()))
    }
    _ => raise CliError("UNKNOWN_COMMAND: use --help")
  }
}

///|
fn main {
  run(@env.args()) catch {
    error => {
      eprintln(error)
      exit_process(2)
    }
  }
}
