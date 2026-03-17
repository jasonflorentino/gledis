//// RESP 2

import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type RespType {
  RespStr(data: String)
  RespErr(data: String)
  // RespNum(data: Int)
  RespBulk(data: String)
  RespArr(data: List(RespType))
  RespNull
}

/// Clients only send arrays of bulk strings
pub fn parse(data: BitArray) -> Result(#(RespType, BitArray), String) {
  case data {
    // <<"+", rest:bytes>> -> parse_string(rest)
    // <<"-", rest:bytes>> -> parse_error(rest)
    // <<":", rest:bytes>> -> parse_integer(rest)
    <<"$", rest:bytes>> -> parse_bulk(rest)
    <<"*", rest:bytes>> -> parse_array(rest)
    _ -> Error("Unknown datatype byte")
  }
}

/// do parse x times
pub fn parse_times(
  from: BitArray,
  into: List(RespType),
  times: Int,
) -> Result(#(List(RespType), BitArray), String) {
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

fn parse_array(data: BitArray) -> Result(#(RespType, BitArray), String) {
  use #(size, rest) <- result.try(read_int(data))
  use #(vals, rest) <- result.try(parse_times(rest, [], size))
  Ok(#(RespArr(vals), rest))
}

fn parse_bulk(data: BitArray) -> Result(#(RespType, BitArray), String) {
  use #(size, rest) <- result.try(read_int(data))
  // TODO: handle parsing Bulk Null?
  use #(line_bin, rest) <- result.try(read_line(rest, <<>>))
  assert bit_array.byte_size(line_bin) == size
  use line_str <- result.try(
    result.map_error(bit_array.to_string(line_bin), fn(_) {
      "couldnt parse to string"
    }),
  )
  Ok(#(RespBulk(line_str), rest))
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

fn read_int(data: BitArray) -> Result(#(Int, BitArray), String) {
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

pub fn to_string(val: RespType) -> String {
  case val {
    RespStr(data) ->
      join_lines([
        first_byte(val) <> data,
      ])
    RespErr(data) ->
      join_lines([
        first_byte(val) <> data,
      ])
    RespBulk(data) ->
      join_lines([
        first_byte(val) <> int.to_string(size(val)),
        data,
      ])
    RespNull ->
      join_lines([
        first_byte(val) <> int.to_string(size(val)),
      ])
    RespArr(data) ->
      join_lines([
        first_byte(val) <> int.to_string(size(val)),
        join_lines(list.map(data, to_string)),
      ])
  }
}

fn join_lines(lines: List(String)) -> String {
  string.join(lines, "\r\n")
}

fn first_byte(val: RespType) -> String {
  case val {
    RespStr(_) -> "+"
    RespErr(_) -> "-"
    RespBulk(_) -> "$"
    RespArr(_) -> "*"
    RespNull -> "$"
  }
}

fn size(val: RespType) -> Int {
  case val {
    RespStr(val) -> string.byte_size(val)
    RespErr(val) -> string.byte_size(val)
    RespBulk(val) -> string.byte_size(val)
    RespArr(items) -> list.length(items)
    RespNull -> -1
  }
}

pub fn unwrap_bulk(bulk: RespType) -> Result(String, String) {
  case bulk {
    RespBulk(val) -> Ok(val)
    _ -> Error("not a bulk")
  }
}
