import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import startest.{describe, it}
import types.{Uri, empty_uri}
import uri

pub fn main() {
  startest.run(startest.default_config())
}

pub fn parse_scheme_tests() {
  describe("scheme parsing", [
    it("simple parse", fn() {
      uri.parse("") |> should.equal(Ok(types.empty_uri))
      uri.parse("foo")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "foo")))
      uri.parse("foo:")
      |> should.equal(Ok(Uri(..types.empty_uri, scheme: Some("foo"))))
      uri.parse("foo:bar:nisse")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), path: "bar:nisse"),
      ))
      uri.parse("foo://")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), host: Some("")),
      ))
      uri.parse("foo:///")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), host: Some(""), path: "/"),
      ))
      uri.parse("foo:////")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), host: Some(""), path: "//"),
      ))
    }),
  ])
}

pub fn parse_userinfo_tests() {
  describe("userinfo parsing", [
    it("simple parse", fn() {
      uri.parse("user:password@localhost")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("user"), path: "password@localhost"),
      ))
      uri.parse("user@")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "user@")))
      uri.parse("/user@")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "/user@")))
      uri.parse("user@localhost")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "user@localhost")))
      uri.parse("//user@localhost")
      |> should.equal(Ok(
        Uri(..types.empty_uri, userinfo: Some("user"), host: Some("localhost")),
      ))
      uri.parse("//user:password@localhost")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          userinfo: Some("user:password"),
          host: Some("localhost"),
        ),
      ))
      uri.parse("foo:/user@")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), path: "/user@"),
      ))
      uri.parse("foo://user@localhost")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          userinfo: Some("user"),
          host: Some("localhost"),
        ),
      ))
      uri.parse("foo://user:password@localhost")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          userinfo: Some("user:password"),
          host: Some("localhost"),
        ),
      ))
    }),
    it("percent encoding", fn() {
      uri.parse("user:%E5%90%88@%E6%B0%97%E9%81%93")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("user"),
          path: "%E5%90%88@%E6%B0%97%E9%81%93",
        ),
      ))
      uri.parse("%E5%90%88%E6%B0%97%E9%81%93@")
      |> should.equal(Ok(
        Uri(..types.empty_uri, path: "%E5%90%88%E6%B0%97%E9%81%93@"),
      ))
      uri.parse("/%E5%90%88%E6%B0%97%E9%81%93@")
      |> should.equal(Ok(
        Uri(..types.empty_uri, path: "/%E5%90%88%E6%B0%97%E9%81%93@"),
      ))
      uri.parse("%E5%90%88@%E6%B0%97%E9%81%93")
      |> should.equal(Ok(
        Uri(..types.empty_uri, path: "%E5%90%88@%E6%B0%97%E9%81%93"),
      ))
      uri.parse("//%E5%90%88@%E6%B0%97%E9%81%93")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("%E6%B0%97%E9%81%93"),
          userinfo: Some("%E5%90%88"),
        ),
      ))
      uri.parse("//%E5%90%88:%E6%B0%97@%E9%81%93")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("%E9%81%93"),
          userinfo: Some("%E5%90%88:%E6%B0%97"),
        ),
      ))
      uri.parse("foo:/%E5%90%88%E6%B0%97%E9%81%93@")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          path: "/%E5%90%88%E6%B0%97%E9%81%93@",
        ),
      ))
      uri.parse("foo://%E5%90%88@%E6%B0%97%E9%81%93")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          userinfo: Some("%E5%90%88"),
          host: Some("%E6%B0%97%E9%81%93"),
        ),
      ))
      uri.parse("foo://%E5%90%88:%E6%B0%97@%E9%81%93")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          userinfo: Some("%E5%90%88:%E6%B0%97"),
          host: Some("%E9%81%93"),
        ),
      ))
      uri.parse("//%E5%90%88@%E6%B0%97%E9%81%93@") |> should.be_error
      uri.parse("foo://%E5%90%88@%E6%B0%97%E9%81%93@") |> should.be_error
    }),
  ])
}

