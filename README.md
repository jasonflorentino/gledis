# gledis

A toy implementation of Redis and the [Redis serialization protocol](https://redis.io/docs/latest/develop/reference/protocol-spec/) in [Gleam](https://gleam.run/) so I can get familiar with the language.

## Try it

- Run the server
  ```shell
  gleam run
  ```
- Send commands using a client app like `redis-cli`
```shell
$ redis-cli
127.0.0.1:6379> ping
PONG
127.0.0.1:6379> get name
(nil)
127.0.0.1:6379> set name jason
OK
127.0.0.1:6379> get name
jason
```

## Testing

- Run unit tests with gleam
  ```shell
  gleam test
  ```
- There's also an end to end test that spins up the server, the `redis-cli`, and asserts that outputs match their commands which helps ensure behaviours dont regress over refactors.
  ```shell
  ./test_e2e.sh
  ```

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
