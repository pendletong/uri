import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleam/uri.{type Uri}
import gluri/internal/parser
import gluri/internal/utils

/// Parses a string to the RFC3986 standard.
/// `Error` is returned if it fails parsing.
///
/// ## Examples
///
/// ```gleam
/// parse("https://me@host.com:9999/path?q=1#fragment")
/// // -> Ok(
/// //   Uri(
/// //     scheme: Some("https"),
/// //     userinfo: Some("me"),
/// //     host: Some("host.com"),
/// //     port: Some(9999),
/// //     path: "/path",
/// //     query: Some("q=1"),
/// //     fragment: Some("fragment")
/// //   )
/// // )
/// ```
///
pub fn parse(uri: String) -> Result(Uri, Nil) {
  parser.parse(uri)
}

/// Encodes a `Uri` value as a URI string.
///
///
/// ## Examples
///
/// ```gleam
/// let uri = Uri(
///      scheme: Some("https"),
///      userinfo: Some("me"),
///      host: Some("host.com"),
///      port: Some(9999),
///      path: "/path",
///      query: Some("q=1"),
///      fragment: Some("fragment")
///    )
/// to_string(uri)
/// // -> "https://me@host.com:9999/path?q=1#fragment"
/// ```
///
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

/// Resolves a URI with respect to the given base URI.
///
/// The base URI must be an absolute URI or this function will return an error.
/// The algorithm for merging uris is as described in
/// [RFC 3986](https://tools.ietf.org/html/rfc3986#section-5.2).
///
pub fn merge(base: Uri, relative: Uri) -> Result(Uri, Nil) {
  utils.merge(base, relative)
}

/// Normalises the `Uri`
///
/// This follows the normalisation process in RFC3986
/// - Case normalisation (scheme/host -> lowercase, percent-encoding -> uppercase)
/// - Percent-encoding normalisation (removal of non-necessary encoding)
/// - Path segement normalisation (processing of /, .. and .)
/// - Scheme based normalisation (removal of default ports for http/https/ftp/ws/wss, setting empty path to / for valid http(s) uri)
///
/// ## Examples
///
/// ```gleam
/// let uri = Uri(
///      scheme: Some("Https"),
///      userinfo: None,
///      host: Some("host.com"),
///      port: Some(443),
///      path: "",
///      query: Some("q=1"),
///      fragment: Some("fragment")
///    )
/// normalise(uri)
/// // -> "https://host.com/?q=1#fragment"
/// ```
///
pub fn normalise(uri: Uri) -> Uri {
  utils.normalise(uri)
}

/// Determines whether 2 Uris are equivalent, i.e. denote the same endpoint
///
/// This will perform normalisation if the Uris are not exactly the same
///
/// ## Examples
///
/// ```gleam
/// let uri = parse("Https://host.com:443?q=1#fragment")
/// let uri2 = parse("https://HOST.com/?q=1#fragment")
/// are_equivalent(uri, uri2)
/// // -> True
/// ```
///
pub fn are_equivalent(uri1: Uri, uri2: Uri) -> Bool {
  use <- bool.guard(when: uri1 == uri2, return: True)

  let uri1 = normalise(uri1)
  let uri2 = normalise(uri2)

  uri1 == uri2
}

/// Decodes a percent encoded string.
///
/// Will return an `Error` if the encoding is not valid
///
/// ## Examples
///
/// ```gleam
/// percent_decode("This%20is%20worth%20%E2%82%AC1+")
/// // -> Ok("This is worth €1+")
/// ```
///
pub fn percent_decode(value: String) -> Result(String, Nil) {
  utils.percent_decode(value)
}

/// Encodes a string into a percent encoded string.
///
/// ## Examples
///
/// ```gleam
/// percent_encode("This is worth €1+")
/// // -> "This%20is%20worth%20%E2%82%AC1+"
/// ```
///
pub fn percent_encode(value: String) -> String {
  utils.do_percent_encode(value)
}

/// Encodes a list of key/value pairs into a URI query string
///
/// Empty keys/values are encoded so would need to be filtered before
/// passing into this function if required
///
/// ## Examples
///
/// ```gleam
/// query_to_string([#("first", "1"), #("", ""), #("last", "2")])
/// // -> "first=1&=&last=2"
/// ```
///
pub fn query_to_string(query: List(#(String, String))) -> String {
  list.map(query, fn(q) {
    [utils.do_percent_encode(q.0), "=", utils.do_percent_encode(q.1)]
  })
  |> list.intersperse(["&"])
  |> list.flatten
  |> string.concat
}

/// Takes a query string and returns a list of key/value pairs
///
/// As this decodes the keys & values an `Error` may be returned if the
/// encoding is invalid
///
/// As in query_to_string entries with blank key and values are returned
/// Empty entries (i.e. without a = separator) are omitted as they cannot
/// be generated using query_to_string
///
/// ## Examples
///
/// ```gleam
/// parse_query("first=1&=&last=2")
/// // -> Ok([#("first", "1"), #("", ""), #("last", "2")])
/// ```
///
pub fn parse_query(query: String) -> Result(List(#(String, String)), Nil) {
  parser.parse_query_parts(query)
}

/// Returns the origin of the passed URI.
///
/// Returns the origin of a uri based on
/// [RFC 6454](https://tools.ietf.org/html/rfc6454)
///
/// If the URI scheme is not `http` and `https`.
/// `Error` will be returned.
///
/// ## Examples
///
/// ```gleam
/// let assert Ok(uri) = parse("https://blah.com/test?this#that")
/// origin(uri)
/// // -> Ok("https://blah.com")
/// ```
///
pub fn origin(uri: Uri) -> Result(String, Nil) {
  case
    uri.scheme |> option.map(string.lowercase),
    uri.host |> option.map(string.lowercase),
    utils.scheme_normalisation(uri.port, uri.scheme)
  {
    Some("http" as scheme), Some(host), port
    | Some("https" as scheme), Some(host), port
    -> {
      let port =
        port
        |> option.map(fn(p) { ":" <> int.to_string(p) })
        |> option.unwrap("")
      Ok(scheme <> "://" <> host <> port)
    }
    _, _, _ -> Error(Nil)
  }
}