pub fn parse_host_tests() {
  describe("host parsing", [
    it("simple parse", fn() {
      uri.parse("//hostname")
      |> should.equal(Ok(Uri(..types.empty_uri, host: Some("hostname"))))
      uri.parse("foo://hostname")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), host: Some("hostname")),
      ))
      uri.parse("foo://user@hostname")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          userinfo: Some("user"),
          host: Some("hostname"),
        ),
      ))
    }),
    it("ipv4 parse", fn() {
      uri.parse("//127.0.0.1")
      |> should.equal(Ok(Uri(..types.empty_uri, host: Some("127.0.0.1"))))
      uri.parse("//127.0.0.1/over/there")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some("127.0.0.1"), path: "/over/there"),
      ))
      uri.parse("//127.0.0.1?name=ferret")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("127.0.0.1"),
          query: Some("name=ferret"),
        ),
      ))
      uri.parse("//127.0.0.1#nose")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some("127.0.0.1"), fragment: Some("nose")),
      ))

      uri.parse("//127.0.0.x")
      |> should.equal(Ok(Uri(..types.empty_uri, host: Some("127.0.0.x"))))
      uri.parse("//1227.0.0.1")
      |> should.equal(Ok(Uri(..types.empty_uri, host: Some("1227.0.0.1"))))
    }),
    it("ipv6 parse", fn() {
      uri.parse("//[::127.0.0.1]")
      |> should.equal(Ok(Uri(..types.empty_uri, host: Some("::127.0.0.1"))))
      uri.parse("//[2001:0db8:0000:0000:0000:0000:1428:07ab]")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("2001:0db8:0000:0000:0000:0000:1428:07ab"),
        ),
      ))
      uri.parse("//[::127.0.0.1]/over/there")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some("::127.0.0.1"), path: "/over/there"),
      ))
      uri.parse("//[::127.0.0.1]?name=ferret")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("::127.0.0.1"),
          query: Some("name=ferret"),
        ),
      ))
      uri.parse("//[::127.0.0.1]#nose")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("::127.0.0.1"),
          fragment: Some("nose"),
        ),
      ))

      uri.parse("//[::127.0.0.x]") |> should.be_error
      uri.parse("//[::1227.0.0.1]") |> should.be_error
      uri.parse("//[2001:0db8:0000:0000:0000:0000:1428:G7ab]")
      |> should.be_error
    }),
  ])
}

pub fn parse_port_tests() {
  describe("port parsing", [
    it("simple parse", fn() {
      uri.parse("/:8042")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "/:8042")))
      uri.parse("//:8042")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some(""), port: Some(8042)),
      ))
      uri.parse("//example.com:8042")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some("example.com"), port: Some(8042)),
      ))
      uri.parse("foo:/:8042")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), path: "/:8042"),
      ))
      uri.parse("foo://:8042")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some(""),
          port: Some(8042),
        ),
      ))
      uri.parse("foo://example.com:8042")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some("example.com"),
          port: Some(8042),
        ),
      ))
      uri.parse(":8042") |> should.be_error
      uri.parse("//:8042x") |> should.be_error
    }),
    it("undefined port", fn() {
      uri.parse("/:")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "/:")))
      uri.parse("//:")
      |> should.equal(Ok(Uri(..types.empty_uri, host: Some(""), port: None)))
      uri.parse("//example.com:")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some("example.com"), port: None),
      ))
      uri.parse("foo:/:")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), path: "/:"),
      ))
      uri.parse("foo://:")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), host: Some(""), port: None),
      ))
      uri.parse("foo://example.com:")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some("example.com"),
          port: None,
        ),
      ))
      uri.parse(":") |> should.be_error
      uri.parse("//:x") |> should.be_error
    }),
  ])
}

pub fn parse_path_tests() {
  describe("path parsing", [
    it("simple parse", fn() {
      uri.parse("over/there")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "over/there")))
      uri.parse("/over/there")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "/over/there")))
      uri.parse("foo:/over/there")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), path: "/over/there"),
      ))
      uri.parse("foo://example.com/over/there")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some("example.com"),
          path: "/over/there",
        ),
      ))
      uri.parse("foo://example.com:8042/over/there")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some("example.com"),
          port: Some(8042),
          path: "/over/there",
        ),
      ))
    }),
  ])
}

