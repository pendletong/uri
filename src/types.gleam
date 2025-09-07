import gleam/option.{type Option, None}

pub type Uri {
  Uri(
    scheme: Option(String),
    userinfo: Option(String),
    host: Option(String),
    port: Option(Int),
    path: String,
    query: Option(String),
    fragment: Option(String),
  )
}

pub const empty_uri = Uri(None, None, None, None, "", None, None)
