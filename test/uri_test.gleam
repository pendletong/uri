import gleam/option.{Some}
import gleeunit/should
import startest.{describe, it}
import uri.{Uri}

pub fn main() {
  startest.run(startest.default_config())
}

pub fn parse_scheme_tests() {
  describe("scheme parsing", [
    it("should parse", fn() {
      uri.parse("") |> should.equal(Ok(uri.empty_uri))
      uri.parse("foo")
      |> should.equal(Ok(Uri(..uri.empty_uri, path: "foo")))
      uri.parse("foo:")
      |> should.equal(Ok(Uri(..uri.empty_uri, scheme: Some("foo"))))
      uri.parse("foo:bar:nisse")
      |> should.equal(Ok(
        Uri(..uri.empty_uri, scheme: Some("foo"), path: "bar:nisse"),
      ))
      uri.parse("foo://")
      |> should.equal(Ok(
        Uri(..uri.empty_uri, scheme: Some("foo"), host: Some("")),
      ))
      uri.parse("foo:///")
      |> should.equal(Ok(
        Uri(..uri.empty_uri, scheme: Some("foo"), host: Some(""), path: "/"),
      ))
      uri.parse("foo:////")
      |> should.equal(Ok(
        Uri(..uri.empty_uri, scheme: Some("foo"), host: Some(""), path: "//"),
      ))
    }),
  ])
}

pub fn parse_userinfo_tests() {
  describe("userinfo parsing", [
    it("should parse", fn() {
      uri.parse("user:password@localhost")
      |> should.equal(Ok(
        Uri(..uri.empty_uri, scheme: Some("user"), path: "password@localhost"),
      ))
      uri.parse("user@")
      |> should.equal(Ok(Uri(..uri.empty_uri, path: "user@")))
      uri.parse("/user@")
      |> should.equal(Ok(Uri(..uri.empty_uri, path: "/user@")))
      uri.parse("user@localhost")
      |> should.equal(Ok(Uri(..uri.empty_uri, path: "user@localhost")))
      uri.parse("//user@localhost")
      |> should.equal(Ok(
        Uri(..uri.empty_uri, userinfo: Some("user"), host: Some("localhost")),
      ))
      uri.parse("//user:password@localhost")
      |> should.equal(Ok(
        Uri(
          ..uri.empty_uri,
          userinfo: Some("user:password"),
          host: Some("localhost"),
        ),
      ))
      uri.parse("foo:/user@")
      |> should.equal(Ok(
        Uri(..uri.empty_uri, scheme: Some("foo"), path: "/user@"),
      ))
      uri.parse("foo://user@localhost")
      |> should.equal(Ok(
        Uri(
          ..uri.empty_uri,
          scheme: Some("foo"),
          userinfo: Some("user"),
          host: Some("localhost"),
        ),
      ))
      uri.parse("foo://user:password@localhost")
      |> should.equal(Ok(
        Uri(
          ..uri.empty_uri,
          scheme: Some("foo"),
          userinfo: Some("user:password"),
          host: Some("localhost"),
        ),
      ))
    }),
  ])
}
// gleeunit test functions end in `_test`
// pub fn uri_test() {
//   match("uri:")
//   match("//@")
//   match("//")
//   match("")
//   match("?")
//   match("#")
//   match("#\t")
//   match("//:")
// }

// fn match(uri: String) {
//   assert uri.parse(uri)  |> uri.to_uri
//     == uri2.parse(uri)
// }
