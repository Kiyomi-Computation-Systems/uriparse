# 0001: the project is chez-uri, and the boundary against chez-httparse

Date: 2026-09-18
Status: accepted, then **amended in part by [0041](0041-the-query-is-split-by-a-core-library-over-its-bytes-never-by-the-grammar.md)**
Plan: [the brief](../2026-09-18-chez-uri-project-brief.md),
[the design](../2026-09-18-chez-uri-design.md)

> **Amendment (0041).** The out-of-scope bullet on
> `application/x-www-form-urlencoded` stands for the grammar: the scanner, the
> `uri-components` query and every low-layer function keep the RFC 3986 query
> opaque. 0041 adds `(uri query)`, a separate core library that splits an
> already-isolated query into key/value pairs. That is the "clearly separate
> module" the bullet allows. It does not implement WHATWG's parser.

## Context

The repository is `uriparse`; the sibling is `chez-httparse` and already
contains a URL machine. A reader who finds both will ask why this is not a
module over there, and the answer has to be written down once rather than
re-argued per pull request.

There is also a naming trap. RFC 3986's term is **URI**. "URL" appears in that
document informally and is never defined by its grammar; it is the WHATWG
standard's term, and WHATWG's parser gives different answers on ordinary
inputs. A project that mixes the two names will eventually mix the two
behaviours, and parser differentials between URI and URL readings are a
security class, not a curiosity.

## Decision

1. **The project is `chez-uri`.** Libraries are `(uri …)`; machine tokens use
   the bare stem `uri`; product and prose contexts use `chez-uri`. The
   repository keeps the name `uriparse` — the remote and LICENSE already carry
   it, and nothing functional derives from it.

2. **"URL" is reserved for the WHATWG thing this project is not.** It appears
   in no export, no span name, no error code and no library name. Where it must
   be named at all, it is named to say we do not implement it.

3. **The normative reference is RFC 3986 alone**, which is
   [0003](0003-the-normative-reference-is-rfc-3986.md)'s subject.

4. **This is a separate repository, and the reasons are not preference.**
   - `chez-httparse`'s thesis is llhttp conformance against a vendored corpus,
     byte for byte. "Implement RFC 3986" is a different thesis with a different
     normative reference and a different corpus, and its ratchet would dilute
     the other's.
   - The URL machine already in `chez-httparse` is not a precedent for hosting
     this one. `(httparse url-grammar)`'s `url-subgraph` is spliced into the
     HTTP grammar to validate the request target; it is load-bearing and cannot
     move.
   - `chez-httparse` decision 0006 sends general capability upstream to
     `byte-machine` and keeps HTTP-specific work local. An RFC 3986 library is
     neither, which makes it a **peer consumer** of `byte-machine` — the same
     position `chez-httparse` occupies.
   - Grammar reuse is zero. llhttp's `URL_CHAR` is documented upstream as
     explicitly not a standard; its host span swallows userinfo and port. Byte-set
     helpers are the whole overlap.
   - CI is one Linux cell on a tight budget
     ([0006](0006-ci-covers-the-linux-cell-alone.md)). Co-located, every HTTP
     pull request pays for URI lanes it cannot affect.

5. **The harness is copied, not factored out.** `chez-httparse`'s
   `test/common/`, `test/support/harness/` and CMake lanes are copied verbatim
   and then adapted. The second copy is the only place both can be seen at once,
   which is the only way to tell what is generic from what is llhttp-shaped —
   `trace-format`, for one, renders llhttp's trace text and is not generic at
   all. If a third consumer appears, `byte-machine` is the natural home.

## Out of scope, and it stays out

- **WHATWG URL.** A separate machine with a separate corpus if ever wanted, not
  a mode of this one.
- **RFC 3987 IRIs**, IDNA, Punycode, Unicode mapping tables.
- **`application/x-www-form-urlencoded`** query splitting. RFC 3986's `query` is
  opaque; `key=value&…` is an HTML convention. `chez-http-server` will want it;
  it belongs in a clearly separate module or in the server, never in this
  grammar.
- **URI Templates** (RFC 6570), scheme-specific semantics, any registry of known
  schemes.
