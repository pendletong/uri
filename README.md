
# uri

Uri (RFC 3986) library for Gleam

[![Package Version](https://img.shields.io/hexpm/v/gluri)](https://hex.pm/packages/gluri)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gluri/)

```sh
gleam add uri@1
```
```gleam
import uri

pub fn main() {
  let uri = uri.parse("http://example.com:8080/path?q=1")
      |> result.unwrap(types.empty_uri)
  uri.normalise(uri) |> uri.to_string |> echo
}
```

Further documentation can be found at <https://hexdocs.pm/uri>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