pub fn parse_query_part_tests() {
  describe("query parsing", [
    it("simple parse", fn() {
      uri.parse("foo:?name=ferret")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), query: Some("name=ferret")),
      ))
      uri.parse("foo:over/there?name=ferret")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          path: "over/there",
          query: Some("name=ferret"),
        ),
      ))
      uri.parse("foo:/over/there?name=ferret")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          path: "/over/there",
          query: Some("name=ferret"),
        ),
      ))
      uri.parse("foo://example.com?name=ferret")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some("example.com"),
          query: Some("name=ferret"),
        ),
      ))
      uri.parse("foo://example.com/?name=ferret")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some("example.com"),
          path: "/",
          query: Some("name=ferret"),
        ),
      ))

      uri.parse("?name=ferret")
      |> should.equal(Ok(
        Uri(..types.empty_uri, path: "", query: Some("name=ferret")),
      ))
      uri.parse("over/there?name=ferret")
      |> should.equal(Ok(
        Uri(..types.empty_uri, path: "over/there", query: Some("name=ferret")),
      ))
      uri.parse("/?name=ferret")
      |> should.equal(Ok(
        Uri(..types.empty_uri, path: "/", query: Some("name=ferret")),
      ))
      uri.parse("/over/there?name=ferret")
      |> should.equal(Ok(
        Uri(..types.empty_uri, path: "/over/there", query: Some("name=ferret")),
      ))
      uri.parse("//example.com?name=ferret")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("example.com"),
          query: Some("name=ferret"),
        ),
      ))
      uri.parse("//example.com/?name=ferret")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("example.com"),
          path: "/",
          query: Some("name=ferret"),
        ),
      ))
    }),
    it("percent encoding", fn() {
      uri.parse("foo://example.com/?name=%E5%90%88%E6%B0%97%E9%81%93")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some("example.com"),
          path: "/",
          query: Some("name=%E5%90%88%E6%B0%97%E9%81%93"),
        ),
      ))
      uri.parse("//example.com/?name=%E5%90%88%E6%B0%97%E9%81%93")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("example.com"),
          path: "/",
          query: Some("name=%E5%90%88%E6%B0%97%E9%81%93"),
        ),
      ))
    }),
  ])
}

pub fn parse_fragment_tests() {
  describe("fragment parsing", [
    it("simple parse", fn() {
      uri.parse("foo:#nose")
      |> should.equal(Ok(
        Uri(..types.empty_uri, scheme: Some("foo"), fragment: Some("nose")),
      ))
      uri.parse("foo:over/there#nose")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          path: "over/there",
          fragment: Some("nose"),
        ),
      ))
      uri.parse("foo:/over/there#nose")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          path: "/over/there",
          fragment: Some("nose"),
        ),
      ))
      uri.parse("foo://example.com#nose")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some("example.com"),
          fragment: Some("nose"),
        ),
      ))
      uri.parse("foo://example.com/#nose")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some("example.com"),
          path: "/",
          fragment: Some("nose"),
        ),
      ))
      uri.parse("foo://example.com#nose")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some("example.com"),
          fragment: Some("nose"),
        ),
      ))

      uri.parse("#nose")
      |> should.equal(Ok(Uri(..types.empty_uri, fragment: Some("nose"))))
      uri.parse("over/there#nose")
      |> should.equal(Ok(
        Uri(..types.empty_uri, path: "over/there", fragment: Some("nose")),
      ))
      uri.parse("/#nose")
      |> should.equal(Ok(
        Uri(..types.empty_uri, path: "/", fragment: Some("nose")),
      ))
      uri.parse("/over/there#nose")
      |> should.equal(Ok(
        Uri(..types.empty_uri, path: "/over/there", fragment: Some("nose")),
      ))
      uri.parse("//example.com#nose")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("example.com"),
          fragment: Some("nose"),
        ),
      ))
      uri.parse("//example.com/#nose")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("example.com"),
          path: "/",
          fragment: Some("nose"),
        ),
      ))
    }),
    it("percent encoding", fn() {
      uri.parse("foo://example.com#%E5%90%88%E6%B0%97%E9%81%93")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some("example.com"),
          fragment: Some("%E5%90%88%E6%B0%97%E9%81%93"),
        ),
      ))
      uri.parse("//example.com/#%E5%90%88%E6%B0%97%E9%81%93")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("example.com"),
          path: "/",
          fragment: Some("%E5%90%88%E6%B0%97%E9%81%93"),
        ),
      ))
    }),
  ])
}

