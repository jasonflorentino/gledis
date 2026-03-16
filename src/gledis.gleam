import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/format.{printf}
import gleam/io
import gleam/option.{None}
import glisten.{Packet}

const port = 6379

pub fn main() -> Nil {
  io.println("Starting server...")

  let assert Ok(_) =
    glisten.new(fn(_conn) { #(Nil, None) }, fn(state, msg, conn) {
      let assert Packet(msg) = msg
      let assert Ok(msg_str) = bit_array.to_string(msg)
      io.println("received: " <> msg_str)

      let response = "+OK\r\n"
      io.println("response: " <> response)
      let assert Ok(_) = glisten.send(conn, bytes_tree.from_string(response))

      glisten.continue(state)
    })
    |> glisten.start(port)

  printf("Listening on port: ~b\n", port)

  process.sleep_forever()
}
