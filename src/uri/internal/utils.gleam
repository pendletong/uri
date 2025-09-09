import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import splitter.{type Splitter}
import types.{type Uri, Uri}

pub const scheme_port = [
  #("http", 80),
  #("https", 443),
  #("ftp", 21),
  #("ws", 80),
  #("wss", 443),
]

pub fn get_port_for_scheme(scheme: String) -> Option(Int) {
  list.find(scheme_port, fn(sp) { sp.0 == scheme })
  |> result.map(fn(sp) { sp.1 })
  |> option.from_result
}

pub fn merge(base: Uri, relative: Uri) -> Result(Uri, Nil) {
  use <- bool.guard(when: base.scheme == None, return: Error(Nil))
  let uri = case relative.scheme {
    Some(_) -> {
      Uri(..relative, path: remove_dot_segments(relative.path))
    }
    None -> {
      let scheme = base.scheme
      case relative.host, relative.port, relative.userinfo {
        Some(_), _, _ | _, Some(_), _ | _, _, Some(_) -> {
          Uri(..relative, scheme:, path: remove_dot_segments(relative.path))
        }
        _, _, _ -> {
          case relative.path {
            "" -> {
              let query = case relative.query {
                Some(_) -> relative.query
                _ -> base.query
              }
              Uri(..base, query:)
            }
            "/" <> _ -> {
              Uri(
                ..base,
                path: remove_dot_segments(relative.path),
                query: relative.query,
              )
            }
            _ -> {
              let path = merge_paths(base, relative)
              Uri(
                ..base,
                path: remove_dot_segments(path),
                query: relative.query,
              )
            }
          }
        }
      }
    }
  }

  Uri(..uri, fragment: relative.fragment) |> Ok
}

fn has_authority(uri: Uri) -> Bool {
  case uri.host {
    Some(_) -> True
    _ -> False
  }
}

fn merge_paths(base: Uri, relative: Uri) -> String {
  case has_authority(base), base.path {
    True, "" -> "/" <> relative.path
    _, _ -> {
      remove_segment(base.path) <> "/" <> relative.path
    }
  }
}

pub fn normalise(uri: Uri) -> Uri {
  let percent_splitter = splitter.new(["%"])
  let percent_normaliser = normalise_percent(percent_splitter, _)
  let scheme = uri.scheme |> option.map(string.lowercase)
  let userinfo = uri.userinfo |> option.map(percent_normaliser)
  let port = uri.port |> scheme_normalisation(scheme)
  let host =
    uri.host |> option.map(string.lowercase) |> option.map(percent_normaliser)
  let path =
    uri.path
    |> percent_normaliser
    |> remove_dot_segments
    |> path_normalise(scheme, host)
  let query = uri.query |> option.map(percent_normaliser)
  let fragment = uri.fragment |> option.map(percent_normaliser)

  Uri(scheme, userinfo, host, port, path, query, fragment)
}

pub fn path_normalise(str: String, scheme: Option(String), host: Option(String)) {
  case str {
    "" -> {
      case scheme {
        Some("http") | Some("https") -> {
          case host {
            Some(_) -> "/"
            _ -> ""
          }
        }
        _ -> ""
      }
    }
    _ -> str
  }
}

pub fn scheme_normalisation(
  port: Option(Int),
  scheme: Option(String),
) -> Option(Int) {
  case scheme, port {
    Some(scheme), Some(_) -> {
      case get_port_for_scheme(scheme) == port {
        True -> None
        False -> port
      }
    }
    _, _ -> port
  }
}

fn remove_dot_segments(path: String) -> String {
  do_remove_dot_segments(path, "")
}

