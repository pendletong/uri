import gleam/bool
import gleam/int
import gleam/option.{None, Some}
import gleam/string
import gleam/uri
import internal/parser
import splitter.{type Splitter}
import types.{type Uri, Uri}

pub fn parse(uri: String) -> Result(Uri, Nil) {
  parser.parse(uri)
}

pub fn to_string(uri: Uri) -> String {
  let parts = case uri.fragment {
    Some(fragment) -> ["#", fragment]
    None -> []
  }
  let parts = case uri.query {
    Some(query) -> ["?", query, ..parts]
    None -> parts
  }
  let parts = [uri.path, ..parts]
  let parts = case uri.host, string.starts_with(uri.path, "/") {
    Some(host), False if host != "" -> ["/", ..parts]
    _, _ -> parts
  }
  let parts = case uri.host, uri.port {
    Some(_), Some(port) -> [":", int.to_string(port), ..parts]
    _, _ -> parts
  }
  let parts = case uri.scheme, uri.userinfo, uri.host {
    Some(s), Some(u), Some(h) -> [s, "://", u, "@", h, ..parts]
    Some(s), None, Some(h) -> [s, "://", h, ..parts]
    Some(s), Some(_), None | Some(s), None, None -> [s, ":", ..parts]
    None, None, Some(h) -> ["//", h, ..parts]
    _, _, _ -> parts
  }
  string.concat(parts)
}

pub fn normalize(uri: Uri) -> Uri {
  normalise(uri)
}

pub fn normalise(uri: Uri) -> Uri {
  let percent_splitter = splitter.new(["%"])
  let percent_normaliser = normalise_percent(percent_splitter, _)
  let scheme = uri.scheme |> option.map(string.lowercase)
  let userinfo = uri.userinfo |> option.map(percent_normaliser)
  let port = uri.port
  let host =
    uri.host |> option.map(string.lowercase) |> option.map(percent_normaliser)
  let path = uri.path |> percent_normaliser |> normalise_path
  let query = uri.query |> option.map(percent_normaliser)
  let fragment = uri.fragment |> option.map(percent_normaliser)

  Uri(scheme, userinfo, host, port, path, query, fragment)
}

fn normalise_path(path: String) -> String {
  do_normalise_path(path, "")
}

fn do_normalise_path(path: String, acc: String) -> String {
  case path {
    "../" <> rest | "./" <> rest -> do_normalise_path(rest, acc)
    "/./" <> rest -> do_normalise_path("/" <> rest, acc)
    "/." -> do_normalise_path("/", acc)
    "/../" <> rest -> do_normalise_path("/" <> rest, remove_segment(acc))
    "/.." -> do_normalise_path("/", remove_segment(acc))
    "." | ".." | "" -> acc
    _ -> {
      let assert Ok(#(char, rest)) = string.pop_grapheme(path)
      do_normalise_path(rest, acc <> char)
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
          let #(pc_val, rest) = case parser.parse_hex_digit(after) {
            Ok(#(pc1, rest)) -> {
              case parser.parse_hex_digit(rest) {
                Ok(#(pc2, rest)) -> {
                  let hex = pc1 <> pc2
                  let v = unescape_percent(hex)
                  case v == hex {
                    True -> #("%" <> string.uppercase(v), rest)
                    False -> #(v, rest)
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
      case ascii {
        45
        | 46
        | 95
        | 126
        | 48
        | 49
        | 50
        | 51
        | 52
        | 53
        | 54
        | 55
        | 56
        | 57
        | 65
        | 66
        | 67
        | 68
        | 69
        | 70
        | 71
        | 72
        | 73
        | 74
        | 75
        | 76
        | 77
        | 78
        | 79
        | 80
        | 81
        | 82
        | 83
        | 84
        | 85
        | 86
        | 87
        | 88
        | 89
        | 90
        | 97
        | 98
        | 99
        | 100
        | 101
        | 102
        | 103
        | 104
        | 105
        | 106
        | 107
        | 108
        | 109
        | 110
        | 111
        | 112
        | 113
        | 114
        | 115
        | 116
        | 117
        | 118
        | 119
        | 120
        | 121
        | 122 -> {
          let assert Ok(cpnt) = string.utf_codepoint(ascii)
          string.from_utf_codepoints([cpnt])
        }
        _ -> str
      }
    }
  }
}

pub fn are_equivalent(uri1: Uri, uri2: Uri) {
  use <- bool.guard(when: uri1 == uri2, return: True)

  let uri1 = normalise(uri1)
  let uri2 = normalise(uri2)

  use <- bool.guard(when: uri1 == uri2, return: True)

  False
}

pub fn to_uri(uri: Uri) -> uri.Uri {
  uri.Uri(
    uri.scheme,
    uri.userinfo,
    uri.host,
    uri.port,
    uri.path,
    uri.query,
    uri.fragment,
  )
}

pub fn from_uri(uri: uri.Uri) -> Uri {
  Uri(
    uri.scheme,
    uri.userinfo,
    uri.host,
    uri.port,
    uri.path,
    uri.query,
    uri.fragment,
  )
}
