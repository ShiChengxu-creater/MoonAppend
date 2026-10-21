///|
pub(all) suberror WireError {
  WireError(String)
} derive(Debug)

///|
pub extend WireError with @debug.Debug::{to_repr}

///|
priv struct Cursor {
  input : String
  mut pos : Int
}

///|
fn Cursor::ws(self : Cursor) -> Unit {
  while self.pos < self.input.length() &&
        [9, 10, 13, 32].contains(self.input[self.pos].to_int()) {
    self.pos = self.pos + 1
  }
}

///|
fn Cursor::take(self : Cursor, expected : Int) -> Unit raise WireError {
  self.ws()
  if self.pos >= self.input.length() ||
    self.input[self.pos].to_int() != expected {
    raise WireError("JSON_SYNTAX")
  }
  self.pos = self.pos + 1
}

///|
fn Cursor::peek(self : Cursor) -> Int {
  self.ws()
  if self.pos == self.input.length() {
    -1
  } else {
    self.input[self.pos].to_int()
  }
}

///|
fn Cursor::string(self : Cursor) -> String raise Error {
  self.ws()
  let start = self.pos
  self.take(34)
  let mut escaped = false
  while self.pos < self.input.length() {
    let code = self.input[self.pos].to_int()
    self.pos = self.pos + 1
    if escaped {
      escaped = false
    } else if code == 92 {
      escaped = true
    } else if code == 34 {
      let value = @json.parse(self.input[start:self.pos])
      match value {
        String(s) => return s
        _ => raise WireError("EXPECTED_STRING")
      }
    }
  }
  raise WireError("UNTERMINATED_STRING")
}

///|
/// Flat versioned schema: strings and arrays of strings only. Duplicate decoded
/// keys, unknown fields, trailing input and nested arbitrary JSON are rejected.
fn parse(
  input : String,
  kind : String,
  fields : Array[String],
) -> Map[String, Json] raise Error {
  if input.length() > 16777216 {
    raise WireError("JSON_INPUT_LIMIT")
  }
  let cursor = { input, pos: 0, }
  let output = Map([])
  cursor.take(123)
  if cursor.peek() != 125 {
    while true {
      let key = cursor.string()
      if output.contains(key) {
        raise WireError("DUPLICATE_FIELD")
      }
      if key != "format" && key != "kind" && !fields.contains(key) {
        raise WireError("UNKNOWN_FIELD")
      }
      cursor.take(58)
      let value = if cursor.peek() == 34 {
        Json::string(cursor.string())
      } else if cursor.peek() == 91 {
        cursor.take(91)
        let items : Array[Json] = []
        if cursor.peek() != 93 {
          while true {
            if items.length() >= 65536 {
              raise WireError("ARRAY_LIMIT")
            }
            items.push(Json::string(cursor.string()))
            if cursor.peek() != 44 {
              break
            }
            cursor.take(44)
          }
        }
        cursor.take(93)
        Json::array(items)
      } else {
        raise WireError("EXPECTED_STRING_OR_ARRAY")
      }
      output.set(key, value)
      if cursor.peek() != 44 {
        break
      }
      cursor.take(44)
    }
  }
  cursor.take(125)
  if cursor.peek() != -1 {
    raise WireError("TRAILING_INPUT")
  }
  if output.length() != fields.length() + 2 {
    raise WireError("MISSING_FIELD")
  }
  if text(output, "format") != "moonappend/1" || text(output, "kind") != kind {
    raise WireError("WRONG_FORMAT_OR_KIND")
  }
  output
}

///|
fn text(fields : Map[String, Json], key : String) -> String raise WireError {
  match fields.get(key) {
    Some(String(s)) => s
    _ => raise WireError("EXPECTED_STRING: \{key}")
  }
}

///|
pub fn parse_size(text : String) -> UInt64 raise WireError {
  if text.is_empty() || (text.length() > 1 && text[0] == 48) {
    raise WireError("INVALID_DECIMAL")
  }
  let mut value = 0UL
  for code in text {
    if code < '0' || code > '9' {
      raise WireError("INVALID_DECIMAL")
    }
    let digit = (code.to_int() - 48).to_uint64()
    if value > (@tree.MAX_TREE_SIZE - digit) / 10UL {
      raise WireError("DECIMAL_LIMIT")
    }
    value = value * 10UL + digit
  }
  value
}

///|
pub fn bytes_hex(value : Bytes) -> String {
  let digits = "0123456789abcdef"
  let output = StringBuilder()
  for b in value {
    output.write_char(digits[b.to_int() / 16].to_char().unwrap())
    output.write_char(digits[b.to_int() % 16].to_char().unwrap())
  }
  output.to_string()
}

