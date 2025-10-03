import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri, Uri}
import splitter.{type Splitter}

type Scheme {
  Scheme(name: String, port: Int)
}

const scheme_port = [
  Scheme("http", 80),
  Scheme("https", 443),
  Scheme("ftp", 21),
  Scheme("ws", 80),
  Scheme("wss", 443),
]

pub fn get_port_for_scheme(scheme: String) -> Option(Int) {
  list.find(scheme_port, fn(sp) { sp.name == scheme })
  |> result.map(fn(sp) { sp.port })
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

pub fn try_parsers(
  over list: List(fn(String) -> Result(#(a, String), Nil)),
  against static_data: String,
) -> Result(#(a, String), Nil) {
  case list {
    [] -> Error(Nil)
    [first, ..rest] ->
      case first(static_data) {
        Error(_) -> try_parsers(rest, static_data)
        Ok(r) -> Ok(r)
      }
  }
}

pub fn parse_min_max(
  str: f,
  min: Int,
  max: Int,
  parse_fn: fn(f) -> Result(#(String, f), g),
) -> Result(#(String, f), Nil) {
  do_parse_min_max(str, "", min, max, parse_fn)
}

pub fn do_parse_min_max(
  str: d,
  acc: String,
  min: Int,
  max: Int,
  parse_fn: fn(d) -> Result(#(String, d), e),
) -> Result(#(String, d), Nil) {
  case parse_fn(str) {
    Error(_) -> {
      case min > 0 {
        True -> Error(Nil)
        False -> Ok(#(acc, str))
      }
    }
    Ok(#(l, rest)) -> {
      case max {
        1 -> Ok(#(acc <> l, rest))
        _ -> do_parse_min_max(rest, acc <> l, min - 1, max - 1, parse_fn)
      }
    }
  }
}

pub fn parse_optional(
  to_parse str: String,
  with opt_fn: fn(String) -> Result(#(String, String), Nil),
) -> #(String, String) {
  case opt_fn(str) {
    Error(Nil) -> #("", str)
    Ok(r) -> r
  }
}

pub fn parse_optional_result(
  to_parse str: String,
  with opt_fn: fn(String) -> Result(#(String, String), Nil),
) -> Result(#(String, String), Nil) {
  parse_optional(str, opt_fn) |> Ok
}

pub fn parse_this_then(
  to_parse str: String,
  with parsers: List(fn(String) -> Result(#(String, String), Nil)),
) -> Result(#(String, String), Nil) {
  do_parse_this_then(str, "", parsers)
}

fn do_parse_this_then(
  to_parse str: String,
  from initial: String,
  with parsers: List(fn(String) -> Result(#(String, String), Nil)),
) -> Result(#(String, String), Nil) {
  case parsers {
    [] -> Ok(#(initial, str))
    [head, ..tail] -> {
      case head(str) {
        Ok(#(res, rest)) -> do_parse_this_then(rest, initial <> res, tail)
        Error(_) -> Error(Nil)
      }
    }
  }
}

pub fn parse_multiple(
  to_parse str: String,
  with to_run: fn(String) -> Result(#(String, String), Nil),
) -> Result(#(String, String), Nil) {
  case do_parse_multiple(str, to_run, "") {
    Ok(#("", _)) | Error(Nil) -> Error(Nil)
    Ok(#(r, rest)) -> Ok(#(r, rest))
  }
}

fn do_parse_multiple(
  to_parse str: String,
  with to_run: fn(String) -> Result(#(String, String), Nil),
  acc ret: String,
) -> Result(#(String, String), Nil) {
  case str {
    "" -> Ok(#(ret, str))
    _ ->
      case to_run(str) {
        Ok(#(r, rest)) -> do_parse_multiple(rest, to_run, ret <> r)
        Error(_) -> Ok(#(ret, str))
      }
  }
}

pub fn combine_uris(uris: List(Uri)) -> Uri {
  list.fold(uris, Uri(None, None, None, None, "", None, None), fn(acc, uri) {
    let acc = case uri {
      Uri(Some(scheme), _, _, _, _, _, _) -> Uri(..acc, scheme: Some(scheme))
      _ -> acc
    }
    let acc = case uri {
      Uri(_, Some(userinfo), _, _, _, _, _) ->
        Uri(..acc, userinfo: Some(userinfo))
      _ -> acc
    }
    let acc = case uri {
      Uri(_, _, Some(host), _, _, _, _) -> Uri(..acc, host: Some(host))
      _ -> acc
    }
    let acc = case uri {
      Uri(_, _, _, Some(port), _, _, _) -> Uri(..acc, port: Some(port))
      _ -> acc
    }
    let acc = case uri {
      Uri(_, _, _, _, path, _, _) if path != "" -> Uri(..acc, path: path)
      _ -> acc
    }
    let acc = case uri {
      Uri(_, _, _, _, _, Some(query), _) -> Uri(..acc, query: Some(query))
      _ -> acc
    }
    case uri {
      Uri(_, _, _, _, _, _, Some(fragment)) ->
        Uri(..acc, fragment: Some(fragment))
      _ -> acc
    }
  })
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
  path |> string.reverse |> do_remove_segment |> string.reverse
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

pub fn parse_hex_digit(str: String) -> Result(#(String, String), Nil) {
  case string.pop_grapheme(str) {
    Ok(#("0" as char, tail))
    | Ok(#("1" as char, tail))
    | Ok(#("2" as char, tail))
    | Ok(#("3" as char, tail))
    | Ok(#("4" as char, tail))
    | Ok(#("5" as char, tail))
    | Ok(#("6" as char, tail))
    | Ok(#("7" as char, tail))
    | Ok(#("8" as char, tail))
    | Ok(#("9" as char, tail))
    | Ok(#("a" as char, tail))
    | Ok(#("b" as char, tail))
    | Ok(#("c" as char, tail))
    | Ok(#("d" as char, tail))
    | Ok(#("e" as char, tail))
    | Ok(#("f" as char, tail))
    | Ok(#("A" as char, tail))
    | Ok(#("B" as char, tail))
    | Ok(#("C" as char, tail))
    | Ok(#("D" as char, tail))
    | Ok(#("E" as char, tail))
    | Ok(#("F" as char, tail)) -> Ok(#(char, tail))

    _ -> Error(Nil)
  }
}

pub fn parse_hex_digits(str, min, max) {
  parse_min_max(str, min, max, parse_hex_digit)
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