pub fn parse_special_tests() {
  describe("special parsing", [
    it("special 1", fn() {
      uri.parse("//?")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some(""), query: Some("")),
      ))
      uri.parse("//#")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some(""), fragment: Some("")),
      ))
      uri.parse("//?#")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some(""),
          query: Some(""),
          fragment: Some(""),
        ),
      ))
      uri.parse("foo://?")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some(""),
          query: Some(""),
        ),
      ))
      uri.parse("foo://#")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some(""),
          fragment: Some(""),
        ),
      ))
      uri.parse("foo://?#")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some(""),
          query: Some(""),
          fragment: Some(""),
        ),
      ))
      uri.parse("///")
      |> should.equal(Ok(Uri(..types.empty_uri, host: Some(""), path: "/")))
      uri.parse("///hostname")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some(""), path: "/hostname"),
      ))
      uri.parse("///?")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some(""), path: "/", query: Some("")),
      ))
      uri.parse("///#")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some(""), path: "/", fragment: Some("")),
      ))
      uri.parse("///?#")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some(""),
          path: "/",
          query: Some(""),
          fragment: Some(""),
        ),
      ))
      uri.parse("//foo?")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some("foo"), query: Some("")),
      ))
      uri.parse("//foo#")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some("foo"), fragment: Some("")),
      ))
      uri.parse("//foo?#")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          host: Some("foo"),
          query: Some(""),
          fragment: Some(""),
        ),
      ))
      uri.parse("//foo/")
      |> should.equal(Ok(Uri(..types.empty_uri, host: Some("foo"), path: "/")))
      uri.parse("http://foo?")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("http"),
          host: Some("foo"),
          query: Some(""),
        ),
      ))
      uri.parse("http://foo#")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("http"),
          host: Some("foo"),
          fragment: Some(""),
        ),
      ))
      uri.parse("http://foo?#")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("http"),
          host: Some("foo"),
          query: Some(""),
          fragment: Some(""),
        ),
      ))
      uri.parse("http://foo/")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("http"),
          host: Some("foo"),
          path: "/",
        ),
      ))
      uri.parse("http://foo:80?")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("http"),
          host: Some("foo"),
          port: Some(80),
          query: Some(""),
        ),
      ))
      uri.parse("http://foo:80#")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("http"),
          host: Some("foo"),
          port: Some(80),
          fragment: Some(""),
        ),
      ))
      uri.parse("http://foo:80?#")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("http"),
          host: Some("foo"),
          port: Some(80),
          query: Some(""),
          fragment: Some(""),
        ),
      ))
      uri.parse("http://foo:80/")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("http"),
          host: Some("foo"),
          port: Some(80),
          path: "/",
        ),
      ))
      uri.parse("?")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "", query: Some(""))))
      uri.parse("??")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "", query: Some("?"))))
      uri.parse("???")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "", query: Some("??"))))
      uri.parse("#")
      |> should.equal(Ok(Uri(..types.empty_uri, path: "", fragment: Some(""))))
      uri.parse("##")
      |> should.be_error
      uri.parse("###")
      |> should.be_error
    }),
    it("special 2", fn() {
      uri.parse("a://:1/")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("a"),
          host: Some(""),
          port: Some(1),
          path: "/",
        ),
      ))
      uri.parse("a:/a/")
      |> should.equal(Ok(Uri(..types.empty_uri, scheme: Some("a"), path: "/a/")))
      uri.parse("//@")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some(""), path: "", userinfo: Some("")),
      ))
      uri.parse("foo://@")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some(""),
          path: "",
          userinfo: Some(""),
        ),
      ))
      uri.parse("//@/")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some(""), path: "/", userinfo: Some("")),
      ))
      uri.parse("foo://@/")
      |> should.equal(Ok(
        Uri(
          ..types.empty_uri,
          scheme: Some("foo"),
          host: Some(""),
          path: "/",
          userinfo: Some(""),
        ),
      ))
      uri.parse("//localhost:/")
      |> should.equal(Ok(
        Uri(..types.empty_uri, host: Some("localhost"), path: "/"),
      ))
      uri.parse("//:")
      |> should.equal(Ok(Uri(..types.empty_uri, host: Some(""), path: "")))
    }),
  ])
}

