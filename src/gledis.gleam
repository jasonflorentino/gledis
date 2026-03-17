import gleam/bytes_tree
import gleam/erlang/process
import gleam/io
import gleam/option.{None}
import gleam/string
import glisten.{Packet}
import internal/command
import internal/log.{debug, info}
import internal/resp
import internal/table

const port = 6379

pub fn main() -> Nil {
  io.println("Starting server...")

  let store = table.new("db1")

  let assert Ok(_) =
    glisten.new(fn(_conn) { #(Nil, None) }, fn(state, msg, conn) {
      let assert Packet(msg) = msg
      debug("msg: ~p", [msg])

      let assert Ok(#(command, _rest)) = resp.parse(msg)
      debug("command: ~p", [command])

      let response_str =
        command.handle(command, store) |> resp.to_string |> ensure_ending
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

fn ensure_ending(str: String) -> String {
  case string.ends_with(str, "\r\n") {
    True -> str
    False -> str <> "\r\n"
  }
}
