import gleam/list
import gleam/uri as uri2
import gluri as uri
import glychee/benchmark
import glychee/configuration

@target(erlang)
pub fn main() {
  configuration.initialize()
  configuration.set_pair(configuration.Warmup, 2)
  // configuration.set_pair(configuration.Parallel, 2)

  parse_benchmark()
}

@target(erlang)
pub fn parse_benchmark() {
  let data = [
    benchmark.Data("simple", "http://github.com"),
    benchmark.Data(
      "long",
      "https://github.com/gleam-lang/stdlib/issues/523#issuecomment-3288230480",
    ),
    benchmark.Data(
      "with user",
      "https://test_name:user%20$$$@github.com/gleam-lang/stdlib/issues/523#issuecomment-3288230480",
    ),
    benchmark.Data("ipv4", "https://192.255.36.4/"),
    benchmark.Data("ipv6", "http://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]"),
    benchmark.Data("ipv6 short", "http://[2001:0db8::1]"),
  ]

  // Test that all URIs parse successfully - this is because
  // when this is pushed back into earlier versions of the codebase,
  // some URIs may fail to parse due to a bug that has been fixed.
  list.each(data, fn(data) {
    let assert Ok(_) = uri.parse(data.data)
  })

  benchmark.run(
    [
      benchmark.Function("parse_benchmark", fn(data) {
        fn() {
          let _ = uri.parse(data)
          Nil
        }
      }),
      benchmark.Function("stdlib_parse_benchmark", fn(data) {
        fn() {
          let _ = uri2.parse(data)
          Nil
        }
      }),
    ],
    data,
  )
}
