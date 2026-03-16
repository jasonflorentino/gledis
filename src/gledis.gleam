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
      echo "msg"
      echo msg
      let assert Ok(#(value, _rest)) = parse(msg)
      echo "value"
      echo value

      let assert Ok(response) = handle(value)
      io.println("response: " <> response)
      let assert Ok(_) = glisten.send(conn, bytes_tree.from_string(response))
      echo "sent"

      glisten.continue(state)
    })
    |> glisten.start(port)

  printf("Listening on port: ~b\n", port)

  process.sleep_forever()
}

// *2 \r\n $5 \r\n hello \r\n $5 \r\n world
// let msg  = <<"*2\r\n$5\r\nhello\r\n$5\r\nworld">>

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
  // RespStr(data: String)
  // RespErr(data: String)
  // RespNum(data: Int)
  RespBulk(data: String)
  RespArr(data: List(Value))
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

// fn parse_string(data: BitArray) -> Result(#(Value, BitArray), String) {
//   echo data
//   Ok("Ok\r\n")
// }

// fn parse_error(data: BitArray) -> Result(String, String) {
//   echo data
//   Ok("Ok\r\n")
// }

// fn parse_integer(data: BitArray) -> Result(String, String) {
//   echo data
//   Ok("Ok\r\n")
// }

fn handle(_value: Value) -> Result(String, String) {
  Ok("+4\r\nPONG\r\n")
}