pub fn parse_failure_tests() {
  describe("fail parsing", [
    it("failure", fn() {
      uri.parse("å") |> should.be_error
      uri.parse("aå:/foo") |> should.be_error
      uri.parse("foo://usär@host") |> should.be_error
      uri.parse("//host/path?foö=bar") |> should.be_error
      uri.parse("//host/path#foö") |> should.be_error
      uri.parse("//[:::127.0.0.1]") |> should.be_error
      uri.parse("//localhost:A8") |> should.be_error
      uri.parse("http://f%ff%%ff/") |> should.be_error
      uri.parse("http://f%ff%fr/") |> should.be_error
    }),
  ])
}

pub fn merge_tests() {
  describe("merging", [
    it("relative merge", fn() {
      let uri1 = uri.parse("/relative") |> should.be_ok
      let uri2 = uri.parse("") |> should.be_ok
      uri.merge(uri1, uri2) |> should.be_error
    }),
    it("simple merge", fn() {
      let uri1 = uri.parse("http://google.com/weebl") |> should.be_ok
      let uri2 = uri.parse("http://example.com/baz") |> should.be_ok
      uri.merge(uri1, uri2) |> should.equal(uri.parse("http://example.com/baz"))
    }),
    it("segments merge", fn() {
      let uri1 = uri.parse("http://google.com/weebl") |> should.be_ok
      let uri2 =
        uri.parse("http://example.com/.././bob/../../baz") |> should.be_ok
      uri.merge(uri1, uri2) |> should.equal(uri.parse("http://example.com/baz"))
    }),
    it("base with authority merge", fn() {
      let uri1 = uri.parse("http://google.com/weebl") |> should.be_ok
      let uri2 = uri.parse("//example.com/baz") |> should.be_ok
      uri.merge(uri1, uri2) |> should.equal(uri.parse("http://example.com/baz"))
    }),
    it("base with authority segments merge", fn() {
      let uri1 = uri.parse("http://google.com/weebl") |> should.be_ok
      let uri2 =
        uri.parse("//example.com/.././bob/../../../baz") |> should.be_ok
      uri.merge(uri1, uri2) |> should.equal(uri.parse("http://example.com/baz"))
    }),
    it("base with absolute merge", fn() {
      let uri1 = uri.parse("http://google.com/weebl/eh") |> should.be_ok
      let uri2 = uri.parse("/baz") |> should.be_ok
      uri.merge(uri1, uri2) |> should.equal(uri.parse("http://google.com/baz"))
    }),
    it("base with relative merge", fn() {
      let uri1 = uri.parse("http://google.com/weebl/eh") |> should.be_ok
      let uri2 = uri.parse("baz") |> should.be_ok
      uri.merge(uri1, uri2)
      |> echo
      |> should.equal(uri.parse("http://google.com/weebl/baz"))
      let uri1 = uri.parse("http://google.com/weebl/") |> should.be_ok
      let uri2 = uri.parse("baz") |> should.be_ok
      uri.merge(uri1, uri2)
      |> echo
      |> should.equal(uri.parse("http://google.com/weebl/baz"))
      let uri1 = uri.parse("http://google.com") |> should.be_ok
      let uri2 = uri.parse("baz") |> should.be_ok
      uri.merge(uri1, uri2)
      |> echo
      |> should.equal(uri.parse("http://google.com/baz"))
    }),
    it("base with relative segments merge", fn() {
      let uri1 = uri.parse("http://google.com") |> should.be_ok
      let uri2 = uri.parse("/.././bob/../../../baz") |> should.be_ok
      uri.merge(uri1, uri2)
      |> echo
      |> should.equal(uri.parse("http://google.com/baz"))
    }),
    it("base with empty uri merge", fn() {
      let uri1 = uri.parse("http://google.com/weebl/bob") |> should.be_ok
      let uri2 = uri.parse("") |> should.be_ok
      uri.merge(uri1, uri2)
      |> echo
      |> should.equal(uri.parse("http://google.com/weebl/bob"))
    }),

    it("base with fragment merge", fn() {
      let uri1 = uri.parse("http://google.com/weebl/bob") |> should.be_ok
      let uri2 = uri.parse("#fragment") |> should.be_ok
      uri.merge(uri1, uri2)
      |> echo
      |> should.equal(uri.parse("http://google.com/weebl/bob#fragment"))
    }),
    it("base with query merge", fn() {
      let uri1 = uri.parse("http://google.com/weebl/bob") |> should.be_ok
      let uri2 = uri.parse("?query") |> should.be_ok
      uri.merge(uri1, uri2)
      |> echo
      |> should.equal(uri.parse("http://google.com/weebl/bob?query"))
      let uri1 = uri.parse("http://google.com/weebl/bob?query1") |> should.be_ok
      let uri2 = uri.parse("?query2") |> should.be_ok
      uri.merge(uri1, uri2)
      |> echo
      |> should.equal(uri.parse("http://google.com/weebl/bob?query2"))
      let uri1 = uri.parse("http://google.com/weebl/bob?query1") |> should.be_ok
      let uri2 = uri.parse("") |> should.be_ok
      uri.merge(uri1, uri2)
      |> echo
      |> should.equal(uri.parse("http://google.com/weebl/bob?query1"))
    }),
  ])
}

