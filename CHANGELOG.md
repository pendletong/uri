# Changelog

## v1.0.0

- Initial Release

## v2.0.0

- Removed types.Uri. Now gluri uses the stdlib Uri type (and empty)

## v2.0.1

- Improved parsing performance significantly and reduced memory usage up to 50%
- Significantly improved IPV4 parsing performance

## v2.0.2

- Minor performance improvement for uris with userinfo
- More performance improvements for ascii/digit parsing

## 2.0.3

- Minor performance improvement for erlang
- Major performance improvement for js

## 2.0.4

- Reverted some optimisations as they are unnecessary for Gleam v1.14.0+
- Fix uri encoding/decoding (I think)

## 2.0.5

- Updated libraries
- Fixed IPV6 parsing (hopefully)

## 2.0.6

- Fix [] wrapping for IPv6 and IPvFuture

## 2.0.7

- Rework IPv6 parsing for major performance improvement of shortened formats
  - NB this is the first version of gluri that implements section specific parsing. Previously the parser strictly followed the abnf spec which caused issues with IPv6 as the frequent backtracking caused performance issues.
- Modify query_to_string to reduce the number of characters that are percent encoded
- Reworked internals to avoid asserts and use <-
