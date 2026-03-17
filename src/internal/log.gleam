import gleam/format.{printf}

pub fn info(format: String, args: a) {
  printf(format <> "\n", args)
}

pub fn debug(format: String, args: a) {
  printf(format <> "\n", args)
}
