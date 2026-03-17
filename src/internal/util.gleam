import gleam/string

pub fn ensure_ending(str: String) -> String {
  case string.ends_with(str, "\r\n") {
    True -> str
    False -> str <> "\r\n"
  }
}
