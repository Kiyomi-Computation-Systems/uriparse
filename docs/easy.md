# URIs as strings

`(uri easy)` takes a URI as a string and gives you back a record you can ask
questions. The answers are strings, numbers and lists.

```scheme
(import (rnrs) (uri easy))

(define u (string->uri "https://user@Example.COM:8443/a/caf%C3%A9?q=a%26b&tag#top"))

(for-each (lambda (x) (write x) (newline))
          (list (uri-scheme u)
                (uri-host u)
                (uri-port u)
                (uri-path u)
                (uri-path-segments u)
                (uri-query-pairs u)
                (uri-fragment u)))
```

```text
"https"
"example.com"
8443
"/a/caf%C3%A9"
("a" "café")
(("q" . "a&b") ("tag" . #f))
"top"
```

## Parsing

Three procedures turn a string into a URI record. They differ in what they
accept:

| Procedure               | Accepts                                      |
|-------------------------|----------------------------------------------|
| `string->uri`           | an absolute URI: it must have a scheme       |
| `string->uri-reference` | an absolute URI or a relative reference      |
| `string->relative-ref`  | a relative reference only: no scheme allowed |

```scheme
(uri-path (string->uri-reference "../a/b"))
;; => "../a/b"
(uri-scheme (string->uri-reference "../a/b"))
;; => #f
```

All three check the whole URI against RFC 3986. A bad one raises a
`&uri-error`. It says what is wrong (the reason), where (the offset, in
characters), and in which string:

```scheme
(guard (e ((uri-error? e)
           (list (uri-error-reason e) (uri-error-offset e) (uri-error-input e))))
  (string->uri "http://a b/"))
;; => (invalid-reg-name 8 "http://a b/")
(guard (e ((uri-error? e) (uri-error-reason e)))
  (string->uri "/just/a/path"))
;; => scheme-required
```

To ask without catching anything, use `uri-string?`. It takes the same three
modes, as symbols, and defaults to `'uri`:

```scheme
(uri-string? "http://a b/")
;; => #f
(uri-string? "../a" 'uri-reference)
;; => #t
```

[Errors](errors.md#the-easy-layer) lists every reason.

### Only ASCII

RFC 3986 allows only ASCII characters in a URI, so a string with `é` in it is
refused. Encode text before you put it in a URI:

```scheme
(uri-string? "http://a/café")
;; => #f
(uri-encode "café")
;; => "caf%C3%A9"
(uri-string? (string-append "http://a/" (uri-encode "café")))
;; => #t
```

## Reading

Each accessor returns the part as it was written, so nothing is lost:

```scheme
(uri-path (string->uri "http://a/x%20y/Z"))
;; => "/x%20y/Z"
(uri-userinfo (string->uri "http://Alice@a/"))
;; => "Alice"
(uri-authority (string->uri "http://Alice@a:80/"))
;; => "Alice@a:80"
```

There are two exceptions. `uri-scheme` and `uri-host` come back in lowercase,
with needless `%XX` decoded, because you mostly read them to compare them:

```scheme
(uri-scheme (string->uri "HTTP://a"))
;; => "http"
(uri-host (string->uri "http://Ex%61mple.COM/"))
;; => "example.com"
(uri-host (string->uri "http://[::1]:8080/"))
;; => "[::1]"
```

### Missing or empty

`#f` means the part is missing. `""` means it is there, but empty. They are
different URIs:

```scheme
(uri-query (string->uri "http://a"))
;; => #f
(uri-query (string->uri "http://a?"))
;; => ""
(uri-fragment (string->uri "http://a#"))
;; => ""
```

The path is never missing, only empty:

```scheme
(uri-path (string->uri "http://a"))
;; => ""
```

`uri-port` is a number, or `#f` when there is no port. An empty port, as in
`http://a:`, is also `#f`:

```scheme
(uri-port (string->uri "http://a:080/"))
;; => 80
(uri-port (string->uri "http://a:/"))
;; => #f
```

## Decoding

`uri-path-segments`, `uri-query-pairs` and `uri-form-pairs` split first and
decode after. So an encoded `/` or `&` stays inside its piece instead of
splitting it:

```scheme
(uri-path-segments (string->uri "http://a/x%2Fy/z"))
;; => ("x/y" "z")
(uri-query-pairs (string->uri "http://a?k=a%26b&n=1"))
;; => (("k" . "a&b") ("n" . "1"))
```

A key with no `=` gets the value `#f`. A key with `=` and nothing after gets
`""`:

```scheme
(uri-query-pairs (string->uri "http://a?flag&empty="))
;; => (("flag" . #f) ("empty" . ""))
```

`uri-form-pairs` also reads `+` as a space, the way HTML forms write it.
`uri-query-pairs` leaves `+` alone:

```scheme
(uri-form-pairs (string->uri "http://a?q=a+b&x=%2B"))
;; => (("q" . "a b") ("x" . "+"))
(uri-query-pairs (string->uri "http://a?q=a+b"))
;; => (("q" . "a+b"))
```

`uri-decode` decodes any string. Decoding must give valid UTF-8. If it does
not, you get an error, never a `�`:

```scheme
(uri-decode "caf%C3%A9")
;; => "café"
(guard (e ((uri-error? e) (uri-error-reason e)))
  (uri-decode "%FF"))
;; => invalid-utf-8
```

[Queries and percent-encoding](queries.md) has the full rules.

## Resolving, normalizing, comparing

`uri-resolve` follows a relative link from a base, the way a browser does.
Either argument can be a string or a URI record:

```scheme
(uri->string (uri-resolve "http://a/b/c/d" "../x?y"))
;; => "http://a/b/x?y"
(uri->string (uri-resolve "http://a/b/c/d" "//other/z"))
;; => "http://other/z"
```

`uri-normalize` lowercases the scheme and host, tidies percent-encoding, and
removes `.` and `..` segments:

```scheme
(uri->string (uri-normalize (string->uri "HTTP://A/%7Ex/./y/../z")))
;; => "http://a/~x/z"
```

`uri=?` compares two URIs after normalizing both:

```scheme
(uri=? "HTTP://a/%7Euser" "http://a/~user")
;; => #t
(uri=? "http://a" "http://a?")
;; => #f
```

`uri->string` gives a record back as a string. A parsed URI comes back
exactly as written:

```scheme
(uri->string (string->uri "HTTP://A/%7e"))
;; => "HTTP://A/%7e"
```

[Resolving and normalizing](resolving.md) explains what each step does.

## Crossing to the byte layer

`uri->components` gives the five parts as bytevectors, the form the
byte-level libraries use. `components->uri` goes the other way, and checks
the parts as it does:

```scheme
(uri->string (components->uri (uri->components (string->uri "http://a/b?c"))))
;; => "http://a/b?c"
```

`(uri easy)` checks everything and allocates freely. A server reading URIs off
the wire should use [the byte layer](parsing.md) instead.
