import gleam/time/timestamp

pub type Time =
  timestamp.Timestamp

pub fn now() {
  timestamp.system_time()
}
