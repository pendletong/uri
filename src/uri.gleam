import gleam/bool
import gleam/int
import gleam/option.{None, Some}
import gleam/uri
import internal/parser
import internal/utils
import types.{type Uri, Uri}

pub fn parse(uri: String) -> Result(Uri, Nil) {
  parser.parse(uri)
}

pub fn to_string(uri: Uri) -> String {
  let uri_string = case uri.scheme {
    Some(scheme) -> scheme <> ":"
    _ -> ""
  }
  let uri_string = case uri.host {
    Some(_) -> {
      uri_string
      <> "//"
      <> case uri.userinfo {
        Some(userinfo) -> userinfo <> "@"
        _ -> ""
      }
      <> case uri.host {
        Some(host) -> host
        _ -> ""
      }
      <> case uri.port {
        Some(port) -> ":" <> int.to_string(port)
        _ -> ""
      }
    }
    _ -> uri_string
  }
  let uri_string = uri_string <> uri.path
  let uri_string =
    uri_string
    <> case uri.query {
      Some(query) -> "?" <> query
      _ -> ""
    }
  let uri_string =
    uri_string
    <> case uri.fragment {
      Some(fragment) -> "#" <> fragment
      _ -> ""
    }
  uri_string
}

pub fn merge(base: Uri, relative: Uri) -> Result(Uri, Nil) {
  utils.merge(base, relative)
}

pub fn normalize(uri: Uri) -> Uri {
  normalise(uri)
}

pub fn normalise(uri: Uri) -> Uri {
  utils.normalise(uri)
}

pub fn are_equivalent(uri1: Uri, uri2: Uri) {
  use <- bool.guard(when: uri1 == uri2, return: True)

  let uri1 = normalise(uri1)
  let uri2 = normalise(uri2)

  uri1 == uri2
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

pub fn percent_decode(value: String) -> Result(String, Nil) {
  utils.percent_decode(value)
}

pub fn percent_encode(value: String) -> String {
  utils.do_percent_encode(value)
}

pub fn query_to_string(query: List(#(String, String))) -> String {
  todo
}

pub fn parse_query(query: String) -> Result(List(#(String, String)), Nil) {
  todo
}

pub fn origin(uri: Uri) -> Result(String, Nil) {
  todo
}
