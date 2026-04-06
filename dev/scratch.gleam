// import gleam/result

import gleam/uri as uri2

// import splitter
// import types.{Uri}

import gluri as uri

pub fn main() {
  // uri.parse("https://192.255.36.4/") |> echo
  // uri.parse(
  //   "https://github.com/gleam-lang/stdlib/issues/523#issuecomment-3288230480",
  // )
  // |> echo
  // let _ = uri.parse("/abc/def") |> echo
  // let _ = uri2.parse("/abc/def") |> echo
  // let _ = uri.parse("/abc/") |> echo

  // let _ = uri.parse("//[2600:1406:bc00:53::b81e:94c8]") |> echo
  // let _ = uri.parse("//[::2600:1406:0000:bc00:53:b81e:94c8]/") |> echo
  // let _ = uri.parse("//[::2600]/") |> echo
  // let _ = uri.parse("//[::]/") |> echo
  // let _ = uri.parse("//[::1%2]/") |> echo
  // let _ = uri2.parse("//[::1%2]/") |> echo
  // let _ = uri.parse("//[::127.0.0.1]/") |> echo
  // let _ = uri2.parse("//[0:1:2:3:4:5:6::]/") |> echo
  // let assert Error(Nil) =
  //   uri.parse("//[2600:1406:bc00:53::b81e:94c8:1111:2222]") |> echo
  let assert Ok(_) =
    uri.parse_query("el%E2%82%AC1=12%CE%A33&el%F0%90%80%852=321") |> echo
  uri.query_to_string([#("weebl bob", "1+1-1*1.1~1!1'1(1);%")]) |> echo
  uri2.query_to_string([#("weebl bob", "1+1-1*1.1~1!1'1(1);%")]) |> echo
  Nil
}
