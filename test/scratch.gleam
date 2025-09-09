// import gleam/result

// import gleam/uri as uri2
// import splitter
// import types.{Uri}

import gluri as uri

pub fn main() {
  uri.parse("http://my_host.com") |> echo
  Nil
}
