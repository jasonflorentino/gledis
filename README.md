# gledis

A toy implementation of Redis and the [Redis serialization protocol](https://redis.io/docs/latest/develop/reference/protocol-spec/) in [Gleam](https://gleam.run/) so I can get familiar with the language.

## Try it

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

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
