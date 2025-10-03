import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri, Uri, empty}
import gluri/internal/utils.{
  combine_uris, parse_hex_digit, parse_hex_digits, parse_min_max, parse_multiple,
  parse_optional, parse_optional_result, parse_this_then, percent_decode,
  try_parsers,
}
import splitter

// URI-reference = URI / relative-ref
// URI           = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
// relative-ref  = relative-part [ "?" query ] [ "#" fragment ]
pub fn parse(uri: String) -> Result(Uri, Nil) {
  case parse_scheme(uri) {
    Ok(#(scheme, rest)) -> {
      use #(rel_part, rest) <- result.try(parse_hier_part(rest))

      let #(query, rest) = parse_query(rest)

      let #(fragment, rest) = parse_fragment(rest)

      case rest {
        "" -> Ok(combine_uris([scheme, rel_part, query, fragment]))
        _ -> Error(Nil)
      }
    }
    Error(_) -> {
      use #(rel_part, rest) <- result.try(parse_relative_part(uri))

      let #(query, rest) = parse_query(rest)

      let #(fragment, rest) = parse_fragment(rest)

      case rest {
        "" -> Ok(combine_uris([rel_part, query, fragment]))
        _ -> Error(Nil)
      }
    }
  }
}

// hier-part     = "//" authority path-abempty
//              / path-absolute
//              / path-rootless
//              / path-empty
fn parse_hier_part(str: String) -> Result(#(Uri, String), Nil) {
  try_parsers(
    [
      parse_authority,
      parse_path_absolute,
      parse_path_rootless,
      parse_path_empty,
    ],
    str,
  )
}

// query         = *( pchar / "/" / "?" )
fn parse_query(str: String) -> #(Uri, String) {
  case str {
    "?" <> rest -> {
      let #(query, rest) =
        parse_optional(rest, parse_multiple(_, parse_query_fragment))
      #(Uri(..empty, query: Some(query)), rest)
    }
    _ -> #(empty, str)
  }
}

// fragment      = *( pchar / "/" / "?" )
fn parse_fragment(str: String) -> #(Uri, String) {
  case str {
    "#" <> rest -> {
      let #(fragment, rest) =
        parse_optional(rest, parse_multiple(_, parse_query_fragment))
      #(Uri(..empty, fragment: Some(fragment)), rest)
    }
    _ -> #(empty, str)
  }
}

// relative-part = "//" authority path-abempty
//              / path-absolute
//              / path-noscheme
//              / path-empty
fn parse_relative_part(str: String) -> Result(#(Uri, String), Nil) {
  try_parsers(
    [
      parse_authority,
      parse_path_absolute,
      parse_path_noscheme,
      parse_path_empty,
    ],
    str,
  )
}

