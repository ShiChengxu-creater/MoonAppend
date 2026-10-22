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
fn emit(value : String, destination : String?) -> Unit raise Error {
  match destination {
    None => println(value)
    Some(path) => @disk.write_new_file(path, @utf8.encode(value + "\n"))
  }
}

///|
fn result(
  value : @tree.Verification,
  destination : String?,
) -> Unit raise Error {
  let output : Json = {
    "status": value.code(),
    "verified": value.is_verified(),
  }
  emit(output.stringify(), destination)
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
fn run(args : Array[String], destination : String?) -> Unit raise Error {
  let display : (String) -> Unit raise Error = text => emit(text, destination)
  if args.length() == 1 || args[1] == "--help" {
    if destination is Some(_) {
      raise CliError("HELP_HAS_NO_OUTPUT_FILE")
    }
    display(
      "MoonAppend 0.3.0 native CLI; all indices are zero-based, ranges are [start,end)",
    )
    display(
      "init DIR | append DIR RECORDS.json | snapshot DIR SIZE | audit DIR",
    )
    display(
      "backup DIR NEW_DIR (audited committed copy; reopen NEW_DIR to restore)",
    )
    display(
      "inclusion DIR INDEX SIZE | consistency DIR OLD_SIZE NEW_SIZE | range DIR START END SIZE",
    )
    display(
      "export DIR START END | verify-range TRUSTED.json START RECORDS.json PROOF.json",
    )
    display(
      "verify-inclusion TRUSTED.json INDEX RECORDS.json PROOF.json | verify-consistency OLD.json NEW.json PROOF.json",
    )
    display(
      "shard START RECORDS.json OUT.bin | merge LEFT.bin RIGHT.bin OUT.bin | resume STATE.bin RECORDS.json OUT.bin | root STATE.bin",
    )
    display(
      "generate DIR COUNT BATCH_SIZE (deterministic fixture; COUNT <= 1000000)",
    )
    display(
      "Use --out NEW_FILE for UTF-8 output; existing paths are refused. Checkpoint commands report status text.",
    )
    return
  }
  match args[1] {
    "init" => {
      require_args(args, 3)
      let log = @disk.DiskLog::create(args[2])
      defer log.close()
      display(@wire.encode_snapshot(log.snapshot()))
    }
    "append" => {
      require_args(args, 4)
      let entries = records(args[3])
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      display(@wire.encode_snapshot(log.append_batch(entries)))
    }
    "snapshot" => {
      require_args(args, 4)
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      display(@wire.encode_snapshot(log.snapshot_at(@wire.parse_size(args[3]))))
    }
    "backup" => {
      require_args(args, 4)
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      display(@wire.encode_snapshot(log.backup(args[3])))
    }
    "audit" => {
      require_args(args, 3)
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      let head = log.audit()
      display(@wire.encode_snapshot(head))
    }
    "inclusion" => {
      require_args(args, 5)
      let log = @disk.DiskLog::open(args[2])
      defer log.close()
      display(
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
      display(
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
      display(
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
      display(encoded)
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
        destination,
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
        destination,
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
        destination,
      )
    }
    "shard" => {
      require_args(args, 5)
      let state = @tree.CompactRange::from_leaves(
        @wire.parse_size(args[2]),
        records(args[3]),
      )
      @disk.write_new_file(args[4], state.checkpoint())
      display("SHARD_WRITTEN")
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
      display("SHARDS_MERGED")
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
      display("STATE_RESUMED")
    }
    "root" => {
      require_args(args, 3)
      display(
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
      display(@wire.encode_snapshot(log.snapshot()))
    }
    _ => raise CliError("UNKNOWN_COMMAND: use --help")
  }
}

///|
fn main {
  let args = @env.args()
  let destination = if args.length() >= 4 && args[args.length() - 2] == "--out" {
    let path = args.pop().unwrap()
    ignore(args.pop())
    Some(path)
  } else {
    None
  }
  try {
    if destination is Some(path) && @disk.path_exists(path) {
      raise CliError("OUTPUT_EXISTS")
    }
    run(args, destination)
  } catch {
    error => {
      eprintln(error)
      exit_process(2)
    }
  }
}
