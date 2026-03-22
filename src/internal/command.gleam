import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import internal/log.{debug}
import internal/resp.{
  type RespType, RespArr, RespBulk, RespErr, RespNull, RespStr,
}
import internal/table
import internal/time.{type Time}

type Command {
  COMMAND
  GET
  PING
  SET
  UNKNOWN
}

pub opaque type Value {
  Value(val: String, expires_at: Option(Time))
}

pub fn handle(value: RespType, store: table.Table(String, Value)) -> RespType {
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
  store: table.Table(String, Value),
  fun: fn(List(RespType), table.Table(String, Value)) -> RespType,
) -> RespType {
  case args {
    [_cmd, ..args] -> {
      fun(args, store)
    }
    [] -> RespErr("ERR couldnt handle get")
  }
}

fn get(args: List(RespType), store: table.Table(String, Value)) -> RespType {
  use_args(args, store, fn(args, store) {
    debug("get args: ~p", [args])
    case args {
      [RespBulk(key)] -> {
        case table.get(store, key) {
          None -> RespNull
          Some(Value(val, None)) -> RespStr(val)
          Some(Value(val, Some(expires_at))) -> {
            case time.is_before(expires_at, time.now()) {
              True -> {
                // TODO: background expiry process
                table.del(store, [key])
                RespNull
              }
              False -> RespStr(val)
            }
          }
        }
      }
      _ -> RespErr("ERR invalid args")
    }
  })
}

type SetOpts {
  SetOpts(nx: Bool, ex: Option(Int))
}

fn parse_set_opts(rest: List(RespType)) -> Result(SetOpts, String) {
  case rest {
    [] -> Ok(SetOpts(nx: False, ex: None))
    [RespBulk("NX")] -> Ok(SetOpts(nx: True, ex: None))
    [RespBulk("EX")] -> Error("ERR EX requires a number")
    [RespBulk("NX"), RespBulk("EX")] -> Error("ERR EX requires a number")
    [RespBulk("EX"), RespBulk(n)] -> {
      case int.base_parse(n, 10) {
        Ok(seconds) -> Ok(SetOpts(nx: False, ex: Some(seconds)))
        Error(_) -> Error("ERR failed to parse EX number")
      }
    }
    [RespBulk("NX"), RespBulk("EX"), RespBulk(n)] -> {
      case int.base_parse(n, 10) {
        Ok(seconds) -> Ok(SetOpts(nx: True, ex: Some(seconds)))
        Error(_) -> Error("ERR failed to parse EX number")
      }
    }
    _ -> Error("ERR invalid args")
  }
}

fn set(args: List(RespType), store: table.Table(String, Value)) -> RespType {
  use_args(args, store, fn(args, store) {
    debug("set args: ~p", [args])
    case args {
      [RespBulk(key), RespBulk(val), ..rest] -> {
        debug("got key:val: ~s:~s rest_len(~s)", [
          key,
          val,
          int.to_string(list.length(rest)),
        ])
        case parse_set_opts(rest) {
          Error(msg) -> RespErr(msg)
          Ok(SetOpts(nx, ex)) -> {
            let already_exists: Bool = case table.get(store, key) {
              None -> False
              Some(Value(_, Some(expires_at))) ->
                time.is_after(expires_at, time.now())
              _ -> True
            }
            let should_skip = nx == True && already_exists == True
            case should_skip {
              True -> RespNull
              False -> {
                table.set(store, key, Value(val:, expires_at: get_expiry(ex)))
                RespStr("OK")
              }
            }
          }
        }
      }
      _ -> RespErr("ERR invalid args")
    }
  })
}

fn get_expiry(ttl_seconds: Option(Int)) -> Option(Time) {
  case ttl_seconds {
    Some(ttl) -> Some(time.add_seconds(time.now(), ttl))
    None -> None
  }
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
