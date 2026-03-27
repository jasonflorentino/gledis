import file_streams/file_open_mode
import file_streams/file_stream.{type FileStream}
import gleam/erlang/process
import gleam/otp/actor

pub opaque type AofState {
  AofState(file: FileStream)
}

pub opaque type Message {
  Write(BitArray)
  Flush
  Shutdown
}

pub type AofStream =
  actor.Started(process.Subject(Message))

pub fn start(filename: String) {
  actor.new_with_initialiser(100, fn(selector) {
    let assert Ok(file) =
      file_stream.open(filename, [file_open_mode.Write, file_open_mode.Raw])
    Ok(actor.returning(actor.initialised(AofState(file:)), selector))
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn write(aof: AofStream, msg: BitArray) {
  actor.send(aof.data, Write(msg))
}

fn handle_message(state: AofState, message: Message) {
  case message {
    Write(command) -> {
      let assert Ok(_) = file_stream.write_bytes(state.file, command)
      actor.continue(state)
    }
    Flush -> {
      let assert Ok(_) = file_stream.sync(state.file)
      actor.continue(state)
    }
    Shutdown -> {
      let assert Ok(_) = file_stream.sync(state.file)
      let assert Ok(_) = file_stream.close(state.file)
      actor.stop()
    }
  }
}
