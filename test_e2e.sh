#!/usr/bin/env bash
set -em

CLI="redis-cli"

assert_eq() {
  local got="$1" expected="$2" label="$3"
  if [ "$got" = "$expected" ]; then
    echo "✓ $label"
  else
    echo "✗ $label: expected '$expected', got '$got'"
    exit 1
  fi
}

# Start the server
gleam run &> server.log &
SERVER_PID=$!
echo "Server logging to server.log"
trap "kill -- -$SERVER_PID 2>/dev/null" EXIT

# Wait for it to be ready
echo "Waiting for server to start..."
for i in $(seq 1 10); do
  if $CLI ping &>/dev/null; then
    echo " Server ready!"
    break
  fi
  printf "."
  sleep 0.5
done

# Tests
assert_eq "$($CLI GET name)" "" "GET name returns nil"
assert_eq "$($CLI SET name jason EX 5)" "OK" "SET name with expiry"
assert_eq "$($CLI GET name)" "jason" "GET name returns 'jason'"
assert_eq "$($CLI SET name bryan NX)" "" "SET name with NX returns nil"

echo "Waiting 6 seconds for TTL expiry..."
sleep 6

assert_eq "$($CLI SET name bryan NX)" "OK" "SET name with NX returns OK after expiry"
assert_eq "$($CLI GET name)" "bryan" "GET name returns 'bryan'"

echo "All tests passed!"
