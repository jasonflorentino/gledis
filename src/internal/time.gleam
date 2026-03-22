import gleam/order
import gleam/time/duration
import gleam/time/timestamp

pub type Time =
  timestamp.Timestamp

pub fn now() -> Time {
  timestamp.system_time()
}

pub fn is_after(a: Time, b: Time) -> Bool {
  timestamp.compare(a, b) == order.Gt
}

pub fn is_before(a: Time, b: Time) -> Bool {
  timestamp.compare(a, b) == order.Lt
}

pub fn add_seconds(t: Time, s: Int) -> Time {
  timestamp.add(t, duration.seconds(s))
}
