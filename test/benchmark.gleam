import gleam/string
import gleam/uri as uri2
import gluri as uri
import glychee/benchmark
import glychee/configuration

@target(erlang)
pub fn main() {
  configuration.initialize()
  configuration.set_pair(configuration.Warmup, 2)
  configuration.set_pair(configuration.Parallel, 2)

  // pop_benchmark()
  parse_benchmark()
  // reg_name_benchmark()
  // ip_benchmark()
}

// @target(erlang)
// pub fn ip_benchmark() {
//   benchmark.run(
//     [
//       benchmark.Function("ip_benchmark", fn(data) {
//         fn() {
//           let _ = parser.parse_dec_octet(data)
//           Nil
//         }
//       }),
//     ],
//     [
//       benchmark.Data("173", "173"),
//       benchmark.Data("5", "5"),
//       benchmark.Data("200", "200"),
//       benchmark.Data("255", "255"),
//       benchmark.Data("fail", "2b"),
//     ],
//   )
// }

// @target(erlang)
// pub fn reg_name_benchmark() {
//   benchmark.run(
//     [
//       benchmark.Function("reg_name_benchmark", fn(data) {
//         fn() {
//           let _ = parser.parse_reg_name(data)
//           Nil
//         }
//       }),
//     ],
//     [
//       benchmark.Data("long", "github.com"),
//     ],
//   )
// }

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
      benchmark.Data(
        "with user",
        "https://test_name:user%20$$$@github.com/gleam-lang/stdlib/issues/523#issuecomment-3288230480",
      ),
      benchmark.Data("ipv4", "https://192.255.36.4/"),
    ],
  )
}

@target(erlang)
pub fn pop_benchmark() {
  benchmark.run(
    [
      benchmark.Function("pop", fn(data) { fn() { pop(data, "") } }),
      benchmark.Function("pop2", fn(data) { fn() { pop4(data, "") } }),
      benchmark.Function("pop3", fn(data) { fn() { pop5(data, "") } }),
      benchmark.Function("match", fn(data) { fn() { pop2(data, "") } }),
      benchmark.Function("match_2", fn(data) { fn() { pop3(data, "") } }),
    ],
    [
      // benchmark.Data("long", "abcdefghijklmnopqrstuvwxyz"),
      benchmark.Data(
        "with user",
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
      ),
      // benchmark.Data("ipv4", "https://192.255.36.4/"),
    ],
  )
}

pub fn pop(input, _) {
  case string.pop_grapheme(input) {
    Ok(#(char, tail)) -> {
      let assert [codepoint] = string.to_utf_codepoints(char)
      let i = string.utf_codepoint_to_int(codepoint)
      case i {
        _ if i >= 0x41 && i <= 0x5A -> pop(tail, char)
        _ if i >= 0x61 && i <= 0x7A -> pop(tail, char)
        _ -> Nil
      }
    }
    Error(_) -> Nil
  }
}

pub fn pop2(input, _) {
  case input {
    "a" as j <> tail
    | "b" as j <> tail
    | "c" as j <> tail
    | "d" as j <> tail
    | "e" as j <> tail
    | "f" as j <> tail
    | "g" as j <> tail
    | "h" as j <> tail
    | "i" as j <> tail
    | "j" as j <> tail
    | "k" as j <> tail
    | "l" as j <> tail
    | "m" as j <> tail
    | "n" as j <> tail
    | "o" as j <> tail
    | "p" as j <> tail
    | "q" as j <> tail
    | "r" as j <> tail
    | "s" as j <> tail
    | "t" as j <> tail
    | "u" as j <> tail
    | "v" as j <> tail
    | "w" as j <> tail
    | "x" as j <> tail
    | "y" as j <> tail
    | "z" as j <> tail
    | "A" as j <> tail
    | "B" as j <> tail
    | "C" as j <> tail
    | "D" as j <> tail
    | "E" as j <> tail
    | "F" as j <> tail
    | "G" as j <> tail
    | "H" as j <> tail
    | "I" as j <> tail
    | "J" as j <> tail
    | "K" as j <> tail
    | "L" as j <> tail
    | "M" as j <> tail
    | "N" as j <> tail
    | "O" as j <> tail
    | "P" as j <> tail
    | "Q" as j <> tail
    | "R" as j <> tail
    | "S" as j <> tail
    | "T" as j <> tail
    | "U" as j <> tail
    | "V" as j <> tail
    | "W" as j <> tail
    | "X" as j <> tail
    | "Y" as j <> tail
    | "Z" as j <> tail -> pop2(tail, j)
    _ -> Nil
  }
}

