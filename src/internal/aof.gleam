import file_streams/file_open_mode
import file_streams/file_stream.{type FileStream}
import gleam/erlang/process
import gleam/otp/actor

pub opaque type AofState {
  AofState(self: process.Subject(Message), file: FileStream)
}

pub opaque type Message {
  Write(BitArray)
  Sync
  Shutdown
}

pub type AofStream =
  actor.Started(process.Subject(Message))

const sync_interval_ms = 1000

pub fn start(filename: String) {
  let assert Ok(aof) =
    actor.new_with_initialiser(100, fn(self) {
      let assert Ok(file) =
        file_stream.open(filename, [file_open_mode.Write, file_open_mode.Raw])
      Ok(actor.returning(actor.initialised(AofState(self:, file:)), self))
    })
    |> actor.on_message(handle_message)
    |> actor.start

  // kick off sync
  schedule_sync(aof.data)
  aof
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
    Sync -> {
      let assert Ok(_) = file_stream.sync(state.file)
      schedule_sync(state.self)
      actor.continue(state)
    }
    Shutdown -> {
      let assert Ok(_) = file_stream.sync(state.file)
      let assert Ok(_) = file_stream.close(state.file)
      actor.stop()
    }
  }
}

fn schedule_sync(aof: process.Subject(Message)) -> Nil {
  process.send_after(aof, sync_interval_ms, Sync)
  Nil
}