fn do_remove_dot_segments(path: String, acc: String) -> String {
  case path {
    "../" <> rest | "./" <> rest -> do_remove_dot_segments(rest, acc)
    "/./" <> rest -> do_remove_dot_segments("/" <> rest, acc)
    "/." -> acc <> "/"
    "/../" <> rest -> do_remove_dot_segments("/" <> rest, remove_segment(acc))
    "/.." -> remove_segment(acc) <> "/"
    "." | ".." | "" -> acc <> path
    _ -> {
      let assert Ok(#(char, rest)) = string.pop_grapheme(path)
      do_remove_dot_segments(rest, acc <> char)
    }
  }
}

fn remove_segment(path: String) -> String {
  path |> echo |> string.reverse |> do_remove_segment |> string.reverse
}

fn do_remove_segment(path: String) -> String {
  case path {
    "/" <> rest -> rest
    "" -> ""
    _ -> {
      do_remove_segment(path |> string.drop_start(1))
    }
  }
}

fn normalise_percent(percent_splitter: Splitter, str: String) -> String {
  do_normalise_percent(percent_splitter, str, "")
}

fn do_normalise_percent(
  percent_splitter: Splitter,
  str: String,
  res: String,
) -> String {
  let #(before, pc, after) = splitter.split(percent_splitter, str)
  case pc {
    "" -> res <> before
    _ -> {
      case after {
        "" -> res <> before
        _ -> {
          let #(pc_val, rest) = case parse_hex_digit(after) {
            Ok(#(pc1, rest)) -> {
              case parse_hex_digit(rest) {
                Ok(#(pc2, rest)) -> {
                  let hex = pc1 <> pc2
                  let v = unescape_percent(hex)
                  case v == hex {
                    True -> #("%" <> string.uppercase(v), rest)
                    False -> #(string.lowercase(v), rest)
                  }
                }
                Error(_) -> #("", after)
              }
            }
            Error(_) -> #("", after)
          }
          do_normalise_percent(percent_splitter, rest, res <> before <> pc_val)
        }
      }
    }
  }
}

fn unescape_percent(str: String) -> String {
  case int.base_parse(str, 16) {
    Error(_) -> str
    Ok(ascii) -> {
      case is_unreserved_char(ascii) {
        True -> {
          let assert Ok(cpnt) = string.utf_codepoint(ascii)
          string.from_utf_codepoints([cpnt])
        }
        False -> str
      }
    }
  }
}

pub fn parse_hex_digit(str) {
  case str {
    "0" as l <> rest
    | "1" as l <> rest
    | "2" as l <> rest
    | "3" as l <> rest
    | "4" as l <> rest
    | "5" as l <> rest
    | "6" as l <> rest
    | "7" as l <> rest
    | "8" as l <> rest
    | "9" as l <> rest
    | "a" as l <> rest
    | "b" as l <> rest
    | "c" as l <> rest
    | "d" as l <> rest
    | "e" as l <> rest
    | "f" as l <> rest
    | "A" as l <> rest
    | "B" as l <> rest
    | "C" as l <> rest
    | "D" as l <> rest
    | "E" as l <> rest
    | "F" as l <> rest -> Ok(#(l, rest))
    _ -> Error(Nil)
  }
}

fn encoding_not_needed(i: Int) -> Bool {
  // $-_.+!*'()
  case i {
    36 | 45 | 95 | 46 | 43 | 33 | 42 | 39 | 40 | 41 -> True
    _ -> False
  }
}

fn is_unreserved_char(i: Int) -> Bool {
  case i {
    45 | 46 | 95 | 126 -> True
    _ if i >= 48 && i <= 57 -> True
    _ if i >= 65 && i <= 90 -> True
    _ if i >= 97 && i <= 122 -> True
    _ -> False
  }
}

pub fn percent_decode(str: String) -> Result(String, Nil) {
  let percent_splitter = splitter.new(["%"])
  do_percent_decode(percent_splitter, str, "")
}

fn do_percent_decode(
  splitter: splitter.Splitter,
  str: String,
  acc: String,
) -> Result(String, Nil) {
  case splitter.split(splitter, str) {
    #(before, "", "") -> Ok(acc <> before)
    #(before, "%", after) -> {
      use #(hd1, rest) <- result.try(parse_hex_digit(after))
      use #(hd2, rest) <- result.try(parse_hex_digit(rest))

      use char <- result.try(int.base_parse(hd1 <> hd2, 16))
      case int.bitwise_and(char, 128) {
        0 -> {
          use char <- result.try(string.utf_codepoint(char))
          do_percent_decode(
            splitter,
            rest,
            acc <> before <> string.from_utf_codepoints([char]),
          )
        }
        _ -> {
          case int.bitwise_and(char, 224) {
            192 -> {
              "2bytes" |> echo
              use #(char, rest) <- result.try(decode_2byte_utf(hd1 <> hd2, rest))

              do_percent_decode(splitter, rest, acc <> before <> char)
            }
            _ -> {
              case int.bitwise_and(char, 240) {
                224 -> {
                  use #(char, rest) <- result.try(decode_3byte_utf(
                    hd1 <> hd2,
                    rest,
                  ))

                  do_percent_decode(splitter, rest, acc <> before <> char)
                }
                _ -> {
                  case int.bitwise_and(char, 248) {
                    240 -> {
                      use #(char, rest) <- result.try(decode_4byte_utf(
                        hd1 <> hd2,
                        rest,
                      ))

                      do_percent_decode(splitter, rest, acc <> before <> char)
                    }
                    _ -> Error(Nil)
                  }
                }
              }
            }
          }
        }
      }
    }
    _ -> Error(Nil)
  }
}

