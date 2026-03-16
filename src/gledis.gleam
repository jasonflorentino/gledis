import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/format.{printf}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import glisten.{Packet}

const port = 6379

pub fn main() -> Nil {
  io.println("Starting server...")

  let assert Ok(_) =
    glisten.new(fn(_conn) { #(Nil, None) }, fn(state, msg, conn) {
      let assert Packet(msg) = msg
      debug("msg: ~p", [msg])

      let assert Ok(#(command, _rest)) = parse(msg)
      debug("command: ~p", [command])

      let response_str = handle(command) |> value_to_string |> ensure_ending
      debug("response: ~s", response_str)

      let response_bytes = bytes_tree.from_string(response_str)
      debug("response_bytes: ~p", [response_bytes])

      let assert Ok(_) = glisten.send(conn, response_bytes)

      glisten.continue(state)
    })
    |> glisten.start(port)

  info("Listening on port: ~b", port)

  process.sleep_forever()
}

fn info(format: String, args: a) {
  printf(format <> "\n", args)
}

fn debug(format: String, args: a) {
  printf(format <> "\n", args)
}

fn ensure_ending(str: String) -> String {
  case string.ends_with(str, "\r\n") {
    True -> str
    False -> str <> "\r\n"
  }
}

fn read_line(
  from: BitArray,
  to: BitArray,
) -> Result(#(BitArray, BitArray), String) {
  case from {
    <<"\r\n", rest:bytes>> -> Ok(#(to, rest))
    <<first:size(8), rest:bytes>> ->
      read_line(rest, bit_array.append(to, <<first>>))
    _ -> Error("couldnt read line")
  }
}

fn read_integer(data: BitArray) -> Result(#(Int, BitArray), String) {
  use #(num_bin, rest) <- result.try(read_line(data, <<>>))
  use num_str <- result.try(
    result.map_error(bit_array.to_string(num_bin), fn(_) {
      "couldnt convert to string"
    }),
  )
  use num_int <- result.try(
    result.map_error(int.parse(num_str), fn(_) { "couldnt parse int" }),
  )
  Ok(#(num_int, rest))
}

type Value {
  RespStr(data: String)
  RespErr(data: String)
  // RespNum(data: Int)
  RespBulk(data: String)
  RespArr(data: List(Value))
}

fn lines_to_string(lines: List(String)) -> String {
  string.join(lines, "\r\n")
}

fn value_to_string(val: Value) -> String {
  case val {
    RespStr(data) ->
      lines_to_string([
        datatype_to_string(val) <> data,
      ])
    RespErr(data) ->
      lines_to_string([
        datatype_to_string(val) <> data,
      ])
    RespBulk(data) ->
      lines_to_string([
        datatype_to_string(val) <> int.to_string(value_size(val)),
        data,
      ])
    RespArr(data) ->
      lines_to_string([
        datatype_to_string(val) <> int.to_string(value_size(val)),
        lines_to_string(list.map(data, value_to_string)),
      ])
  }
}

fn datatype_to_string(val: Value) -> String {
  case val {
    RespStr(_) -> "+"
    RespErr(_) -> "-"
    RespBulk(_) -> "$"
    RespArr(_) -> "*"
  }
}

fn value_size(val: Value) -> Int {
  case val {
    RespStr(val) -> string.byte_size(val)
    RespErr(val) -> string.byte_size(val)
    RespBulk(val) -> string.byte_size(val)
    RespArr(items) -> list.length(items)
  }
}

fn parse(data: BitArray) -> Result(#(Value, BitArray), String) {
  case data {
    // <<"+", rest:bytes>> -> parse_string(rest)
    // <<"-", rest:bytes>> -> parse_error(rest)
    // <<":", rest:bytes>> -> parse_integer(rest)
    <<"$", rest:bytes>> -> parse_bulk(rest)
    <<"*", rest:bytes>> -> parse_array(rest)
    _ -> Error("Unknown datatype byte")
  }
}

fn parse_times(
  from: BitArray,
  into: List(Value),
  times: Int,
) -> Result(#(List(Value), BitArray), String) {
  case times {
    // reverse once we're done since we've been prepending
    0 -> Ok(#(list.reverse(into), from))
    _ -> {
      use #(val, rest) <- result.try(parse(from))
      // prepend into list to accumulate since this is more performant
      parse_times(rest, [val, ..into], times - 1)
    }
  }
}

fn parse_array(data: BitArray) -> Result(#(Value, BitArray), String) {
  use #(size, rest) <- result.try(read_integer(data))
  use #(vals, rest) <- result.try(parse_times(rest, [], size))
  Ok(#(RespArr(vals), rest))
}

fn parse_bulk(data: BitArray) -> Result(#(Value, BitArray), String) {
  use #(size, rest) <- result.try(read_integer(data))
  use #(line_bin, rest) <- result.try(read_line(rest, <<>>))
  assert bit_array.byte_size(line_bin) == size
  use line_str <- result.try(
    result.map_error(bit_array.to_string(line_bin), fn(_) {
      "couldnt parse to string"
    }),
  )
  Ok(#(RespBulk(line_str), rest))
}

fn handle(value: Value) -> Value {
  case value {
    RespArr(args) -> {
      let cmd = result.unwrap(get_command(args), UNKNOWN)
      case cmd {
        COMMAND -> RespArr([])
        PING -> RespStr("PONG")
        _ -> RespErr("ERR couldnt get command")
      }
    }
    _ -> RespErr("ERR must be an arr")
  }
}

type Command {
  COMMAND
  PING
  UNKNOWN
}

fn get_command(args: List(Value)) -> Result(Command, String) {
  case args {
    [val, ..] -> {
      use cmd <- result.try(unwrap_bulk(val))
      case string.uppercase(cmd) {
        "PING" -> Ok(PING)
        "COMMAND" -> Ok(COMMAND)
        _ -> Error("unknown cmd")
      }
    }
    _ -> Error("empty args")
  }
}

fn unwrap_bulk(bulk: Value) -> Result(String, String) {
  case bulk {
    RespBulk(val) -> Ok(val)
    _ -> Error("not a bulk")
  }
}