pub fn more_merge_tests() {
  describe("rfc merge tests", [
    it("normal examples", fn() {
      let base = uri.parse("http://a/b/c/d;p?q") |> should.be_ok

      let rel = uri.parse("g:h") |> should.be_ok
      uri.merge(base, rel) |> should.be_ok |> should.equal(rel)
      let rel = uri.parse("g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g") |> should.be_ok)
      let rel = uri.parse("./g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g") |> should.be_ok)
      let rel = uri.parse("g/") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g/") |> should.be_ok)
      let rel = uri.parse("/g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/g") |> should.be_ok)
      let rel = uri.parse("//g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://g") |> should.be_ok)
      let rel = uri.parse("?y") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/d;p?y") |> should.be_ok)
      let rel = uri.parse("g?y") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g?y") |> should.be_ok)
      let rel = uri.parse("#s") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/d;p?q#s") |> should.be_ok)
      let rel = uri.parse("g#s") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g#s") |> should.be_ok)
      let rel = uri.parse("g?y#s") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g?y#s") |> should.be_ok)
      let rel = uri.parse(";x") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/;x") |> should.be_ok)
      let rel = uri.parse("g;x") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g;x") |> should.be_ok)
      let rel = uri.parse("g;x?y#s") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g;x?y#s") |> should.be_ok)
      let rel = uri.parse("") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/d;p?q") |> should.be_ok)
      let rel = uri.parse(".") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/") |> should.be_ok)
      let rel = uri.parse("./") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/") |> should.be_ok)
      let rel = uri.parse("..") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/") |> should.be_ok)
      let rel = uri.parse("../") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/") |> should.be_ok)
      let rel = uri.parse("../g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/g") |> should.be_ok)
      let rel = uri.parse("../..") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/") |> should.be_ok)
      let rel = uri.parse("../../") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/") |> should.be_ok)
      let rel = uri.parse("../../g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/g") |> should.be_ok)
    }),
  ])
}

