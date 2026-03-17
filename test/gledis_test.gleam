import gleam/list
import gleeunit
import internal/resp

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn parse_test() {
  // happy
  [
    #(<<"*1\r\n$4\r\nping\r\n">>, resp.RespArr([resp.RespBulk("ping")])),
    #(
      <<"*2\r\n$5\r\nhello\r\n$5\r\nworld\r\n">>,
      resp.RespArr([resp.RespBulk("hello"), resp.RespBulk("world")]),
    ),
  ]
  |> list.each(fn(test_data) {
    let #(input, expected) = test_data
    let assert Ok(#(result, rest)) = resp.parse(input)
    assert result == expected
    assert rest == <<>>
  })

  // sad
  [
    // invalid resp data type
    #(<<"fails">>),
    // malformed resp data -- array length doesnt match data
    #(<<"*2\r\n$4\r\nping\r\n">>),
    // malformed resp data -- bulk length doesnt match data
    #(<<"*1\r\n$4\r\npin\r\n">>),
    // malformed resp data -- bulk length doesnt match data
    #(<<"*1\r\n$3\r\nping\r\n">>),
  ]
  |> list.each(fn(test_data) {
    let #(input) = test_data
    let assert Error(_) = resp.parse(input)
  })
}
