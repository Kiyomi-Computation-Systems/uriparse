# Queries and percent-encoding

This page is about the byte-level libraries `(uri query)` and
`(uri percent)`. With strings, `(uri easy)` has `uri-query-pairs`,
`uri-form-pairs`, `uri-decode` and `uri-encode`, which follow the same rules:
see [URIs as strings](easy.md#decoding).

## Query pairs

RFC 3986 says nothing about what is inside a query: to the RFC,
`q=1&lang=en` is just bytes. The `key=value&key=value` reading is a
convention from HTML forms. `(uri query)` reads a query that way.

`query-pairs` takes the query's bytes and returns a list of
`(key . value)` pairs, each one decoded:

```scheme
(import (rnrs) (uri query))

(define (show-pairs pairs)
  (for-each (lambda (p)
              (write (utf8->string (car p)))
              (display " = ")
              (write (and (cdr p) (utf8->string (cdr p))))
              (newline))
            pairs))

(show-pairs (query-pairs (string->utf8 "q=a%26b&lang=en&flag&empty=")))
```

```text
"q" = "a&b"
"lang" = "en"
"flag" = #f
"empty" = ""
```

The rules:

- **Split, then decode.** `%26` is an `&`, but it is decoded after the split,
  so it stays inside its value.
- **`&` is the only separator.** `;` is an ordinary character.
- **A piece splits at its first `=`.** `a=b=c` is the key `a` with the value
  `b=c`.
- **No `=` means no value.** `flag` has the value `#f`. `empty=` has the
  value `""`, which is not the same.
- **Empty pieces are skipped.** `a&&b` is two pairs, and an empty query has
  none.
- **Order and repeats are kept.** `a=1&a=2` is two pairs, in that order.

```scheme
(length (query-pairs (string->utf8 "a&&b")))
;; => 2
(query-pairs (string->utf8 ""))
;; => ()
```

`form-pairs` is the same, except that `+` means a space, as HTML forms write
it. `query-pairs` leaves `+` alone, since RFC 3986 gives it no meaning. An
encoded `%2B` is a real `+` either way:

```scheme
(utf8->string (cdar (form-pairs (string->utf8 "q=a+b%2Bc"))))
;; => "a b+c"
(utf8->string (cdar (query-pairs (string->utf8 "q=a+b%2Bc"))))
;; => "a+b+c"
```

The decoded bytes are returned as they are. Whether they are valid UTF-8 is
for you to check; `(uri easy)` checks it for you.

## Percent-decoding

`pct-decode` replaces each `%XX` with the byte it stands for:

```scheme
(utf8->string (pct-decode (string->utf8 "caf%C3%A9")))
;; => "café"
```

It never fails. A `%` that is not followed by two hex digits is just a `%`:

```scheme
(utf8->string (pct-decode (string->utf8 "100% %zz")))
;; => "100% %zz"
```

It decodes once, never twice. `%2541` is `%25` (a `%`) followed by `41`, so
it decodes to `%41`, not to `A`:

```scheme
(utf8->string (pct-decode (string->utf8 "%2541")))
;; => "%41"
```

## Percent-encoding

`pct-encode` takes the bytes and a test. It keeps each byte the test accepts
and writes every other byte as `%XX`, with uppercase hex:

```scheme
(utf8->string (pct-encode (string->utf8 "a b/c") unreserved-byte?))
;; => "a%20b%2Fc"
```

`unreserved-byte?` is the safe default. It accepts the bytes RFC 3986 calls
unreserved: letters, digits, `-`, `.`, `_` and `~`. Those mean the same
encoded or not, so they never need it. Pass your own test to keep more, such
as `/` in a path:

```scheme
(utf8->string
 (pct-encode (string->utf8 "a b/c")
             (lambda (b) (or (unreserved-byte? b) (= b (char->integer #\/))))))
;; => "a%20b/c"
```

Two small helpers read and write hex digits as bytes. `hex-digit-value`
gives a hex digit's value, or `#f`. `nibble->hex-digit` gives the uppercase
digit for a value from 0 to 15:

```scheme
(hex-digit-value (char->integer #\c))
;; => 12
(hex-digit-value (char->integer #\g))
;; => #f
(integer->char (nibble->hex-digit 12))
;; => #\C
```
