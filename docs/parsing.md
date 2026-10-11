# Parsing bytes

A server gets a URI as bytes, straight off the network. `(uri collect)`
parses those bytes without turning them into a string first. It can take them
all at once or a chunk at a time, and it can reuse its memory for the next
request.

## Parse once

`uri-parse` takes a mode and a bytevector, and gives back a result:

```scheme
(import (rnrs) (uri collect) (uri components))

(define result
  (uri-parse 'uri (string->utf8 "https://example.com/path?q=1#top")))

;; Print one part, or <absent> when the URI has none.
(define (show name bv)
  (display name) (display ": ")
  (display (if bv (utf8->string bv) "<absent>"))
  (newline))

(when (uri-parse-ok? result)
  (let ((c (uri-parse-components result)))
    (show "scheme"    (uri-components-scheme c))
    (show "authority" (uri-components-authority c))
    (show "path"      (uri-components-path c))
    (show "query"     (uri-components-query c))
    (show "fragment"  (uri-components-fragment c))))
```

```text
scheme: https
authority: example.com
path: /path
query: q=1
fragment: top
```

The parts are bytevectors. `string->utf8` and `utf8->string` cross between
bytes and strings.

### Three modes

The mode says what kind of URI you expect:

| Mode             | Accepts                                   | Example        |
|------------------|-------------------------------------------|----------------|
| `'uri`           | an absolute URI: it must have a scheme    | `http://a/b`   |
| `'relative-ref`  | a relative reference: no scheme allowed   | `../b?c`       |
| `'uri-reference` | either one                                | both of those  |

```scheme
(uri-parse-ok? (uri-parse 'uri (string->utf8 "../b")))
;; => #f
(uri-parse-ok? (uri-parse 'uri-reference (string->utf8 "../b")))
;; => #t
```

## The result

A result either worked or it did not. `uri-parse-ok?` tells you which.

When it worked, `uri-parse-components` gives the five parts. When it did not,
`uri-parse-error-code` says what went wrong and `uri-parse-error-offset` says
where, as a byte index into your input:

```scheme
(uri-parse-error-code (uri-parse 'uri (string->utf8 "a/b")))
;; => scheme-required
(uri-parse-error-offset (uri-parse 'uri (string->utf8 "a/b")))
;; => 1
(uri-parse-components (uri-parse 'uri (string->utf8 "a/b")))
;; => #f
```

`uri-parse-component-offset` tells you where each part starts in your input,
which is handy for error messages of your own:

```scheme
(uri-parse-component-offset (uri-parse 'uri (string->utf8 "http://a/b?q")) 'query)
;; => 11
(uri-parse-component-offset (uri-parse 'uri (string->utf8 "http://a/b")) 'query)
;; => #f
```

## The five parts

A parse splits a URI into the five parts RFC 3986 names:

```text
  https://user@example.com:8443/a/b?q=1#top
  \___/   \__________________/\__/ \_/ \_/
 scheme        authority      path query fragment
```

Each part is a bytevector, or `#f`. **`#f` means absent. An empty bytevector
means present but empty.** `http://a` has no query; `http://a?` has an empty
one. They are different URIs, and uriparse never mixes them up:

```scheme
(uri-components-query
 (uri-parse-components (uri-parse 'uri (string->utf8 "http://a"))))
;; => #f
(uri-components-query
 (uri-parse-components (uri-parse 'uri (string->utf8 "http://a?"))))
;; => #vu8()
```

Four predicates ask the question for you:

```scheme
(uri-component-absent? #f)
;; => #t
(uri-component-present? #vu8())
;; => #t
(uri-component-empty? #f)
;; => #f
(uri-component-present-nonempty? (string->utf8 "q=1"))
;; => #t
```

The path is never absent. It is empty when there is none:

```scheme
(uri-components-path
 (uri-parse-components (uri-parse 'uri (string->utf8 "http://a"))))
;; => #vu8()
```

The authority stays in one piece: `user@example.com:8443`.
[Validating](validating.md#check-an-authority-in-place) shows how to find the
host inside it, and `(uri easy)` splits it for you.

You can build parts yourself with `make-uri-components`, and compare two sets
with `uri-components=?`, which keeps absent and empty apart.

## Lenient on purpose

`uri-parse` finds the parts. It does not check their characters, so this
parses, space and all:

```scheme
(uri-parse-ok? (uri-parse 'uri (string->utf8 "http://a/b c")))
;; => #t
```

That keeps parsing fast and lets you decide how strict to be. When you need a
valid URI, use `uri-parse-validate` instead. [Validating](validating.md)
covers it.

## Parse in chunks

Bytes from a socket arrive in pieces. A collector takes them as they come:

1. `make-uri-collector` makes one, for a mode.
2. `uri-collect-feed!` gives it the bytes from `start` to `end` of a
   bytevector. Call it once per chunk.
3. `uri-collect-finish!` says the input is over, and returns the result.

```scheme
(import (rnrs) (uri collect) (uri components))

(define c (make-uri-collector 'uri))
(define chunk-1 (string->utf8 "https://exam"))
(define chunk-2 (string->utf8 "ple.com/a?q=1"))

(uri-collect-feed! c chunk-1 0 (bytevector-length chunk-1))
(uri-collect-feed! c chunk-2 0 (bytevector-length chunk-2))

(define result (uri-collect-finish! c))
(display (utf8->string (uri-components-authority (uri-parse-components result))))
(newline)
```

```text
example.com
```

A chunk can end anywhere, even in the middle of a part. The result is the
same however the input was split.

## Reuse a collector

`uri-collector-reset!` puts a collector back to new, keeping its mode. A
server can keep one collector per connection and reset it for each request,
instead of making a new one each time. Resetting reallocates nothing.

```scheme
(import (rnrs) (uri collect) (uri components))

(define c (make-uri-collector 'uri))

(define (parse! text)
  (let ((bytes (string->utf8 text)))
    (uri-collector-reset! c)
    (uri-collect-feed! c bytes 0 (bytevector-length bytes))
    (uri-collect-finish! c)))

(for-each
 (lambda (text)
   (let ((r (parse! text)))
     (display (utf8->string (uri-components-path (uri-parse-components r))))
     (newline)))
 '("http://a/first" "http://b/second"))
```

```text
/first
/second
```

To check a collector's result, pass it to `uri-parse-result-validate`. See
[Validating](validating.md#validate-a-result-you-already-have).

## Under the hood

The scanner that splits a URI is generated from a grammar by
[byte-machine](https://github.com/Kiyomi-Computation-Systems/byte-machine).
`(uri collect)` drives it for you. If you embed the scanner yourself, with
your own callbacks, `(generated uri-scanner)` exports the machine and
`(uri vocabulary)` names its modes, spans, callbacks and error codes. The
[API reference](reference.md#the-scanner) lists them.
