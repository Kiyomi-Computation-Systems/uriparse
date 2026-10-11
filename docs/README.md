# uriparse

uriparse reads URIs. Give it `https://example.com/a?q=1#top` and it tells
you the scheme, the host, the path, the query and the fragment. It can also
check a URI against the rules, resolve a relative link against a base, and
normalize two URIs so you can compare them.

It follows [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986), the standard
that says what a URI is. It is portable R6RS Scheme, tested on Chez Scheme.

## A taste

```scheme
(uri-host (string->uri "https://Example.COM:8443/a/b?q=1"))
;; => "example.com"
(uri-port (string->uri "https://Example.COM:8443/a/b?q=1"))
;; => 8443
(uri-query-pairs (string->uri "https://example.com/?q=a%26b&tag"))
;; => (("q" . "a&b") ("tag" . #f))
(uri->string (uri-resolve "http://a/b/c/d" "../x?y"))
;; => "http://a/b/x?y"
```

`;; =>` shows what the line above it returns. Every example in these pages
is run by the test suite, so what they show is what you get.

## Two layers

uriparse has two ways in. Pick the one that fits your data.

- **Strings: `(uri easy)`.** You have a URI in a string and want answers in
  strings. It checks everything and is the simplest to use. Start here.
- **Bytes: `(uri collect)` and friends.** You are a server reading URIs
  straight off the network, as bytes. These libraries take bytevectors,
  accept input in pieces, reuse their memory, and can check a slice of your
  own buffer without copying it.

You can cross between them: `uri->components` and `components->uri` turn
one into the other.

## Read next

- [Installing](installing.md): get the code and run a first program.
- [URIs as strings](easy.md): parse, read, decode, resolve and compare with
  `(uri easy)`.
- [Parsing bytes](parsing.md): split a URI held as bytes, all at once or
  in chunks.
- [Validating](validating.md): check a URI, or one part of it, against the
  RFC's grammar.
- [Resolving and normalizing](resolving.md): relative links, normal forms
  and turning parts back into a URI.
- [Queries and percent-encoding](queries.md): `key=value` pairs and `%XX`.
- [Errors](errors.md): every error, what it means, and where it points.
- [API reference](reference.md): every library and every binding.

These pages are generated from the Markdown in [docs/](../docs).