pub fn decode_2byte_utf(
  first_byte: String,
  rest: String,
) -> Result(#(String, String), Nil) {
  use rest <- result.try(case rest {
    "%" <> rest -> Ok(rest)
    _ -> Error(Nil)
  })
  use #(hd3, rest) <- result.try(parse_hex_digit(rest))

  use <- bool.guard(when: !within_byte_range(hd3), return: Error(Nil))

  use #(hd4, rest) <- result.try(parse_hex_digit(rest))

  use bytes <- result.try(int.base_parse(first_byte <> hd3 <> hd4, 16))

  let assert <<
    _:size(3),
    x:size(3),
    y1:size(2),
    _:size(2),
    y2:size(2),
    z:size(4),
  >> = <<bytes:size(16)>>
  let assert <<i:size(16)>> = <<
    0:size(5),
    x:size(3),
    y1:size(2),
    y2:size(2),
    z:size(4),
  >>

  use res <- result.try(string.utf_codepoint(i))

  Ok(#(string.from_utf_codepoints([res]), rest))
}

pub fn decode_3byte_utf(
  first_byte: String,
  rest: String,
) -> Result(#(String, String), Nil) {
  use rest <- result.try(case rest {
    "%" <> rest -> Ok(rest)
    _ -> Error(Nil)
  })
  use #(hd3, rest) <- result.try(parse_hex_digit(rest))

  use <- bool.guard(when: !within_byte_range(hd3), return: Error(Nil))

  use #(hd4, rest) <- result.try(parse_hex_digit(rest))
  use rest <- result.try(case rest {
    "%" <> rest -> Ok(rest)
    _ -> Error(Nil)
  })
  use #(hd5, rest) <- result.try(parse_hex_digit(rest))

  use <- bool.guard(when: !within_byte_range(hd5), return: Error(Nil))

  use #(hd6, rest) <- result.try(parse_hex_digit(rest))

  use bytes <- result.try(int.base_parse(
    first_byte <> hd3 <> hd4 <> hd5 <> hd6,
    16,
  ))

  let assert <<
    _:size(4),
    w:size(4),
    _:size(2),
    x:size(4),
    y1:size(2),
    _:size(2),
    y2:size(2),
    z:size(4),
  >> = <<bytes:size(24)>>
  let assert <<i:size(16)>> = <<
    w:size(4),
    x:size(4),
    y1:size(2),
    y2:size(2),
    z:size(4),
  >>

  use res <- result.try(string.utf_codepoint(i))

  Ok(#(string.from_utf_codepoints([res]), rest))
}

fn decode_4byte_utf(
  first_byte: String,
  rest: String,
) -> Result(#(String, String), Nil) {
  use rest <- result.try(case rest {
    "%" <> rest -> Ok(rest)
    _ -> Error(Nil)
  })
  use #(hd3, rest) <- result.try(parse_hex_digit(rest))

  use <- bool.guard(when: !within_byte_range(hd3), return: Error(Nil))

  use #(hd4, rest) <- result.try(parse_hex_digit(rest))
  use rest <- result.try(case rest {
    "%" <> rest -> Ok(rest)
    _ -> Error(Nil)
  })
  use #(hd5, rest) <- result.try(parse_hex_digit(rest))

  use <- bool.guard(when: !within_byte_range(hd5), return: Error(Nil))

  use #(hd6, rest) <- result.try(parse_hex_digit(rest))
  use rest <- result.try(case rest {
    "%" <> rest -> Ok(rest)
    _ -> Error(Nil)
  })
  use #(hd7, rest) <- result.try(parse_hex_digit(rest))

  use <- bool.guard(when: !within_byte_range(hd7), return: Error(Nil))

  use #(hd8, rest) <- result.try(parse_hex_digit(rest))

  use bytes <- result.try(int.base_parse(
    first_byte <> hd3 <> hd4 <> hd5 <> hd6 <> hd7 <> hd8,
    16,
  ))

  let assert <<
    _:size(5),
    u:size(1),
    v1:size(2),
    _:size(2),
    v2:size(2),
    w:size(4),
    _:size(2),
    x:size(4),
    y1:size(2),
    _:size(2),
    y2:size(2),
    z:size(4),
  >> = <<bytes:size(32)>>
  let assert <<i:size(24)>> = <<
    0:size(3),
    u:size(1),
    v1:size(2),
    v2:size(2),
    w:size(4),
    x:size(4),
    y1:size(2),
    y2:size(2),
    z:size(4),
  >>

  use res <- result.try(string.utf_codepoint(i))

  Ok(#(string.from_utf_codepoints([res]), rest))
}

fn within_byte_range(str: String) {
  case str {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" -> False
    _ -> True
  }
}

pub fn do_percent_encode(str: String) -> String {
  string.to_utf_codepoints(str)
  |> list.map(string.utf_codepoint_to_int)
  |> list.map(encode_codepoint)
  |> string.concat
}

fn encode_codepoint(codepoint: Int) -> String {
  case codepoint <= 127 {
    True -> {
      case is_unreserved_char(codepoint) || encoding_not_needed(codepoint) {
        True -> {
          let assert Ok(cpnt) = string.utf_codepoint(codepoint)
          string.from_utf_codepoints([cpnt])
        }
        False -> {
          "%" <> int.to_base16(codepoint)
        }
      }
    }
    False -> {
      case codepoint <= 2047 {
        True -> {
          let assert <<_:size(5), x:size(3), y1:size(2), y2:size(2), z:size(4)>> = <<
            codepoint:size(16),
          >>
          let res = <<
            6:size(3),
            x:size(3),
            y1:size(2),
            2:size(2),
            y2:size(2),
            z:size(4),
          >>
          let assert <<b1:size(8), b2:size(8)>> = res
          "%" <> int.to_base16(b1) <> "%" <> int.to_base16(b2)
        }
        False -> {
          case codepoint <= 65_535 {
            True -> {
              let assert <<
                w:size(4),
                x:size(4),
                y1:size(2),
                y2:size(2),
                z:size(4),
              >> = <<
                codepoint:size(16),
              >>
              let res = <<
                14:size(4),
                w:size(4),
                2:size(2),
                x:size(4),
                y1:size(2),
                2:size(2),
                y2:size(2),
                z:size(4),
              >>
              let assert <<b1:size(8), b2:size(8), b3:size(8)>> = res
              "%"
              <> int.to_base16(b1)
              <> "%"
              <> int.to_base16(b2)
              <> "%"
              <> int.to_base16(b3)
            }
            False -> {
              let assert <<
                _:size(3),
                u:size(1),
                v1:size(2),
                v2:size(2),
                w:size(4),
                x:size(4),
                y1:size(2),
                y2:size(2),
                z:size(4),
              >> = <<codepoint:size(24)>>
              let res = <<
                30:size(5),
                u:size(1),
                v1:size(2),
                2:size(2),
                v2:size(2),
                w:size(4),
                2:size(2),
                x:size(4),
                y1:size(2),
                2:size(2),
                y2:size(2),
                z:size(4),
              >>

              let assert <<b1:size(8), b2:size(8), b3:size(8), b4:size(8)>> =
                res
              "%"
              <> int.to_base16(b1)
              <> "%"
              <> int.to_base16(b2)
              <> "%"
              <> int.to_base16(b3)
              <> "%"
              <> int.to_base16(b4)
            }
          }
        }
      }
    }
  }
}
