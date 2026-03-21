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

fn set(args: List(RespType), store: table.Table(String, Value)) -> RespType {
  use_args(args, store, fn(args, store) {
    debug("set args: ~p", [args])
    case args {
      [RespBulk(key), RespBulk(val), ..rest] -> {
        debug("got key:val: ~s:~s [~s]", [
          key,
          val,
          int.to_string(list.length(rest)),
        ])
        case rest {
          // Set with no expiry if no extra args
          [] -> {
            table.set(store, key, Value(val:, expires_at: get_expiry(None)))
            RespStr("OK")
          }
          [RespBulk(nx_or_ex)] -> {
            case nx_or_ex {
              "EX" -> RespErr("ERR EX requires a number")
              // Check existence before setting if one arg is NX
              "NX" -> {
                case table.get(store, key) {
                  None -> {
                    table.set(
                      store,
                      key,
                      Value(val:, expires_at: get_expiry(None)),
                    )
                    RespStr("OK")
                  }
                  Some(Value(_, Some(expires_at))) -> {
                    case time.is_before(expires_at, time.now()) {
                      True -> {
                        table.set(
                          store,
                          key,
                          Value(val:, expires_at: get_expiry(None)),
                        )
                        RespStr("OK")
                      }
                      False -> RespNull
                    }
                  }
                  _ -> RespNull
                }
              }
              _ -> RespErr("ERR invalid arg")
            }
          }
          [RespBulk(nx_or_ex), RespBulk(seconds_or_err)] -> {
            case nx_or_ex, seconds_or_err {
              // if first arg is EX ensure second is a number and set with expiry
              "EX", _ -> {
                case int.base_parse(seconds_or_err, 10) {
                  Ok(seconds) -> {
                    table.set(
                      store,
                      key,
                      Value(val:, expires_at: get_expiry(Some(seconds))),
                    )
                    RespStr("OK")
                  }
                  _ -> RespErr("ERR failed to parse EX number")
                }
              }
              "NX", "EX" -> RespErr("ERR EX requires a number")
              "NX", _ -> RespErr("ERR extra arg")
              _, _ -> RespErr("ERR invalid args3")
            }
          }
          _ -> RespErr("ERR invalid args2")
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