pub fn normalise_tests() {
  describe("normalise", [
    it("basic normalise", fn() {
      uri.parse("/a/b/c/./../../g")
      |> should.be_ok
      |> uri.normalise
      |> should.equal(Uri(..empty_uri, path: "/a/g"))
      uri.parse("mid/content=5/../6")
      |> should.be_ok
      |> uri.normalise
      |> should.equal(Uri(..empty_uri, path: "mid/6"))
    }),
    it("normalise ports", fn() {
      uri.parse("http://example.com:80/test")
      |> should.be_ok
      |> uri.normalise
      |> should.equal(
        Uri(
          ..empty_uri,
          scheme: Some("http"),
          host: Some("example.com"),
          path: "/test",
        ),
      )
      uri.parse("https://example.com:443/test")
      |> should.be_ok
      |> uri.normalise
      |> should.equal(
        Uri(
          ..empty_uri,
          scheme: Some("https"),
          host: Some("example.com"),
          path: "/test",
        ),
      )
      uri.parse("http://example.com:8080/test")
      |> should.be_ok
      |> uri.normalise
      |> should.equal(
        Uri(
          ..empty_uri,
          scheme: Some("http"),
          host: Some("example.com"),
          port: Some(8080),
          path: "/test",
        ),
      )
      uri.parse("https://example.com:8043/test")
      |> should.be_ok
      |> uri.normalise
      |> should.equal(
        Uri(
          ..empty_uri,
          scheme: Some("https"),
          host: Some("example.com"),
          port: Some(8043),
          path: "/test",
        ),
      )
    }),
    it("abnormal examples", fn() {
      let base = uri.parse("http://a/b/c/d;p?q") |> should.be_ok

      let rel = uri.parse("../../../g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/g") |> should.be_ok)
      let rel = uri.parse("../../../../g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/g") |> should.be_ok)
      let rel = uri.parse("/./g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/g") |> should.be_ok)
      let rel = uri.parse("/../g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/g") |> should.be_ok)
      let rel = uri.parse("g.") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g.") |> should.be_ok)
      let rel = uri.parse(".g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/.g") |> should.be_ok)
      let rel = uri.parse("g..") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g..") |> should.be_ok)
      let rel = uri.parse("..g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/..g") |> should.be_ok)
    }),
    it("weird examples", fn() {
      let base = uri.parse("http://a/b/c/d;p?q") |> should.be_ok

      let rel = uri.parse("./../g") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/g") |> should.be_ok)
      let rel = uri.parse("./g/.") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g/") |> should.be_ok)
      let rel = uri.parse("g/./h") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g/h") |> should.be_ok)
      let rel = uri.parse("g/../h") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/h") |> should.be_ok)
      let rel = uri.parse("g;x=1/./y") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g;x=1/y") |> should.be_ok)
      let rel = uri.parse("g;x=1/../y") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/y") |> should.be_ok)
    }),

    it("weird fragment examples", fn() {
      let base = uri.parse("http://a/b/c/d;p?q") |> should.be_ok

      let rel = uri.parse("g?y/./x") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g?y/./x") |> should.be_ok)
      let rel = uri.parse("g?y/../x") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g?y/../x") |> should.be_ok)
      let rel = uri.parse("g#s/./x") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g#s/./x") |> should.be_ok)
      let rel = uri.parse("g#s/../x") |> should.be_ok
      uri.merge(base, rel)
      |> should.be_ok
      |> should.equal(uri.parse("http://a/b/c/g#s/../x") |> should.be_ok)
    }),
  ])
}

pub fn to_string_tests() {
  describe("to_string test", [
    it("simple test", fn() {
      let test_uri =
        types.Uri(
          Some("https"),
          Some("weebl:bob"),
          Some("example.com"),
          Some(1234),
          "/path",
          Some("query=true"),
          Some("fragment"),
        )
      uri.to_string(test_uri)
      |> should.equal(
        "https://weebl:bob@example.com:1234/path?query=true#fragment",
      )
    }),
    it("path only", fn() {
      types.Uri(..types.empty_uri, path: "/")
      |> uri.to_string
      |> should.equal("/")
      types.Uri(..types.empty_uri, path: "/blah")
      |> uri.to_string
      |> should.equal("/blah")
      types.Uri(..types.empty_uri, userinfo: Some("user"), path: "/blah")
      |> uri.to_string
      |> should.equal("/blah")
      types.Uri(..types.empty_uri, path: "")
      |> uri.to_string
      |> should.equal("")
    }),
  ])
}

pub fn equivalence_tests() {
  describe("equivalence tests", [
    it("equal", fn() {
      let uri1 = uri.parse("http://example.com") |> should.be_ok
      let uri2 = uri.parse("HTTP://EXAMPLE.COM") |> should.be_ok
      uri.are_equivalent(uri1, uri2) |> should.be_true

      let uri1 = uri.parse("http://example.com") |> should.be_ok
      let uri2 = uri.parse("HTTP://EX%41MPLE.COM") |> should.be_ok |> echo
      uri.are_equivalent(uri1, uri2) |> should.be_true

      let uri1 = uri.parse("http://example.com/a/b/c") |> should.be_ok
      let uri2 =
        uri.parse("HTTP://EXaMPLE.COM/a/d/../b/e/../c") |> should.be_ok |> echo
      uri.are_equivalent(uri1, uri2) |> should.be_true

      let uri1 = uri.parse("http://example.com/a/b/c") |> should.be_ok
      let uri2 =
        uri.parse("HTTP://EXaMPLE.COM/a/../../../../a/b/e/../c")
        |> should.be_ok
        |> echo
      uri.are_equivalent(uri1, uri2) |> should.be_true
    }),
  ])
}