///|
pub fn hex_bytes(value : String) -> Bytes raise WireError {
  if value.length() % 2 != 0 || value.length() > 2097152 {
    raise WireError("HEX_LENGTH")
  }
  let output = []
  for i in 0..<(value.length() / 2) {
    let mut byte = 0
    for j in 0..<2 {
      let c = value[i * 2 + j].to_int()
      let digit = if c >= 48 && c <= 57 {
        c - 48
      } else if c >= 97 && c <= 102 {
        c - 87
      } else {
        raise WireError("HEX_DIGIT")
      }
      byte = byte * 16 + digit
    }
    output.push(byte.to_byte())
  }
  Bytes::from_array(output[:])
}

///|
fn nodes(fields : Map[String, Json]) -> Array[@tree.Hash32] raise Error {
  match fields.get("nodes") {
    Some(Array(items)) => {
      if items.length() > 252 {
        raise WireError("PROOF_LIMIT")
      }
      let output = []
      for item in items {
        match item {
          String(s) => output.push(@tree.Hash32::from_hex(s))
          _ => raise WireError("EXPECTED_NODE")
        }
      }
      output
    }
    _ => raise WireError("EXPECTED_NODES")
  }
}

///|
fn encode(kind : String, fields : Map[String, Json]) -> String {
  fields.set("format", Json::string("moonappend/1"))
  fields.set("kind", Json::string(kind))
  Json::object(fields).stringify()
}

///|
fn encode_nodes(nodes : Array[@tree.Hash32]) -> Json {
  Json::array(nodes.map(n => Json::string(n.hex())))
}

///|
pub fn encode_snapshot(snapshot : @tree.Snapshot) -> String {
  encode("snapshot", {
    "size": Json::string(snapshot.size().to_string()),
    "root": Json::string(snapshot.root().hex()),
  })
}

///|
pub fn decode_snapshot(input : String) -> @tree.Snapshot raise Error {
  let fields = parse(input, "snapshot", ["size", "root"])
  @tree.Snapshot::new(
    parse_size(text(fields, "size")),
    @tree.Hash32::from_hex(text(fields, "root")),
  )
}

///|
pub fn encode_range(proof : @tree.RangeProof) -> String {
  encode("range", {
    "start": Json::string(proof.start().to_string()),
    "end": Json::string(proof.end().to_string()),
    "size": Json::string(proof.tree_size().to_string()),
    "nodes": encode_nodes(proof.nodes()),
  })
}

///|
pub fn decode_range(input : String) -> @tree.RangeProof raise Error {
  let fields = parse(input, "range", ["start", "end", "size", "nodes"])
  @tree.RangeProof::new(
    parse_size(text(fields, "start")),
    parse_size(text(fields, "end")),
    parse_size(text(fields, "size")),
    nodes(fields),
  )
}

///|
pub fn encode_inclusion(proof : @tree.InclusionProof) -> String {
  encode("inclusion", {
    "index": Json::string(proof.leaf_index().to_string()),
    "size": Json::string(proof.tree_size().to_string()),
    "nodes": encode_nodes(proof.nodes()),
  })
}

///|
pub fn decode_inclusion(input : String) -> @tree.InclusionProof raise Error {
  let fields = parse(input, "inclusion", ["index", "size", "nodes"])
  @tree.InclusionProof::new(
    parse_size(text(fields, "index")),
    parse_size(text(fields, "size")),
    nodes(fields),
  )
}

///|
pub fn encode_consistency(proof : @tree.ConsistencyProof) -> String {
  encode("consistency", {
    "old_size": Json::string(proof.old_size().to_string()),
    "new_size": Json::string(proof.new_size().to_string()),
    "nodes": encode_nodes(proof.nodes()),
  })
}

///|
pub fn decode_consistency(input : String) -> @tree.ConsistencyProof raise Error {
  let fields = parse(input, "consistency", ["old_size", "new_size", "nodes"])
  @tree.ConsistencyProof::new(
    parse_size(text(fields, "old_size")),
    parse_size(text(fields, "new_size")),
    nodes(fields),
  )
}

///|
pub fn encode_records(entries : Array[Bytes]) -> String {
  encode("records", {
    "entries": Json::array(entries.map(e => Json::string(bytes_hex(e)))),
  })
}

///|
pub fn decode_records(input : String) -> Array[Bytes] raise Error {
  let fields = parse(input, "records", ["entries"])
  match fields.get("entries") {
    Some(Array(items)) => {
      if items.length() > 4096 {
        raise WireError("BATCH_LIMIT")
      }
      let output = []
      for item in items {
        match item {
          String(s) => output.push(hex_bytes(s))
          _ => raise WireError("EXPECTED_ENTRY")
        }
      }
      output
    }
    _ => raise WireError("EXPECTED_ENTRIES")
  }
}
