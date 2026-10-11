# Resolving and normalizing

This page is about the byte-level libraries. With strings, `(uri easy)`'s
`uri-resolve`, `uri-normalize` and `uri=?` do all of this for you: see
[URIs as strings](easy.md#resolving-normalizing-comparing).

## Resolving a reference

A relative reference, like `../g` in a web page, means "start from the
page's own URI, the base, and go there". Resolving works out the full URI.

`resolve-components`, in `(uri resolve)`, takes the base's parts and the
reference's parts and returns the target's parts. `recompose`, in
`(uri recompose)`, turns parts back into a URI.

```scheme
(import (rnrs) (uri collect) (uri resolve) (uri recompose))

(define (parts mode text)
  (uri-parse-components (uri-parse mode (string->utf8 text))))

(define base (parts 'uri "http://a/b/c/d;p?q"))

(define (resolve ref)
  (display ref) (display " -> ")
  (display (utf8->string (recompose (resolve-components base (parts 'uri-reference ref)))))
  (newline))

(for-each resolve '("g" "./g" "../g" "../../../g" "?y" "#s" "//g" "http:g"))
```

```text
g -> http://a/b/c/g
./g -> http://a/b/c/g
../g -> http://a/b/g
../../../g -> http://a/g
?y -> http://a/b/c/d;p?y
#s -> http://a/b/c/d;p?q#s
//g -> http://g
http:g -> http:g
```

These are rows from the RFC's own table of examples, and every row of that
table passes.

Resolution is strict: `http:g` has a scheme of its own, so it stays `http:g`.
The RFC also describes an older, looser reading that would give
`http://a/b/c/g`. uriparse does not support it.

The base must be absolute: it needs a scheme. Resolution does not normalize,
so `HTTP://A` stays as it is. Normalize first if you want both.

## Normalizing

Two URIs can look different and mean the same thing: `HTTP://Example.COM/%7e`
and `http://example.com/~` are one URI. Normalizing rewrites a URI into one
standard form, so equal URIs become equal bytes.

`normalize-components`, in `(uri normalize)`, does three things:

- lowercases the scheme and the host (not the userinfo, which can be
  case-sensitive);
- writes the hex of every `%XX` in uppercase: `%c3` becomes `%C3`;
- decodes a `%XX` that never needed encoding: letters, digits, `-`, `.`, `_`
  and `~`. `%7E` becomes `~`.

```scheme
(utf8->string
 (recompose
  (normalize-components
   (uri-parse-components
    (uri-parse 'uri (string->utf8 "HTTP://User@Example.COM/%7e/a%2fb"))))))
;; => "http://User@example.com/~/a%2Fb"
```

`%2F` stays encoded: it is a `/` that is data, not a separator, and decoding
it would change the path.

`pct-normalize` does the `%XX` part to any bytevector, and `normalize-scheme`
the lowercasing of a scheme:

```scheme
(utf8->string (pct-normalize (string->utf8 "%7e%2fA%41")))
;; => "~%2FAA"
(utf8->string (normalize-scheme (string->utf8 "HTTPS")))
;; => "https"
```

It does not remove `.` and `..` segments. Resolution does that. Nor does it
do anything that depends on the scheme, such as dropping `:80` from an
`http` URI.

### Normalize first, then resolve

Normalizing can make dot segments: `%2E%2E` decodes to `..`. Resolve a raw
reference and they survive as plain text. Normalize first, and resolution
removes them:

```scheme
(import (rnrs) (uri collect) (uri normalize) (uri resolve) (uri recompose))

(define (parts mode text)
  (uri-parse-components (uri-parse mode (string->utf8 text))))

(define base (parts 'uri "http://a/b/c"))
(define ref (parts 'uri-reference "%2E%2E/x"))

(define (show c) (display (utf8->string (recompose c))) (newline))

(show (resolve-components base ref))
(show (resolve-components base (normalize-components ref)))
```

```text
http://a/b/%2E%2E/x
http://a/x
```

`(uri easy)`'s `uri-normalize` does it all in that order.

## Paths

`(uri path)` has the two path steps resolution uses, for when you need them on
their own.

`remove-dot-segments` takes out `.` and `..`, the RFC's way:

```scheme
(utf8->string (remove-dot-segments (string->utf8 "/a/b/c/./../../g")))
;; => "/a/g"
(utf8->string (remove-dot-segments (string->utf8 "mid/content=5/../6")))
;; => "mid/6"
```

`merge` puts a relative path onto a base path. Its first argument says
whether the base has an authority: with one, an empty base path counts as
`/`.

```scheme
(utf8->string (merge #f (string->utf8 "/b/c/d") (string->utf8 "g")))
;; => "/b/c/g"
(utf8->string (merge #t (string->utf8 "") (string->utf8 "g")))
;; => "/g"
```

`remove-dot-segments-trace` returns every step of the algorithm, as the RFC
writes its worked examples. The test suite uses it to check the steps, not
just the answer.

## Recomposing

`recompose` writes the parts in order: `scheme:`, `//authority`, the path,
`?query`, `#fragment`. A delimiter is written when its part is present, even
if it is empty:

```scheme
(utf8->string
 (recompose (make-uri-components (string->utf8 "http") (string->utf8 "a")
                                 (string->utf8 "/p") (string->utf8 "") #f)))
;; => "http://a/p?"
(utf8->string
 (recompose (make-uri-components (string->utf8 "http") #f
                                 (string->utf8 "/p") #f #f)))
;; => "http:/p"
```

Recomposing gives back what was parsed, byte for byte. It does not repair
parts you put together into something ambiguous. One shape can come out of
resolution itself: against a base with no authority, `.//bar` resolves to the
path `//bar`, which `recompose` writes as `foo://bar`, a URI whose authority
is `bar`:

```scheme
(import (rnrs) (uri collect) (uri resolve) (uri recompose))

(define (parts mode text)
  (uri-parse-components (uri-parse mode (string->utf8 text))))

(display (utf8->string
          (recompose (resolve-components (parts 'uri "foo:/a")
                                         (parts 'uri-reference ".//bar")))))
(newline)
```

```text
foo://bar
```

`(uri easy)` guards against this. It writes that path as `/.//bar`, which
names the same path and parses back unchanged:

```scheme
(uri->string (uri-resolve "foo:/a" ".//bar"))
;; => "foo:/.//bar"
```
