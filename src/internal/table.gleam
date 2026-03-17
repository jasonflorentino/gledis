import gleam/dynamic
import gleam/erlang/atom
import gleam/list
import gleam/option.{type Option, None, Some}

pub opaque type Table(k, v) {
  Table(name: atom.Atom)
}

/// Returns the number of keys that were removed
pub fn del(table: Table(k, v), keys: List(String)) -> Int {
  list.fold(keys, 0, fn(count, key) {
    case ets_member(name(table), key) {
      True -> {
        ets_del(name(table), key)
        count + 1
      }
      False -> count
    }
  })
}

pub fn set(table: Table(k, v), key: String, val: String) -> Nil {
  ets_insert(name(table), [#(key, val)])
}

pub fn get(table: Table(k, v), key: String) -> Option(String) {
  case ets_lookup(name(table), key) {
    [#(_kk, vv)] -> Some(vv)
    _ -> None
  }
}

pub fn name(table: Table(k, v)) -> atom.Atom {
  table.name
}

pub fn new(name: String) -> Table(k, v) {
  let name = atom.create(name)
  ets_table(
    name,
    ["set", "public", "named_table"]
      |> list.map(fn(a) { a |> atom.create |> atom.to_dynamic }),
  )
  let table = Table(name)
  table
}

@external(erlang, "ets", "delete")
fn ets_del(table: atom.Atom, key: k) -> Nil

@external(erlang, "ets", "insert")
fn ets_insert(table: atom.Atom, kv: List(#(k, v))) -> Nil

@external(erlang, "ets", "lookup")
fn ets_lookup(table: atom.Atom, key: k) -> List(#(k, v))

@external(erlang, "ets", "member")
fn ets_member(table: atom.Atom, key: k) -> Bool

@external(erlang, "ets", "new")
fn ets_table(name: atom.Atom, options: List(dynamic.Dynamic)) -> atom.Atom