pub fn pop3(input, _) {
  case input {
    "a" <> tail
    | "b" <> tail
    | "c" <> tail
    | "d" <> tail
    | "e" <> tail
    | "f" <> tail
    | "g" <> tail
    | "h" <> tail
    | "i" <> tail
    | "j" <> tail
    | "k" <> tail
    | "l" <> tail
    | "m" <> tail
    | "n" <> tail
    | "o" <> tail
    | "p" <> tail
    | "q" <> tail
    | "r" <> tail
    | "s" <> tail
    | "t" <> tail
    | "u" <> tail
    | "v" <> tail
    | "w" <> tail
    | "x" <> tail
    | "y" <> tail
    | "z" <> tail
    | "A" <> tail
    | "B" <> tail
    | "C" <> tail
    | "D" <> tail
    | "E" <> tail
    | "F" <> tail
    | "G" <> tail
    | "H" <> tail
    | "I" <> tail
    | "J" <> tail
    | "K" <> tail
    | "L" <> tail
    | "M" <> tail
    | "N" <> tail
    | "O" <> tail
    | "P" <> tail
    | "Q" <> tail
    | "R" <> tail
    | "S" <> tail
    | "T" <> tail
    | "U" <> tail
    | "V" <> tail
    | "W" <> tail
    | "X" <> tail
    | "Y" <> tail
    | "Z" <> tail -> pop3(tail, "")
    _ -> Nil
  }
}

pub fn pop4(input, _) {
  case string.pop_grapheme(input) {
    Ok(#(char, tail)) -> {
      case char {
        "a"
        | "b"
        | "c"
        | "d"
        | "e"
        | "f"
        | "g"
        | "h"
        | "i"
        | "j"
        | "k"
        | "l"
        | "m"
        | "n"
        | "o"
        | "p"
        | "q"
        | "r"
        | "s"
        | "t"
        | "u"
        | "v"
        | "w"
        | "x"
        | "y"
        | "z"
        | "A"
        | "B"
        | "C"
        | "D"
        | "E"
        | "F"
        | "G"
        | "H"
        | "I"
        | "J"
        | "K"
        | "L"
        | "M"
        | "N"
        | "O"
        | "P"
        | "Q"
        | "R"
        | "S"
        | "T"
        | "U"
        | "V"
        | "W"
        | "X"
        | "Y"
        | "Z" -> pop4(tail, char)
        _ -> Nil
      }
    }
    Error(_) -> Nil
  }
}

pub fn pop5(input, _) {
  case string.pop_grapheme(input) {
    Ok(#("a" as char, tail))
    | Ok(#("b" as char, tail))
    | Ok(#("c" as char, tail))
    | Ok(#("d" as char, tail))
    | Ok(#("e" as char, tail))
    | Ok(#("f" as char, tail))
    | Ok(#("g" as char, tail))
    | Ok(#("h" as char, tail))
    | Ok(#("i" as char, tail))
    | Ok(#("j" as char, tail))
    | Ok(#("k" as char, tail))
    | Ok(#("l" as char, tail))
    | Ok(#("m" as char, tail))
    | Ok(#("n" as char, tail))
    | Ok(#("o" as char, tail))
    | Ok(#("p" as char, tail))
    | Ok(#("q" as char, tail))
    | Ok(#("r" as char, tail))
    | Ok(#("s" as char, tail))
    | Ok(#("t" as char, tail))
    | Ok(#("u" as char, tail))
    | Ok(#("v" as char, tail))
    | Ok(#("w" as char, tail))
    | Ok(#("x" as char, tail))
    | Ok(#("y" as char, tail))
    | Ok(#("z" as char, tail))
    | Ok(#("A" as char, tail))
    | Ok(#("B" as char, tail))
    | Ok(#("C" as char, tail))
    | Ok(#("D" as char, tail))
    | Ok(#("E" as char, tail))
    | Ok(#("F" as char, tail))
    | Ok(#("G" as char, tail))
    | Ok(#("H" as char, tail))
    | Ok(#("I" as char, tail))
    | Ok(#("J" as char, tail))
    | Ok(#("K" as char, tail))
    | Ok(#("L" as char, tail))
    | Ok(#("M" as char, tail))
    | Ok(#("N" as char, tail))
    | Ok(#("O" as char, tail))
    | Ok(#("P" as char, tail))
    | Ok(#("Q" as char, tail))
    | Ok(#("R" as char, tail))
    | Ok(#("S" as char, tail))
    | Ok(#("T" as char, tail))
    | Ok(#("U" as char, tail))
    | Ok(#("V" as char, tail))
    | Ok(#("W" as char, tail))
    | Ok(#("X" as char, tail))
    | Ok(#("Y" as char, tail))
    | Ok(#("Z" as char, tail)) -> pop4(tail, char)
    _ -> Nil
  }
}
