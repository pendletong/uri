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

const scheme_port: List(Scheme) = [
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

pub fn parse_count(
  str: f,
  max: Int,
  parse_fn: fn(f) -> Result(#(String, f), g),
) -> #(Int, String, f) {
  do_parse_count(str, 0, "", max, parse_fn)
}

fn do_parse_count(
  str: f,
  i: Int,
  acc: String,
  max: Int,
  parse_fn: fn(f) -> Result(#(String, f), g),
) -> #(Int, String, f) {
  case i == max {
    True -> #(i, acc, str)
    False -> {
      case parse_fn(str) {
        Error(_) -> #(i, acc, str)
        Ok(#(l, rest)) -> do_parse_count(rest, i + 1, acc <> l, max, parse_fn)
      }
    }
  }
}

pub fn parse_min_max(
  str: d,
  min: Int,
  max: Int,
  parse_fn: fn(d) -> Result(#(String, d), e),
) -> Result(#(String, d), Nil) {
  do_parse_min_max(str, "", 0, min, max, parse_fn)
}

fn do_parse_min_max(
  str: d,
  acc: String,
  i: Int,
  min: Int,
  max: Int,
  parse_fn: fn(d) -> Result(#(String, d), e),
) -> Result(#(String, d), Nil) {
  case i == max {
    True -> Ok(#(acc, str))
    False -> {
      case parse_fn(str) {
        Error(_) -> {
          case min > i {
            True -> Error(Nil)
            False -> Ok(#(acc, str))
          }
        }
        Ok(#(l, rest)) ->
          do_parse_min_max(rest, acc <> l, i + 1, min, max, parse_fn)
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

pub fn path_normalise(
  str: String,
  scheme: Option(String),
  host: Option(String),
) -> String {
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
  case str {
    "0" as char <> tail
    | "1" as char <> tail
    | "2" as char <> tail
    | "3" as char <> tail
    | "4" as char <> tail
    | "5" as char <> tail
    | "6" as char <> tail
    | "7" as char <> tail
    | "8" as char <> tail
    | "9" as char <> tail
    | "a" as char <> tail
    | "b" as char <> tail
    | "c" as char <> tail
    | "d" as char <> tail
    | "e" as char <> tail
    | "f" as char <> tail
    | "A" as char <> tail
    | "B" as char <> tail
    | "C" as char <> tail
    | "D" as char <> tail
    | "E" as char <> tail
    | "F" as char <> tail -> Ok(#(char, tail))

    _ -> Error(Nil)
  }
}

pub fn parse_hex_digit_in_byte_range(
  str: String,
) -> Result(#(String, String), Nil) {
  case str {
    "8" as char <> tail
    | "9" as char <> tail
    | "a" as char <> tail
    | "b" as char <> tail
    | "c" as char <> tail
    | "d" as char <> tail
    | "e" as char <> tail
    | "f" as char <> tail
    | "A" as char <> tail
    | "B" as char <> tail
    | "C" as char <> tail
    | "D" as char <> tail
    | "E" as char <> tail
    | "F" as char <> tail -> Ok(#(char, tail))

    _ -> Error(Nil)
  }
}

pub fn parse_hex_digits(
  str: String,
  min: Int,
  max: Int,
) -> Result(#(String, String), Nil) {
  parse_min_max(str, min, max, parse_hex_digit)
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
      case parse_this_then(after, [parse_hex_digit, parse_hex_digit]) {
        Ok(#(digits, rest)) ->
          decode_hex_digits(digits, rest, acc <> before, splitter)
        Error(_) -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn decode_hex_digits(
  digits: String,
  rest: String,
  acc: String,
  splitter: splitter.Splitter,
) {
  case int.base_parse(digits, 16) {
    Ok(char) -> {
      case char >= 128 {
        True -> {
          case get_utf_decoder(char) {
            Ok(f) -> {
              case f(digits, rest) {
                Ok(#(char, rest)) ->
                  do_percent_decode(splitter, rest, acc <> char)
                Error(_) -> Error(Nil)
              }
            }
            Error(_) -> Error(Nil)
          }
        }
        False -> {
          case string.utf_codepoint(char) {
            Ok(char) -> {
              do_percent_decode(
                splitter,
                rest,
                acc <> string.from_utf_codepoints([char]),
              )
            }
            Error(_) -> Error(Nil)
          }
        }
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn get_utf_decoder(
  char: Int,
) -> Result(fn(String, String) -> Result(#(String, String), Nil), Nil) {
  case char >= 240 {
    True -> Ok(decode_4byte_utf)
    False -> {
      case char >= 224 {
        True -> Ok(decode_3byte_utf)
        False -> {
          case char >= 192 {
            True -> Ok(decode_2byte_utf)
            False -> Error(Nil)
          }
        }
      }
    }
  }
}

fn parse_percent(str: String) {
  case str {
    "%" <> rest -> Ok(#("", rest))
    _ -> Error(Nil)
  }
}

fn decode_2byte_utf(
  first_byte: String,
  rest: String,
) -> Result(#(String, String), Nil) {
  first_byte |> echo
  case
    parse_this_then(rest, [
      parse_percent,
      parse_hex_digit_in_byte_range,
      parse_hex_digit,
    ])
  {
    Ok(#(second_byte, rest)) -> {
      case int.base_parse(first_byte <> second_byte, 16) {
        Ok(bytes) -> {
          convert_2byte_utf(bytes, rest)
        }
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn convert_2byte_utf(
  bytes: Int,
  rest: String,
) -> Result(#(String, String), Nil) {
  case <<bytes:size(16)>> {
    <<_:size(3), x:size(3), y1:size(2), _:size(2), y2:size(2), z:size(4)>> -> {
      case
        <<
          0:size(5),
          x:size(3),
          y1:size(2),
          y2:size(2),
          z:size(4),
        >>
      {
        <<i:size(16)>> -> {
          case string.utf_codepoint(i) {
            Ok(res) -> Ok(#(string.from_utf_codepoints([res]), rest))
            Error(_) -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn decode_3byte_utf(
  first_byte: String,
  rest: String,
) -> Result(#(String, String), Nil) {
  case
    parse_this_then(rest, [
      parse_percent,
      parse_hex_digit_in_byte_range,
      parse_hex_digit,
      parse_percent,
      parse_hex_digit_in_byte_range,
      parse_hex_digit,
    ])
  {
    Ok(#(second_bytes, rest)) -> {
      case int.base_parse(first_byte <> second_bytes, 16) {
        Ok(bytes) -> {
          convert_3byte_utf(bytes, rest)
        }
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn convert_3byte_utf(
  bytes: Int,
  rest: String,
) -> Result(#(String, String), Nil) {
  case <<bytes:size(24)>> {
    <<
      _:size(4),
      w:size(4),
      _:size(2),
      x:size(4),
      y1:size(2),
      _:size(2),
      y2:size(2),
      z:size(4),
    >> -> {
      case
        <<
          w:size(4),
          x:size(4),
          y1:size(2),
          y2:size(2),
          z:size(4),
        >>
      {
        <<i:size(16)>> -> {
          case string.utf_codepoint(i) {
            Ok(res) -> Ok(#(string.from_utf_codepoints([res]), rest))
            Error(_) -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    }

    _ -> Error(Nil)
  }
}

fn decode_4byte_utf(
  first_byte: String,
  rest: String,
) -> Result(#(String, String), Nil) {
  case
    parse_this_then(rest, [
      parse_percent,
      parse_hex_digit_in_byte_range,
      parse_hex_digit,
      parse_percent,
      parse_hex_digit_in_byte_range,
      parse_hex_digit,
      parse_percent,
      parse_hex_digit_in_byte_range,
      parse_hex_digit,
    ])
  {
    Ok(#(second_bytes, rest)) -> {
      case int.base_parse(first_byte <> second_bytes, 16) {
        Ok(bytes) -> {
          convert_4byte_utf(bytes, rest)
        }
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn convert_4byte_utf(
  bytes: Int,
  rest: String,
) -> Result(#(String, String), Nil) {
  case <<bytes:size(32)>> {
    <<
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
    >> -> {
      case
        <<
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
      {
        <<i:size(24)>> -> {
          case string.utf_codepoint(i) {
            Ok(res) -> Ok(#(string.from_utf_codepoints([res]), rest))
            Error(_) -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn keep_char_in_query(codepoint: Int) -> Bool {
  case is_unreserved_char(codepoint) {
    True -> True
    False -> {
      case codepoint {
        33 | 36 | 39 | 40 | 41 | 42 | 45 | 46 -> True
        _ -> False
      }
    }
  }
}

pub fn do_percent_encode_for_query(str: String) -> String {
  string.to_utf_codepoints(str)
  |> list.map(string.utf_codepoint_to_int)
  |> list.map(encode_codepoint(_, keep_char_in_query))
  |> string.concat
}

pub fn do_percent_encode(str: String) -> String {
  string.to_utf_codepoints(str)
  |> list.map(string.utf_codepoint_to_int)
  |> list.map(encode_codepoint(_, is_unreserved_char))
  |> string.concat
}

fn encode_codepoint(codepoint: Int, keep_char: fn(Int) -> Bool) -> String {
  case codepoint <= 127 {
    True -> {
      case keep_char(codepoint) {
        True -> {
          let assert Ok(cpnt) = string.utf_codepoint(codepoint)
          string.from_utf_codepoints([cpnt])
        }
        False -> {
          "%" <> string.pad_start(int.to_base16(codepoint), 2, "0")
        }
      }
    }
    False -> {
      case codepoint <= 2047 {
        True -> {
          encode_2byte_utf(codepoint)
        }
        False -> {
          case codepoint <= 65_535 {
            True -> {
              encode_3byte_utf(codepoint)
            }
            False -> {
              encode_4byte_utf(codepoint)
            }
          }
        }
      }
    }
  }
}

fn encode_2byte_utf(codepoint: Int) -> String {
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

fn encode_3byte_utf(codepoint: Int) -> String {
  let assert <<w:size(4), x:size(4), y1:size(2), y2:size(2), z:size(4)>> = <<
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

fn encode_4byte_utf(codepoint: Int) -> String {
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

  let assert <<b1:size(8), b2:size(8), b3:size(8), b4:size(8)>> = res
  "%"
  <> int.to_base16(b1)
  <> "%"
  <> int.to_base16(b2)
  <> "%"
  <> int.to_base16(b3)
  <> "%"
  <> int.to_base16(b4)
}
