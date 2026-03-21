import gleam/option.{None, Some}
import gleam/result
import gleam/string
import internal/log.{debug}
import internal/resp.{
  type RespType, RespArr, RespBulk, RespErr, RespNull, RespStr,
}
import internal/table

type Command {
  COMMAND
  GET
  PING
  SET
  UNKNOWN
}

pub fn handle(value: RespType, store: table.Table(String, String)) -> RespType {
  case value {
    RespArr(args) -> {
      let cmd = result.unwrap(get_command(args), UNKNOWN)
      case cmd {
        COMMAND -> RespArr([])
        PING -> RespStr("PONG")
        GET -> get(args, store)
        SET -> set(args, store)
        _ -> RespErr("ERR couldnt get command")
      }
    }
    _ -> RespErr("ERR must be an arr")
  }
}

fn use_args(
  args: List(RespType),
  store: table.Table(String, String),
  fun: fn(List(RespType), table.Table(String, String)) -> RespType,
) -> RespType {
  case args {
    [_cmd, ..args] -> {
      fun(args, store)
    }
    [] -> RespErr("ERR couldnt handle get")
  }
}

fn get(args: List(RespType), store: table.Table(String, String)) -> RespType {
  use_args(args, store, fn(args, store) {
    debug("get args: ~p", [args])
    case args {
      [RespBulk(key)] -> {
        let val = table.get(store, key)
        debug("got val: ~p", [val])
        case val {
          Some(val) -> RespStr(val)
          None -> RespNull
        }
      }
      _ -> RespErr("ERR invalid args")
    }
  })
}

fn set(args: List(RespType), store: table.Table(String, String)) -> RespType {
  use_args(args, store, fn(args, store) {
    debug("set args: ~p", [args])
    case args {
      [RespBulk(key), RespBulk(val)] -> {
        debug("got key:val: ~s: ~s", [key, val])
        table.set(store, key, val)
        RespStr("OK")
      }
      _ -> RespErr("ERR invalid args")
    }
  })
}

fn get_command(args: List(RespType)) -> Result(Command, String) {
  case args {
    [val, ..] -> {
      use cmd <- result.try(resp.unwrap_bulk(val))
      Ok(command_from_string(cmd))
    }
    _ -> Error("empty args")
  }
}

fn command_from_string(str: String) -> Command {
  case string.uppercase(str) {
    "COMMAND" -> COMMAND
    "GET" -> GET
    "PING" -> PING
    "SET" -> SET
    _ -> UNKNOWN
  }
}
