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
  let _ = uri.parse("/abc/def") |> echo
  let _ = uri2.parse("/abc/def") |> echo
  let _ = uri.parse("/abc/") |> echo
  Nil
}
