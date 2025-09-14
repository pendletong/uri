import gleam/bool
import gleam/int
import gleam/list.{Continue, Stop}
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri.{type Uri, Uri, empty}
import gluri/internal/utils
import splitter

pub fn parse(uri: String) -> Result(Uri, Nil) {
  case parse_scheme(uri) {
    Ok(#(scheme, rest)) -> {
      use #(rel_part, rest) <- result.try(parse_hier_part(rest))

      use #(query, rest) <- result.try(parse_query(rest))

      use #(fragment, rest) <- result.try(parse_fragment(rest))

      case rest {
        "" -> Ok(combine_uris([scheme, rel_part, query, fragment]))
        _ -> Error(Nil)
      }
    }
    Error(_) -> {
      use #(rel_part, rest) <- result.try(parse_relative_part(uri))

      use #(query, rest) <- result.try(parse_query(rest))

      use #(fragment, rest) <- result.try(parse_fragment(rest))

      case rest {
        "" -> Ok(combine_uris([rel_part, query, fragment]))
        _ -> Error(Nil)
      }
    }
  }
}

fn parse_query(str: String) -> Result(#(Uri, String), Nil) {
  case str {
    "?" <> rest -> {
      let #(query, rest) =
        utils.get_multiple_optional(parse_query_fragment, rest)
      Ok(#(Uri(..empty, query: Some(query)), rest))
    }
    _ -> Ok(#(empty, str))
  }
}

fn parse_fragment(str: String) -> Result(#(Uri, String), Nil) {
  case str {
    "#" <> rest -> {
      let #(fragment, rest) =
        utils.get_multiple_optional(parse_query_fragment, rest)
      Ok(#(Uri(..empty, fragment: Some(fragment)), rest))
    }
    _ -> Ok(#(empty, str))
  }
}

fn parse_hier_part(str: String) -> Result(#(Uri, String), Nil) {
  utils.try_parsers(
    [parse_authority, parse_absolute, parse_rootless, parse_empty],
    str,
  )
}

fn parse_relative_part(str: String) -> Result(#(Uri, String), Nil) {
  utils.try_parsers(
    [parse_authority, parse_absolute, parse_noscheme, parse_empty],
    str,
  )
}

fn parse_absolute(str: String) -> Result(#(Uri, String), Nil) {
  case str {
    "/" <> rest -> {
      use #(seg, rest) <- result.try(
        parse_optional(rest, parse_this_then(
          [
            do_parse_segment_nz,
            utils.get_multiple_optional_result(
              fn(str) {
                case str {
                  "/" <> rest -> {
                    do_parse_segment(rest, do_parse_pchar, "/")
                  }
                  _ -> Error(Nil)
                }
              },
              _,
            ),
          ],
          _,
        )),
      )

      Ok(#(Uri(None, None, None, None, "/" <> seg, None, None), rest))
    }
    _ -> Error(Nil)
  }
}

fn parse_rootless(str: String) -> Result(#(Uri, String), Nil) {
  use #(seg1, rest) <- result.try(do_parse_segment_nz(str))

  let #(segs, rest) =
    utils.get_multiple_optional(
      fn(str) {
        case str {
          "/" <> rest -> {
            do_parse_segment(rest, do_parse_pchar, "/")
          }
          _ -> Error(Nil)
        }
      },
      rest,
    )

  Ok(#(Uri(None, None, None, None, seg1 <> segs, None, None), rest))
}

fn parse_noscheme(str: String) -> Result(#(Uri, String), Nil) {
  use #(seg1, rest) <- result.try(do_parse_segment_nz_nc(str))

  let #(segs, rest) =
    utils.get_multiple_optional(
      fn(str) {
        case str {
          "/" <> rest -> {
            do_parse_segment(rest, do_parse_pchar, "/")
          }
          _ -> Error(Nil)
        }
      },
      rest,
    )

  Ok(#(Uri(None, None, None, None, seg1 <> segs, None, None), rest))
}

fn parse_optional(str, opt_fn) {
  case opt_fn(str) {
    Error(Nil) -> Ok(#("", str))
    Ok(r) -> Ok(r)
  }
}

fn parse_empty(str: String) -> Result(#(Uri, String), Nil) {
  Ok(#(Uri(None, None, None, None, "", None, None), str))
}

fn parse_authority(str: String) -> Result(#(Uri, String), Nil) {
  case str {
    "//" <> rest -> {
      parse_authority_part(rest)
    }
    _ -> Error(Nil)
  }
}

fn parse_authority_part(str: String) -> Result(#(Uri, String), Nil) {
  let #(ui, rest) = case parse_userinfo(str, "") {
    Ok(#(ui, rest)) -> #(Some(ui), rest)
    Error(_) -> #(None, str)
  }

  use #(host, rest) <- result.try(parse_host(rest))

  let #(port, rest) = case parse_port(rest) {
    Ok(#("", rest)) -> #(None, rest)
    Error(_) -> #(None, rest)
    Ok(#(port, rest)) -> {
      #(int.parse(port) |> option.from_result, rest)
    }
  }

  let #(path, rest) = parse_path_abempty(rest)

  Ok(#(Uri(None, ui, Some(host), port, path, None, None), rest))
}

fn parse_port(str: String) {
  case str {
    ":" <> rest -> {
      Ok(parse_digits(rest, ""))
    }
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

fn parse_host(str: String) {
  utils.try_parsers([parse_ip_literal, parse_ipv4, parse_reg_name], str)
}

fn parse_ip_literal(str: String) {
  case str {
    "[" <> rest -> {
      use #(ip, rest) <- result.try(utils.try_parsers(
        [parse_ipv6, parse_ipfuture],
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

fn parse_ipv6(str: String) {
  utils.try_parsers(
    [
      parse_this_then([parse_min_max(_, 6, 6, parse_h16_colon), parse_ls32], _),
      parse_this_then(
        [parse_colons, parse_min_max(_, 5, 5, parse_h16_colon), parse_ls32],
        _,
      ),
      parse_this_then(
        [
          parse_optional(_, parse_h16),
          parse_colons,
          parse_min_max(_, 4, 4, parse_h16_colon),
          parse_ls32,
        ],
        _,
      ),
      parse_this_then(
        [
          parse_optional(_, parse_this_then([parse_h16s(_, 1), parse_h16], _)),
          parse_colons,
          parse_min_max(_, 3, 3, parse_h16_colon),
          parse_ls32,
        ],
        _,
      ),
      parse_this_then(
        [
          parse_optional(_, parse_this_then([parse_h16s(_, 2), parse_h16], _)),
          parse_colons,
          parse_min_max(_, 2, 2, parse_h16_colon),
          parse_ls32,
        ],
        _,
      ),
      parse_this_then(
        [
          parse_optional(_, parse_this_then([parse_h16s(_, 3), parse_h16], _)),
          parse_colons,
          parse_min_max(_, 1, 1, parse_h16_colon),
          parse_ls32,
        ],
        _,
      ),
      parse_this_then(
        [
          parse_optional(_, parse_this_then([parse_h16s(_, 4), parse_h16], _)),
          parse_colons,
          parse_ls32,
        ],
        _,
      ),
      parse_this_then(
        [
          parse_optional(_, parse_this_then([parse_h16s(_, 5), parse_h16], _)),
          parse_colons,
          parse_h16,
        ],
        _,
      ),
      parse_this_then(
        [
          parse_optional(_, parse_this_then([parse_h16s(_, 6), parse_h16], _)),
          parse_colons,
        ],
        _,
      ),
    ],
    str,
  )
}

fn parse_h16s(str: String, max) {
  parse_min_max(str, 0, max, parse_h16_colon)
}

fn parse_colons(str: String) {
  case str {
    "::" <> rest -> Ok(#("::", rest))
    _ -> Error(Nil)
  }
}

fn parse_this_then(
  parsers: List(fn(String) -> Result(#(String, String), Nil)),
  str: String,
) {
  list.fold_until(parsers, Ok(#("", str)), fn(acc, parser) {
    let assert Ok(#(res, str)) = acc
    case parser(str) {
      Ok(#(res2, rest)) -> {
        Continue(Ok(#(res <> res2, rest)))
      }
      Error(Nil) -> Stop(Error(Nil))
    }
  })
}

fn parse_ls32(str: String) -> Result(#(String, String), Nil) {
  utils.try_parsers([parse_h16_pair, parse_ipv4], str)
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

fn parse_h16(str: String) {
  parse_hex_digits(str, 1, 4)
}

fn parse_h16_colon(str: String) {
  use #(h16, rest) <- result.try(parse_h16(str))
  case rest {
    ":" <> rest -> Ok(#(h16 <> ":", rest))
    _ -> Error(Nil)
  }
}

fn parse_ipfuture(str: String) {
  case str {
    "v" <> rest -> {
      use #(v, rest) <- result.try(utils.get_multiple(
        utils.parse_hex_digit,
        rest,
      ))

      case rest {
        "." <> rest -> {
          use #(i, rest) <- result.try(utils.get_multiple(
            fn(str) {
              utils.try_parsers(
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
            },
            rest,
          ))
          Ok(#("v" <> v <> "." <> i, rest))
        }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn parse_query_fragment(str: String) {
  utils.try_parsers(
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

fn parse_path_abempty(str: String) -> #(String, String) {
  utils.get_multiple_optional(
    fn(str) {
      case str {
        "/" <> rest -> {
          do_parse_segment(rest, do_parse_pchar, "/")
        }
        _ -> Error(Nil)
      }
    },
    str,
  )
}

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

fn do_parse_segment_nz(str: String) {
  use #(char1, rest) <- result.try(do_parse_pchar(str))

  use #(chars, rest) <- result.try(do_parse_segment(rest, do_parse_pchar, char1))

  Ok(#(chars, rest))
}

fn do_parse_segment_nz_nc(str: String) {
  use #(char1, rest) <- result.try(do_parse_pchar_nc(str))

  use #(chars, rest) <- result.try(do_parse_segment(
    rest,
    do_parse_pchar_nc,
    char1,
  ))

  Ok(#(chars, rest))
}

fn do_parse_pchar(str: String) {
  utils.try_parsers(
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

fn do_parse_pchar_nc(str: String) {
  utils.try_parsers(
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

pub fn parse_reg_name(str: String) {
  // can't error

  case do_parse_reg_name(str, "") {
    Error(Nil) -> Ok(#("", str))
    Ok(#(reg_name, rest)) -> Ok(#(reg_name, rest))
  }
}

fn do_parse_reg_name(str: String, reg_name: String) {
  case
    utils.try_parsers(
      [parse_unreserved, parse_pct_encoded, parse_sub_delim],
      str,
    )
  {
    Error(Nil) | Ok(#("", _)) -> Ok(#(reg_name, str))
    Ok(#(l, rest)) -> do_parse_reg_name(rest, reg_name <> l)
  }
}

fn parse_pct_encoded(str: String) {
  case str {
    "%" <> rest -> {
      use #(hex1, rest) <- result.try(utils.parse_hex_digit(rest))
      use #(hex2, rest) <- result.try(utils.parse_hex_digit(rest))

      Ok(#("%" <> hex1 <> hex2, rest))
    }
    _ -> Error(Nil)
  }
}

fn parse_sub_delim(str: String) {
  case str {
    "!" as l <> rest
    | "$" as l <> rest
    | "&" as l <> rest
    | "'" as l <> rest
    | "(" as l <> rest
    | ")" as l <> rest
    | "*" as l <> rest
    | "+" as l <> rest
    | "," as l <> rest
    | ";" as l <> rest
    | "=" as l <> rest -> Ok(#(l, rest))
    _ -> Error(Nil)
  }
}

fn parse_ipv4(str: String) {
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

const octet_matches = [
  ["2", "5", "012345"],
  ["2", "01234", "0123456789"],
  ["1", "0123456789", "0123456789"],
  ["123456789", "0123456789"],
  ["0123456789"],
]

fn parse_dec_octet(str: String) -> Result(#(String, String), Nil) {
  list.fold_until(octet_matches, Error(Nil), fn(_, chars) {
    case
      list.fold_until(chars, #("", str), fn(acc, charset) {
        let #(octet, str) = acc
        case string.pop_grapheme(str) {
          Error(_) -> Stop(#("", ""))
          Ok(#(char, rest)) -> {
            case string.contains(charset, char) {
              True -> Continue(#(octet <> char, rest))
              False -> Stop(#("", ""))
            }
          }
        }
      })
    {
      #("", _) -> Continue(Error(Nil))
      #(octet, rest) -> Stop(Ok(#(octet, rest)))
    }
  })
}

fn parse_userinfo(
  str: String,
  userinfo: String,
) -> Result(#(String, String), Nil) {
  case str {
    "@" <> rest -> Ok(#(userinfo, rest))
    "" -> Error(Nil)
    _ -> {
      use #(part, rest) <- result.try(utils.try_parsers(
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
      ))
      parse_userinfo(rest, userinfo <> part)
    }
  }
}

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
      use #(part, rest) <- result.try(utils.try_parsers(
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

fn parse_min_max(str, min, max, parse_fn) {
  use <- bool.guard(when: min < 0 || max <= 0 || min > max, return: Error(Nil))
  case
    list.repeat("", max)
    |> list.fold_until(Ok(#("", str, 0)), fn(acc, _) {
      let assert Ok(#(hex, str, i)) = acc
      case parse_fn(str) {
        Error(_) ->
          case i < min {
            True -> Stop(Error(Nil))
            False -> Stop(Ok(#(hex, str, i)))
          }
        Ok(#(l, rest)) -> Continue(Ok(#(hex <> l, rest, i + 1)))
      }
    })
  {
    Error(_) -> Error(Nil)
    Ok(#(hex, str, _)) -> Ok(#(hex, str))
  }
}

fn parse_hex_digits(str, min, max) {
  parse_min_max(str, min, max, utils.parse_hex_digit)
}

fn parse_digit(str: String) -> Result(#(String, String), Nil) {
  case str {
    "0" as l <> rest
    | "1" as l <> rest
    | "2" as l <> rest
    | "3" as l <> rest
    | "4" as l <> rest
    | "5" as l <> rest
    | "6" as l <> rest
    | "7" as l <> rest
    | "8" as l <> rest
    | "9" as l <> rest -> Ok(#(l, rest))
    _ -> Error(Nil)
  }
}

fn parse_alpha(str: String) -> Result(#(String, String), Nil) {
  case str {
    "a" as l <> rest
    | "b" as l <> rest
    | "c" as l <> rest
    | "d" as l <> rest
    | "e" as l <> rest
    | "f" as l <> rest
    | "g" as l <> rest
    | "h" as l <> rest
    | "i" as l <> rest
    | "j" as l <> rest
    | "k" as l <> rest
    | "l" as l <> rest
    | "m" as l <> rest
    | "n" as l <> rest
    | "o" as l <> rest
    | "p" as l <> rest
    | "q" as l <> rest
    | "r" as l <> rest
    | "s" as l <> rest
    | "t" as l <> rest
    | "u" as l <> rest
    | "v" as l <> rest
    | "w" as l <> rest
    | "x" as l <> rest
    | "y" as l <> rest
    | "z" as l <> rest
    | "A" as l <> rest
    | "B" as l <> rest
    | "C" as l <> rest
    | "D" as l <> rest
    | "E" as l <> rest
    | "F" as l <> rest
    | "G" as l <> rest
    | "H" as l <> rest
    | "I" as l <> rest
    | "J" as l <> rest
    | "K" as l <> rest
    | "L" as l <> rest
    | "M" as l <> rest
    | "N" as l <> rest
    | "O" as l <> rest
    | "P" as l <> rest
    | "Q" as l <> rest
    | "R" as l <> rest
    | "S" as l <> rest
    | "T" as l <> rest
    | "U" as l <> rest
    | "V" as l <> rest
    | "W" as l <> rest
    | "X" as l <> rest
    | "Y" as l <> rest
    | "Z" as l <> rest -> Ok(#(l, rest))
    _ -> Error(Nil)
  }
}

fn parse_unreserved(str: String) -> Result(#(String, String), Nil) {
  utils.try_parsers(
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

fn combine_uris(uris: List(Uri)) -> Uri {
  list.fold(uris, Uri(None, None, None, None, "", None, None), fn(acc, uri) {
    let acc = case uri {
      Uri(Some(scheme), _, _, _, _, _, _) -> Uri(..acc, scheme: Some(scheme))
      _ -> acc
    }
    let acc = case uri {
      Uri(_, Some(userinfo), _, _, _, _, _) ->
        Uri(..acc, userinfo: Some(userinfo))
      _ -> acc
    }
    let acc = case uri {
      Uri(_, _, Some(host), _, _, _, _) -> Uri(..acc, host: Some(host))
      _ -> acc
    }
    let acc = case uri {
      Uri(_, _, _, Some(port), _, _, _) -> Uri(..acc, port: Some(port))
      _ -> acc
    }
    let acc = case uri {
      Uri(_, _, _, _, path, _, _) if path != "" -> Uri(..acc, path: path)
      _ -> acc
    }
    let acc = case uri {
      Uri(_, _, _, _, _, Some(query), _) -> Uri(..acc, query: Some(query))
      _ -> acc
    }
    case uri {
      Uri(_, _, _, _, _, _, Some(fragment)) ->
        Uri(..acc, fragment: Some(fragment))
      _ -> acc
    }
  })
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
  use key <- result.try(utils.percent_decode(string.replace(key, "+", " ")))
  use val <- result.try(utils.percent_decode(string.replace(val, "+", " ")))

  Ok(#(key, val))
}