const percent_codec_fixtures = [
  #(" ", "%20"),
  #(",", "%2C"),
  #(";", "%3B"),
  #(":", "%3A"),
  #("!", "!"),
  #("?", "%3F"),
  #("'", "'"),
  #("(", "("),
  #(")", ")"),
  #("[", "%5B"),
  #("@", "%40"),
  #("/", "%2F"),
  #("\\", "%5C"),
  #("&", "%26"),
  #("#", "%23"),
  #("=", "%3D"),
  #("~", "~"),
  #("ñ", "%C3%B1"),
  #("-", "-"),
  #("_", "_"),
  #(".", "."),
  #("*", "*"),
  #("+", "+"),
  #("100% great+fun", "100%25%20great+fun"),
]

pub fn percent_encode_tests() {
  describe("percent encoding", [
    it("encoding", fn() {
      percent_codec_fixtures
      |> list.map(fn(t) {
        let #(a, b) = t
        uri.percent_encode(a)
        |> should.equal(b)
      })
      Nil
    }),
    it("decoding", fn() {
      percent_codec_fixtures
      |> list.map(fn(t) {
        let #(a, b) = t
        uri.percent_decode(b)
        |> should.equal(Ok(a))
      })
      Nil
    }),
    it("fail decoding", fn() {
      uri.percent_decode("%C3test") |> should.be_error
      uri.percent_decode("%C3%01test") |> should.be_error
      uri.percent_decode("%E2%82%01test") |> should.be_error
      uri.percent_decode("%E2%01%ACtest") |> should.be_error
      uri.percent_decode("%F0%90%80%01test") |> should.be_error
      uri.percent_decode("%F0%90%01%85test") |> should.be_error
      uri.percent_decode("%F0%01%80%85test") |> should.be_error
    }),
  ])
}

pub fn parse_query_tests() {
  describe("parse_query", [
    it("basic parse", fn() {
      uri.parse_query("el1=123&el2=321")
      |> should.be_ok
      |> should.equal([#("el1", "123"), #("el2", "321")])
      uri.parse_query("el%201=123&el+2=321")
      |> should.be_ok
      |> should.equal([#("el 1", "123"), #("el 2", "321")])
      uri.parse_query("el%E2%82%AC1=12%CE%A33&el%F0%90%80%852=321")
      |> should.be_ok
      |> should.equal([#("el€1", "12Σ3"), #("el𐀅2", "321")])
    }),
    it("empty parts", fn() {
      uri.parse_query("el1=123&&el2=321")
      |> should.be_ok
      |> should.equal([#("el1", "123"), #("el2", "321")])
      uri.parse_query("el1=&el2=")
      |> should.be_ok
      |> should.equal([#("el1", ""), #("el2", "")])
      uri.parse_query("")
      |> should.be_ok
      |> should.equal([])
      uri.parse_query("=123&el2=321")
      |> should.be_ok
      |> should.equal([#("", "123"), #("el2", "321")])
      uri.parse_query("=&el2=321")
      |> should.be_ok
      |> should.equal([#("", ""), #("el2", "321")])
    }),
  ])
}

pub fn query_to_string_tests() {
  describe("query_to_string", [
    it("basic query", fn() {
      uri.query_to_string([#("el1", "123"), #("el2", "321")])
      |> should.equal("el1=123&el2=321")
      uri.query_to_string([#("el 1", "123"), #("el 2", "321")])
      |> should.equal("el%201=123&el%202=321")
      uri.query_to_string([#("el€1", "12Σ3"), #("el𐀅2", "321")])
      |> should.equal("el%E2%82%AC1=12%CE%A33&el%F0%90%80%852=321")
    }),
    it("empty parts", fn() {
      uri.query_to_string([#("el1", ""), #("el2", "")])
      |> should.equal("el1=&el2=")
      uri.query_to_string([])
      |> should.equal("")
      uri.query_to_string([#("", "123"), #("el2", "321")])
      |> should.equal("=123&el2=321")
      uri.query_to_string([#("", ""), #("el2", "321")])
      |> should.equal("=&el2=321")
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
