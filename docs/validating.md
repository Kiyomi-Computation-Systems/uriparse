# Validating

`uri-parse` finds the parts of a URI but does not check what is in them.
Validating checks every character against RFC 3986's grammar. uriparse keeps
the two apart, so you only pay for the checking you ask for.

Validation accepts exactly the URIs the RFC's grammar accepts, no more and no
fewer. The test suite holds it to that over every short input, the RFC's own
examples, and a hand-written set of hard cases.

## Parse and validate

`uri-parse-validate` takes the same arguments as `uri-parse`. It gives back
the same kind of result, but an invalid URI is an error:

```scheme
(uri-parse-ok? (uri-parse 'uri (string->utf8 "http://a/b c")))
;; => #t
(uri-parse-ok? (uri-parse-validate 'uri (string->utf8 "http://a/b c")))
;; => #f
(uri-parse-error-code (uri-parse-validate 'uri (string->utf8 "http://a/b c")))
;; => invalid-pchar
(uri-parse-error-offset (uri-parse-validate 'uri (string->utf8 "http://a/b c")))
;; => 10
```

The code names the rule of the RFC's grammar that failed: `pchar` is the rule
for a character in a path. The offset is the byte where it failed: the space.
When a URI has more than one fault, you get the leftmost.

[Errors](errors.md#the-byte-layer) lists every code.

## Validate a result you already have

A [collector](parsing.md#parse-in-chunks) gives you a result from
`uri-collect-finish!`. To validate it, pass it to
`uri-parse-result-validate`. Nothing is parsed twice:

```scheme
(import (rnrs) (uri collect))

(define c (make-uri-collector 'uri))
(define bytes (string->utf8 "http://a/%zz"))

(uri-collect-feed! c bytes 0 (bytevector-length bytes))

(define result (uri-parse-result-validate (uri-collect-finish! c)))
(display (uri-parse-error-code result)) (newline)
(display (uri-parse-error-offset result)) (newline)
```

```text
invalid-pct-encoded
9
```

A result that was already an error, or is valid, comes back unchanged.

## Check one part in place

Sometimes you have a part of a URI inside a bigger buffer, such as the path
in an HTTP request line. `validate-component`, in `(uri charset)`, checks it
where it is, without copying it out.

It takes the part's name (`'scheme`, `'path`, `'query` or `'fragment`), a
bytevector, and optionally a `start` and `end`. It returns two values: an
error code and an index, or `#f` and `#f` when the part is valid. The index
counts from `start`.

```scheme
(call-with-values
  (lambda () (validate-component 'path (string->utf8 "/a/b")))
  list)
;; => (#f #f)
(call-with-values
  (lambda () (validate-component 'query (string->utf8 "q=a b")))
  list)
;; => (invalid-query 3)
```

Here the path sits at bytes 4 to 9 of a request line. The bad `%` is at byte
6, which is index 2 from where the path starts:

```scheme
(call-with-values
  (lambda () (validate-component 'path (string->utf8 "GET /a%zz HTTP/1.1") 4 9))
  list)
;; => (invalid-pct-encoded 2)
```

Nothing outside `start` to `end` is read. A range that does not fit the
bytevector is an assertion violation, not a quiet clamp.

## Check an authority in place

The authority is `userinfo@host:port`. `validate-authority`, in `(uri host)`,
checks all of it: the userinfo, the host (a name, an IPv4 address, or an IPv6
or future address in brackets), and the port. Like `validate-component`, it
returns a code and an index, and takes an optional `start` and `end`:

```scheme
(call-with-values
  (lambda () (validate-authority (string->utf8 "user@[::1]:8080")))
  list)
;; => (#f #f)
(call-with-values
  (lambda () (validate-authority (string->utf8 "a:8x")))
  list)
;; => (invalid-port 3)
```

A fault inside `[...]` is reported at the `[`:

```scheme
(call-with-values
  (lambda () (validate-authority (string->utf8 "user@[::g]")))
  list)
;; => (invalid-ip-literal 5)
```

`999.1.1.1` is a valid authority. It is not an IPv4 address, since 999 is too
big, so the grammar reads it as a registered name, and a name may be digits
and dots:

```scheme
(call-with-values
  (lambda () (validate-authority (string->utf8 "999.1.1.1")))
  list)
;; => (#f #f)
```

`authority-host-span` finds the host inside an authority. It returns where the
host starts and ends:

```scheme
(call-with-values
  (lambda () (authority-host-span (string->utf8 "user@Example.com:80")))
  list)
;; => (5 16)
```

An IPv6 host keeps its brackets. `authority-host-span` never fails: it finds
the host by the delimiters alone, so validate first if you need a valid one.

## CONNECT targets

An HTTP `CONNECT` request names its target as a bare `host:port`, with no
scheme and no `//`. RFC 9112 calls this the authority-form. It is not a URI,
so the modes do not cover it. Two procedures do:

- `uri-parse-authority-form` splits it, leniently, like `uri-parse`.
- `uri-parse-authority-form-validate` also holds it to RFC 9112: no userinfo,
  a valid host, and a port that is really there.

Both return a parse result whose authority is the whole target:

```scheme
(utf8->string
 (uri-components-authority
  (uri-parse-components
   (uri-parse-authority-form-validate (string->utf8 "example.com:443")))))
;; => "example.com:443"
(uri-parse-error-code
 (uri-parse-authority-form-validate (string->utf8 "user@example.com:443")))
;; => userinfo-forbidden
(uri-parse-error-code
 (uri-parse-authority-form-validate (string->utf8 "example.com")))
;; => port-required
(uri-parse-error-code
 (uri-parse-authority-form (string->utf8 "example.com:443/x")))
;; => not-authority-form
```
