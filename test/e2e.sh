#!/usr/bin/env bash
set -em

CLI="redis-cli"

# 1 Command
# 2 Expected
# 3 Label
test() {
    local got="$($CLI $1)" expected="$2" label="$3"
    if [ "$got" = "$expected" ]; then
      echo "✓ $label"
    else
      echo "✗ $label: expected '$expected', got '$got'"
      echo "  command: $1"
      exit 1
    fi
}

# Start the server
gleam run &> server.log &
SERVER_PID=$!
echo "Server logging to server.log"
trap "kill -- -$SERVER_PID 2>/dev/null" EXIT

# Wait for it to be ready
echo -n "Waiting for server to start."
for i in $(seq 1 25); do
  if $CLI ping &>/dev/null; then
    echo "Server ready!"
    break
  fi
  printf "."
  sleep 0.2
done
echo

TTL=3
WAIT=$((TTL + 1))

# Tests
test "PING" "PONG" "PING works"
test "GET name" "" "GET returns nil"
test "SET name alice" "OK" "SET works"
test "GET name" "alice" "GET returns 'alice'"
test "SET name jason EX $TTL" "OK" "SET without nx works"
test "GET name" "jason" "GET returns 'jason'"
test "SET name bryan NX" "" "SET with NX returns nil"

echo "Waiting $WAIT seconds for TTL expiry..."
sleep $WAIT

test "SET name bryan NX EX $TTL" "OK" "SET with NX returns OK after expiry"
test "GET name" "bryan" "GET returns 'bryan'"

echo "Waiting $WAIT seconds for TTL expiry..."
sleep $WAIT

test "GET name" "" "GET returns nil"

echo
echo "All tests passed!"
