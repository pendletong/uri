import gleam/uri as uri2
import gluri as uri
import gluri/internal/parser
import glychee/benchmark
import glychee/configuration

@target(erlang)
pub fn main() {
  configuration.initialize()
  configuration.set_pair(configuration.Warmup, 2)
  configuration.set_pair(configuration.Parallel, 2)

  parse_benchmark()
  // reg_name_benchmark()
  // ip_benchmark()
}

@target(erlang)
pub fn ip_benchmark() {
  benchmark.run(
    [
      benchmark.Function("ip_benchmark", fn(data) {
        fn() {
          let _ = parser.parse_dec_octet(data)
          Nil
        }
      }),
    ],
    [
      benchmark.Data("173", "173"),
      benchmark.Data("5", "5"),
      benchmark.Data("200", "200"),
      benchmark.Data("255", "255"),
      benchmark.Data("fail", "2b"),
    ],
  )
}

@target(erlang)
pub fn reg_name_benchmark() {
  benchmark.run(
    [
      benchmark.Function("reg_name_benchmark", fn(data) {
        fn() {
          let _ = parser.parse_reg_name(data)
          Nil
        }
      }),
    ],
    [
      benchmark.Data("long", "github.com"),
    ],
  )
}

@target(erlang)
pub fn parse_benchmark() {
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
    [
      benchmark.Data(
        "long",
        "https://github.com/gleam-lang/stdlib/issues/523#issuecomment-3288230480",
      ),
      benchmark.Data("ipv4", "https://192.255.36.4/"),
    ],
  )
}