// scheme        = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
fn parse_scheme(str: String) -> Result(#(Uri, String), Nil) {
  case str {
    "http:" <> rest ->
      Ok(#(Uri(Some("http"), None, None, None, "", None, None), rest))
    "https:" <> rest ->
      Ok(#(Uri(Some("https"), None, None, None, "", None, None), rest))
    "ftp:" <> rest ->
      Ok(#(Uri(Some("ftp"), None, None, None, "", None, None), rest))
    "file:" <> rest ->
      Ok(#(Uri(Some("file"), None, None, None, "", None, None), rest))
    "ws:" <> rest ->
      Ok(#(Uri(Some("ws"), None, None, None, "", None, None), rest))
    "wss:" <> rest ->
      Ok(#(Uri(Some("wss"), None, None, None, "", None, None), rest))
    _ -> {
      case parse_alpha(str) {
        Ok(#(first, rest)) -> {
          case do_parse_scheme(rest, first) {
            Error(_) -> Error(Nil)
            Ok(#(scheme, rest)) ->
              Ok(#(Uri(Some(scheme), None, None, None, "", None, None), rest))
          }
        }
        _ -> Error(Nil)
      }
    }
  }
}

fn do_parse_scheme(
  str: String,
  scheme: String,
) -> Result(#(String, String), Nil) {
  case str {
    ":" <> rest -> Ok(#(scheme, rest))
    "" -> Error(Nil)
    _ -> {
      use #(part, rest) <- result.try(try_parsers(
        [
          parse_alpha,
          parse_digit,
          fn(str) {
            case str {
              "+" as l <> rest | "-" as l <> rest | "." as l <> rest ->
                Ok(#(l, rest))
              _ -> Error(Nil)
            }
          },
        ],
        str,
      ))
      do_parse_scheme(rest, scheme <> part)
    }
  }
}

// authority     = [ userinfo "@" ] host [ ":" port ]
fn parse_authority(str: String) -> Result(#(Uri, String), Nil) {
  case str {
    "//" <> rest -> {
      parse_authority_part(rest)
    }
    _ -> Error(Nil)
  }
}

fn parse_authority_part(str: String) -> Result(#(Uri, String), Nil) {
  let #(userinfo, rest) = parse_userinfo(str)

  use #(host, rest) <- result.try(parse_host(rest))

  let #(port, rest) = parse_port(rest)

  let #(path, rest) = parse_path_abempty(rest)

  Ok(#(Uri(None, userinfo, Some(host), port, path, None, None), rest))
}

// userinfo      = *( unreserved / pct-encoded / sub-delims / ":" )
fn parse_userinfo(str: String) -> #(Option(String), String) {
  case string.contains(str, "@") {
    True -> do_parse_userinfo(str, "")
    False -> #(None, str)
  }
}

fn do_parse_userinfo(str: String, userinfo: String) -> #(Option(String), String) {
  case str {
    "@" <> rest -> #(Some(userinfo), rest)
    "" -> #(None, userinfo <> str)
    _ -> {
      case
        try_parsers(
          [
            parse_unreserved,
            parse_pct_encoded,
            parse_sub_delim,
            fn(str: String) {
              case str {
                ":" as l <> rest -> Ok(#(l, rest))
                _ -> Error(Nil)
              }
            },
          ],
          str,
        )
      {
        Ok(#(part, rest)) -> do_parse_userinfo(rest, userinfo <> part)
        Error(_) -> #(None, userinfo <> str)
      }
    }
  }
}

// host          = IP-literal / IPv4address / reg-name
fn parse_host(str: String) {
  try_parsers([parse_ip_literal, parse_ipv4address, parse_reg_name], str)
}

// port          = *DIGIT
fn parse_port(str: String) -> #(Option(Int), String) {
  case str {
    ":" <> rest -> {
      let #(port, rest) = parse_digits(rest, "")
      #(int.parse(port) |> option.from_result, rest)
    }
    _ -> #(None, str)
  }
}

// IP-literal    = "[" ( IPv6address / IPvFuture  ) "]"
fn parse_ip_literal(str: String) {
  case str {
    "[" <> rest -> {
      use #(ip, rest) <- result.try(try_parsers(
        [parse_ipv6, parse_ipvfuture],
        rest,
      ))
      case rest {
        "]" <> rest -> Ok(#(ip, rest))
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

// IPvFuture     = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
fn parse_ipvfuture(str: String) {
  case str {
    "v" <> rest -> {
      use #(v, rest) <- result.try(parse_multiple(rest, parse_hex_digit))

      case rest {
        "." <> rest -> {
          use #(i, rest) <- result.try(
            parse_multiple(rest, fn(str) {
              try_parsers(
                [
                  parse_unreserved,
                  parse_sub_delim,
                  fn(str: String) {
                    case str {
                      ":" as l <> rest -> Ok(#(l, rest))
                      _ -> Error(Nil)
                    }
                  },
                ],
                str,
              )
            }),
          )
          Ok(#("v" <> v <> "." <> i, rest))
        }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

// IPv6address   =                            6( h16 ":" ) ls32
//              /                       "::" 5( h16 ":" ) ls32
//              / [               h16 ] "::" 4( h16 ":" ) ls32
//              / [ *1( h16 ":" ) h16 ] "::" 3( h16 ":" ) ls32
//              / [ *2( h16 ":" ) h16 ] "::" 2( h16 ":" ) ls32
//              / [ *3( h16 ":" ) h16 ] "::"    h16 ":"   ls32
//              / [ *4( h16 ":" ) h16 ] "::"              ls32
//              / [ *5( h16 ":" ) h16 ] "::"              h16
//              / [ *6( h16 ":" ) h16 ] "::"
fn parse_ipv6(str: String) {
  try_parsers(
    [
      parse_this_then(_, [parse_min_max(_, 6, 6, parse_h16_colon), parse_ls32]),
      parse_this_then(_, [
        parse_colons,
        parse_min_max(_, 5, 5, parse_h16_colon),
        parse_ls32,
      ]),
      parse_this_then(_, [
        parse_optional_result(_, parse_h16),
        parse_colons,
        parse_min_max(_, 4, 4, parse_h16_colon),
        parse_ls32,
      ]),
      parse_this_then(_, [
        parse_optional_result(
          _,
          parse_this_then(_, [parse_h16s(_, 1), parse_h16]),
        ),
        parse_colons,
        parse_min_max(_, 3, 3, parse_h16_colon),
        parse_ls32,
      ]),
      parse_this_then(_, [
        parse_optional_result(
          _,
          parse_this_then(_, [parse_h16s(_, 2), parse_h16]),
        ),
        parse_colons,
        parse_min_max(_, 2, 2, parse_h16_colon),
        parse_ls32,
      ]),
      parse_this_then(_, [
        parse_optional_result(
          _,
          parse_this_then(_, [parse_h16s(_, 3), parse_h16]),
        ),
        parse_colons,
        parse_min_max(_, 1, 1, parse_h16_colon),
        parse_ls32,
      ]),
      parse_this_then(_, [
        parse_optional_result(
          _,
          parse_this_then(_, [parse_h16s(_, 4), parse_h16]),
        ),
        parse_colons,
        parse_ls32,
      ]),
      parse_this_then(_, [
        parse_optional_result(
          _,
          parse_this_then(_, [parse_h16s(_, 5), parse_h16]),
        ),
        parse_colons,
        parse_h16,
      ]),
      parse_this_then(_, [
        parse_optional_result(
          _,
          parse_this_then(_, [parse_h16s(_, 6), parse_h16]),
        ),
        parse_colons,
      ]),
    ],
    str,
  )
}

fn parse_colons(str: String) {
  case str {
    "::" <> rest -> Ok(#("::", rest))
    _ -> Error(Nil)
  }
}

// h16           = 1*4HEXDIG
fn parse_h16(str: String) {
  parse_hex_digits(str, 1, 4)
}

fn parse_h16s(str: String, max) {
  parse_min_max(str, 0, max, parse_h16_colon)
}

fn parse_h16_pair(str: String) {
  use #(h16a, rest) <- result.try(parse_h16(str))
  case rest {
    ":" <> rest -> {
      use #(h16b, rest) <- result.try(parse_h16(rest))
      Ok(#(h16a <> ":" <> h16b, rest))
    }
    _ -> Error(Nil)
  }
}

fn parse_h16_colon(str: String) {
  use #(h16, rest) <- result.try(parse_h16(str))
  case rest {
    ":" <> rest -> Ok(#(h16 <> ":", rest))
    _ -> Error(Nil)
  }
}

// ls32          = ( h16 ":" h16 ) / IPv4address
fn parse_ls32(str: String) -> Result(#(String, String), Nil) {
  try_parsers([parse_h16_pair, parse_ipv4address], str)
}

// IPv4address   = dec-octet "." dec-octet "." dec-octet "." dec-octet
fn parse_ipv4address(str: String) {
  use #(oct1, rest) <- result.try(parse_dec_octet(str))
  use rest <- result.try(case rest {
    "." <> rest -> Ok(rest)
    _ -> Error(Nil)
  })
  use #(oct2, rest) <- result.try(parse_dec_octet(rest))
  use rest <- result.try(case rest {
    "." <> rest -> Ok(rest)
    _ -> Error(Nil)
  })
  use #(oct3, rest) <- result.try(parse_dec_octet(rest))
  use rest <- result.try(case rest {
    "." <> rest -> Ok(rest)
    _ -> Error(Nil)
  })
  use #(oct4, rest) <- result.try(parse_dec_octet(rest))
  Ok(#(oct1 <> "." <> oct2 <> "." <> oct3 <> "." <> oct4, rest))
}

// dec-octet     = DIGIT                 ; 0-9
//              / %x31-39 DIGIT         ; 10-99
//              / "1" 2DIGIT            ; 100-199
//              / "2" %x30-34 DIGIT     ; 200-249
//              / "25" %x30-35          ; 250-255
fn parse_dec_octet(str: String) -> Result(#(String, String), Nil) {
  try_parsers(
    [
      parse_this_then(_, [
        fn(str) {
          case str {
            "2" as l <> rest -> Ok(#(l, rest))
            _ -> Error(Nil)
          }
        },
        fn(str) {
          case str {
            "5" as l <> rest -> Ok(#(l, rest))
            _ -> Error(Nil)
          }
        },
        fn(str) {
          case str {
            "0" as l <> rest
            | "1" as l <> rest
            | "2" as l <> rest
            | "3" as l <> rest
            | "4" as l <> rest
            | "5" as l <> rest -> Ok(#(l, rest))
            _ -> Error(Nil)
          }
        },
      ]),
      parse_this_then(_, [
        fn(str) {
          case str {
            "2" as l <> rest -> Ok(#(l, rest))
            _ -> Error(Nil)
          }
        },
        fn(str) {
          case str {
            "0" as l <> rest
            | "1" as l <> rest
            | "2" as l <> rest
            | "3" as l <> rest
            | "4" as l <> rest -> Ok(#(l, rest))
            _ -> Error(Nil)
          }
        },
        parse_digit,
      ]),
      parse_this_then(_, [
        fn(str) {
          case str {
            "1" as l <> rest -> Ok(#(l, rest))
            _ -> Error(Nil)
          }
        },
        parse_digit,
        parse_digit,
      ]),
      parse_this_then(_, [parse_digit_nz, parse_digit]),
      parse_digit,
    ],
    str,
  )
}

// reg-name      = *( unreserved / pct-encoded / sub-delims )
fn parse_reg_name(str: String) {
  // can't error

  case do_parse_reg_name(str, "") {
    Error(Nil) -> Ok(#("", str))
    Ok(#(reg_name, rest)) -> Ok(#(reg_name, rest))
  }
}

fn do_parse_reg_name(str: String, reg_name: String) {
  case
    try_parsers([parse_unreserved, parse_pct_encoded, parse_sub_delim], str)
  {
    Error(Nil) | Ok(#("", _)) -> Ok(#(reg_name, str))
    Ok(#(l, rest)) -> do_parse_reg_name(rest, reg_name <> l)
  }
}

// path          = path-abempty    ; begins with "/" or is empty
//              / path-absolute   ; begins with "/" but not "//"
//              / path-noscheme   ; begins with a non-colon segment
//              / path-rootless   ; begins with a segment
//              / path-empty      ; zero characters
// path-abempty  = *( "/" segment )
fn parse_path_abempty(str: String) -> #(String, String) {
  parse_optional(
    str,
    parse_multiple(_, fn(str) {
      case str {
        "/" <> rest -> {
          do_parse_segment(rest, do_parse_pchar, "/")
        }
        _ -> Error(Nil)
      }
    }),
  )
}

// path-absolute = "/" [ segment-nz *( "/" segment ) ]
fn parse_path_absolute(str: String) -> Result(#(Uri, String), Nil) {
  case str {
    "/" <> rest -> {
      let #(seg, rest) =
        parse_optional(
          rest,
          parse_this_then(_, [
            do_parse_segment_nz,
            parse_optional_result(
              _,
              parse_multiple(_, fn(str) {
                case str {
                  "/" <> rest -> {
                    do_parse_segment(rest, do_parse_pchar, "/")
                  }
                  _ -> Error(Nil)
                }
              }),
            ),
          ]),
        )

      Ok(#(Uri(None, None, None, None, "/" <> seg, None, None), rest))
    }
    _ -> Error(Nil)
  }
}

// path-noscheme = segment-nz-nc *( "/" segment )
fn parse_path_noscheme(str: String) -> Result(#(Uri, String), Nil) {
  use #(seg1, rest) <- result.try(do_parse_segment_nz_nc(str))

  let #(segs, rest) =
    parse_optional(
      rest,
      parse_multiple(_, fn(str) {
        case str {
          "/" <> rest -> {
            do_parse_segment(rest, do_parse_pchar, "/")
          }
          _ -> Error(Nil)
        }
      }),
    )

  Ok(#(Uri(None, None, None, None, seg1 <> segs, None, None), rest))
}

// path-rootless = segment-nz *( "/" segment )
fn parse_path_rootless(str: String) -> Result(#(Uri, String), Nil) {
  use #(seg1, rest) <- result.try(do_parse_segment_nz(str))

  let #(segs, rest) =
    parse_optional(
      rest,
      parse_multiple(_, fn(str) {
        case str {
          "/" <> rest -> {
            do_parse_segment(rest, do_parse_pchar, "/")
          }
          _ -> Error(Nil)
        }
      }),
    )

  Ok(#(Uri(None, None, None, None, seg1 <> segs, None, None), rest))
}

// path-empty    = 0<pchar>
fn parse_path_empty(str: String) -> Result(#(Uri, String), Nil) {
  Ok(#(Uri(None, None, None, None, "", None, None), str))
}

//    segment       = *pchar
fn do_parse_segment(
  str: String,
  char_fn,
  segment: String,
) -> Result(#(String, String), Nil) {
  case char_fn(str) {
    Error(Nil) | Ok(#("", _)) -> Ok(#(segment, str))
    Ok(#(l, rest)) -> do_parse_segment(rest, char_fn, segment <> l)
  }
}

// segment-nz    = 1*pchar
fn do_parse_segment_nz(str: String) {
  use #(char1, rest) <- result.try(do_parse_pchar(str))

  use #(chars, rest) <- result.try(do_parse_segment(rest, do_parse_pchar, char1))

  Ok(#(chars, rest))
}

// segment-nz-nc = 1*( unreserved / pct-encoded / sub-delims / "@" )
//              ; non-zero-length segment without any colon ":"
fn do_parse_segment_nz_nc(str: String) {
  use #(char1, rest) <- result.try(do_parse_pchar_without_colon(str))

  use #(chars, rest) <- result.try(do_parse_segment(
    rest,
    do_parse_pchar_without_colon,
    char1,
  ))

  Ok(#(chars, rest))
}

// pchar         = unreserved / pct-encoded / sub-delims / ":" / "@"
fn do_parse_pchar(str: String) {
  try_parsers(
    [
      parse_unreserved,
      parse_pct_encoded,
      parse_sub_delim,
      fn(str: String) {
        case str {
          ":" as l <> rest | "@" as l <> rest -> Ok(#(l, rest))
          _ -> Error(Nil)
        }
      },
    ],
    str,
  )
}

fn do_parse_pchar_without_colon(str: String) {
  try_parsers(
    [
      parse_unreserved,
      parse_pct_encoded,
      parse_sub_delim,
      fn(str: String) {
        case str {
          "@" as l <> rest -> Ok(#(l, rest))
          _ -> Error(Nil)
        }
      },
    ],
    str,
  )
}

// query         = *( pchar / "/" / "?" )
// fragment      = *( pchar / "/" / "?" )
fn parse_query_fragment(str: String) {
  try_parsers(
    [
      do_parse_pchar,
      fn(str: String) {
        case str {
          "/" as l <> rest | "?" as l <> rest -> Ok(#(l, rest))
          _ -> Error(Nil)
        }
      },
    ],
    str,
  )
}

// pct-encoded   = "%" HEXDIG HEXDIG
fn parse_pct_encoded(str: String) {
  case str {
    "%" <> rest -> {
      use #(hex1, rest) <- result.try(parse_hex_digit(rest))
      use #(hex2, rest) <- result.try(parse_hex_digit(rest))

      Ok(#("%" <> hex1 <> hex2, rest))
    }
    _ -> Error(Nil)
  }
}

// unreserved    = ALPHA / DIGIT / "-" / "." / "_" / "~"
// reserved      = gen-delims / sub-delims
// gen-delims    = ":" / "/" / "?" / "#" / "[" / "]" / "@"
fn parse_unreserved(str: String) -> Result(#(String, String), Nil) {
  try_parsers(
    [
      parse_alpha,
      parse_digit,
      fn(str) {
        case str {
          "_" as l <> rest
          | "-" as l <> rest
          | "." as l <> rest
          | "~" as l <> rest -> Ok(#(l, rest))
          _ -> Error(Nil)
        }
      },
    ],
    str,
  )
}

// sub-delims    = "!" / "$" / "&" / "'" / "(" / ")"
//               / "*" / "+" / "," / ";" / "="
//                 %21 / %24 / %26 / %27 / %28 / %29
//               / %2A / %2B / %2C / %3B / %3D
@target(erlang)
fn parse_sub_delim(str: String) -> Result(#(String, String), Nil) {
  case string.pop_grapheme(str) {
    Ok(#("!" as char, tail))
    | Ok(#("$" as char, tail))
    | Ok(#("&" as char, tail))
    | Ok(#("'" as char, tail))
    | Ok(#("(" as char, tail))
    | Ok(#(")" as char, tail))
    | Ok(#("*" as char, tail))
    | Ok(#("+" as char, tail))
    | Ok(#("," as char, tail))
    | Ok(#(";" as char, tail))
    | Ok(#("=" as char, tail)) -> Ok(#(char, tail))
    _ -> Error(Nil)
  }
}

@target(javascript)
fn parse_sub_delim(str: String) -> Result(#(String, String), Nil) {
  case str {
    "!" as char <> tail
    | "$" as char <> tail
    | "&" as char <> tail
    | "'" as char <> tail
    | "(" as char <> tail
    | ")" as char <> tail
    | "*" as char <> tail
    | "+" as char <> tail
    | "," as char <> tail
    | ";" as char <> tail
    | "=" as char <> tail -> Ok(#(char, tail))
    _ -> Error(Nil)
  }
}

// DIGIT    = %x30–39
@target(erlang)
fn parse_digit(str: String) -> Result(#(String, String), Nil) {
  case string.pop_grapheme(str) {
    Ok(#("0" as char, tail))
    | Ok(#("1" as char, tail))
    | Ok(#("2" as char, tail))
    | Ok(#("3" as char, tail))
    | Ok(#("4" as char, tail))
    | Ok(#("5" as char, tail))
    | Ok(#("6" as char, tail))
    | Ok(#("7" as char, tail))
    | Ok(#("8" as char, tail))
    | Ok(#("9" as char, tail)) -> Ok(#(char, tail))

    _ -> Error(Nil)
  }
}

@target(javascript)
fn parse_digit(str: String) -> Result(#(String, String), Nil) {
  case str {
    "0" as char <> tail
    | "1" as char <> tail
    | "2" as char <> tail
    | "3" as char <> tail
    | "4" as char <> tail
    | "5" as char <> tail
    | "6" as char <> tail
    | "7" as char <> tail
    | "8" as char <> tail
    | "9" as char <> tail -> Ok(#(char, tail))

    _ -> Error(Nil)
  }
}

// DIGIT (non-zero)    = %x31–39
@target(erlang)
fn parse_digit_nz(str: String) -> Result(#(String, String), Nil) {
  case string.pop_grapheme(str) {
    Ok(#("1" as char, tail))
    | Ok(#("2" as char, tail))
    | Ok(#("3" as char, tail))
    | Ok(#("4" as char, tail))
    | Ok(#("5" as char, tail))
    | Ok(#("6" as char, tail))
    | Ok(#("7" as char, tail))
    | Ok(#("8" as char, tail))
    | Ok(#("9" as char, tail)) -> Ok(#(char, tail))

    _ -> Error(Nil)
  }
}

@target(javascript)
fn parse_digit_nz(str: String) -> Result(#(String, String), Nil) {
  case str {
    "1" as char <> tail
    | "2" as char <> tail
    | "3" as char <> tail
    | "4" as char <> tail
    | "5" as char <> tail
    | "6" as char <> tail
    | "7" as char <> tail
    | "8" as char <> tail
    | "9" as char <> tail -> Ok(#(char, tail))

    _ -> Error(Nil)
  }
}

fn parse_digits(str: String, digits: String) {
  case parse_digit(str) {
    Ok(#(d, rest)) -> {
      parse_digits(rest, digits <> d)
    }
    Error(_) -> #(digits, str)
  }
}

// ALPHA    = %x41–5A | %x61–7A
@target(erlang)
fn parse_alpha(str: String) -> Result(#(String, String), Nil) {
  case string.pop_grapheme(str) {
    Ok(#("a" as char, tail))
    | Ok(#("b" as char, tail))
    | Ok(#("c" as char, tail))
    | Ok(#("d" as char, tail))
    | Ok(#("e" as char, tail))
    | Ok(#("f" as char, tail))
    | Ok(#("g" as char, tail))
    | Ok(#("h" as char, tail))
    | Ok(#("i" as char, tail))
    | Ok(#("j" as char, tail))
    | Ok(#("k" as char, tail))
    | Ok(#("l" as char, tail))
    | Ok(#("m" as char, tail))
    | Ok(#("n" as char, tail))
    | Ok(#("o" as char, tail))
    | Ok(#("p" as char, tail))
    | Ok(#("q" as char, tail))
    | Ok(#("r" as char, tail))
    | Ok(#("s" as char, tail))
    | Ok(#("t" as char, tail))
    | Ok(#("u" as char, tail))
    | Ok(#("v" as char, tail))
    | Ok(#("w" as char, tail))
    | Ok(#("x" as char, tail))
    | Ok(#("y" as char, tail))
    | Ok(#("z" as char, tail))
    | Ok(#("A" as char, tail))
    | Ok(#("B" as char, tail))
    | Ok(#("C" as char, tail))
    | Ok(#("D" as char, tail))
    | Ok(#("E" as char, tail))
    | Ok(#("F" as char, tail))
    | Ok(#("G" as char, tail))
    | Ok(#("H" as char, tail))
    | Ok(#("I" as char, tail))
    | Ok(#("J" as char, tail))
    | Ok(#("K" as char, tail))
    | Ok(#("L" as char, tail))
    | Ok(#("M" as char, tail))
    | Ok(#("N" as char, tail))
    | Ok(#("O" as char, tail))
    | Ok(#("P" as char, tail))
    | Ok(#("Q" as char, tail))
    | Ok(#("R" as char, tail))
    | Ok(#("S" as char, tail))
    | Ok(#("T" as char, tail))
    | Ok(#("U" as char, tail))
    | Ok(#("V" as char, tail))
    | Ok(#("W" as char, tail))
    | Ok(#("X" as char, tail))
    | Ok(#("Y" as char, tail))
    | Ok(#("Z" as char, tail)) -> Ok(#(char, tail))

    _ -> Error(Nil)
  }
}

@target(javascript)
fn parse_alpha(str: String) -> Result(#(String, String), Nil) {
  case str {
    "a" as char <> tail
    | "b" as char <> tail
    | "c" as char <> tail
    | "d" as char <> tail
    | "e" as char <> tail
    | "f" as char <> tail
    | "g" as char <> tail
    | "h" as char <> tail
    | "i" as char <> tail
    | "j" as char <> tail
    | "k" as char <> tail
    | "l" as char <> tail
    | "m" as char <> tail
    | "n" as char <> tail
    | "o" as char <> tail
    | "p" as char <> tail
    | "q" as char <> tail
    | "r" as char <> tail
    | "s" as char <> tail
    | "t" as char <> tail
    | "u" as char <> tail
    | "v" as char <> tail
    | "w" as char <> tail
    | "x" as char <> tail
    | "y" as char <> tail
    | "z" as char <> tail
    | "A" as char <> tail
    | "B" as char <> tail
    | "C" as char <> tail
    | "D" as char <> tail
    | "E" as char <> tail
    | "F" as char <> tail
    | "G" as char <> tail
    | "H" as char <> tail
    | "I" as char <> tail
    | "J" as char <> tail
    | "K" as char <> tail
    | "L" as char <> tail
    | "M" as char <> tail
    | "N" as char <> tail
    | "O" as char <> tail
    | "P" as char <> tail
    | "Q" as char <> tail
    | "R" as char <> tail
    | "S" as char <> tail
    | "T" as char <> tail
    | "U" as char <> tail
    | "V" as char <> tail
    | "W" as char <> tail
    | "X" as char <> tail
    | "Y" as char <> tail
    | "Z" as char <> tail -> Ok(#(char, tail))

    _ -> Error(Nil)
  }
}

pub fn parse_query_parts(query: String) -> Result(List(#(String, String)), Nil) {
  let splitter = splitter.new(["&"])

  do_parse_query_parts(splitter, query, [])
}

fn do_parse_query_parts(
  splitter: splitter.Splitter,
  query: String,
  acc: List(#(String, String)),
) -> Result(List(#(String, String)), Nil) {
  case splitter.split(splitter, query) {
    #("", _, "") -> Ok(list.reverse(acc))
    #("", _, rest) -> do_parse_query_parts(splitter, rest, acc)
    #(pair, _, rest) -> {
      use pair <- result.try(do_parse_query_pair(pair))

      let acc = [pair, ..acc]

      case rest {
        "" -> Ok(list.reverse(acc))
        _ -> do_parse_query_parts(splitter, rest, acc)
      }
    }
  }
}

fn do_parse_query_pair(pair: String) -> Result(#(String, String), Nil) {
  let #(key, val) = case string.split_once(pair, "=") {
    Error(_) -> #(pair, "")
    Ok(p) -> p
  }
  use key <- result.try(percent_decode(string.replace(key, "+", " ")))
  use val <- result.try(percent_decode(string.replace(val, "+", " ")))

  Ok(#(key, val))
}
