# 0040: the easy layer is strings at the edge, one record, and a validated domain

Date: 2026-10-11
Status: accepted
Plan: [the easy-layer plan](../2026-10-11-easy-layer.md)
Supersedes: [0010](0010-the-core-is-bytevectors-and-the-ascii-fold-is-written-by-hand.md)
item 3 ("no string-level convenience layer in v0.1")
References:
[0008](0008-one-span-per-component-and-absent-is-not-empty.md) (absent is not
empty), [0020](0020-v01-normalizes-scheme-and-percent-and-defers-host-case.md)
(the normalize-before-resolve ordering),
[0022](0022-the-round-trip-property-is-a-one-step-parse-recompose-identity.md)
(the parse∘recompose identity),
[0041](0041-the-query-is-split-by-a-core-library-over-its-bytes-never-by-the-grammar.md),
[0042](0042-the-easy-layer-normalizes-dot-segments-and-guards-the-double-slash-shape.md)

## Context

Everything the library exports is built for a server on a hot path. You pick a
mode, feed bytevectors to a collector, read five fields that are each a
bytevector or `#f`, and tell absent from empty with predicates. A program that
handles a URI as a value, such as a config entry, a link, or an API client's
base URL, has a string and wants answers. It has no use for the collector, the
modes or the bytes, and today it must learn all three to read a host.

0010 item 3 declined a string layer for v0.1. Its reason: it would be two
surfaces to keep in agreement, where the second is the one no vector exercises.
That is a cost, not a prohibition. It is paid by running the committed vectors
through the second surface as well.

Three facts were measured on 2026-10-11 (Chez 10.4.1, tarm64osx) before this
was written:

- Chez's `utf8->string` replaces invalid bytes with U+FFFD. `(utf8->string
  #vu8(#xFF))` and `(utf8->string #vu8(#xFE))` are `string=?`. A layer that
  decoded `%FF` and `%FE` that way would read two different URIs as one.
- The low layer's error offsets count bytes. `uri-parse-validate 'relative-ref`
  on `"é:b"` fails `scheme-forbidden` at byte 2. A string user counts
  characters, and for them it is character 1.
- A host compared raw misses case variants: `(string=? "Example.COM"
  "example.com")` is `#f`. RFC 3986 §3.2.2 says the host is case-insensitive.

## Decision

1. **The layer is `(uri easy)`, in `src/uri/easy.sls`.** Every export is a
   composition of exports that already exist. The low layer's libraries and
   signatures do not change, and nothing below the easy layer imports it. The
   name has two parts, like `(uri collect)`. A one-part `(uri)` resolves to
   different files across implementations (Racket appends `/main`, Chez looks
   for `uri.sls`).

2. **One opaque, immutable record, `Uri`, over validated `uri-components`.**
   There are three parsers, one per mode: `string->uri` (`uri`),
   `string->uri-reference` and `string->relative-ref`. Each runs
   `uri-parse-validate`. There is no lenient easy parse, because lenient
   splitting is the server's tool and stays in `(uri collect)`. Every `Uri`
   holds components that passed validation. So every raw field is ASCII,
   `utf8->string` on one is exact, and U+FFFD cannot appear.

3. **Accessors return the raw text, except `uri-scheme` and `uri-host`.** The
   record and `uri->string` hold the input as written, so `(uri->string
   (string->uri-reference s))` is `s` for every valid `s`. That is 0022's
   identity, reached through strings. `uri-path`, `uri-query`, `uri-fragment`,
   `uri-authority` and `uri-userinfo` are raw. `uri-scheme` and `uri-host` return
   their §6.2.2-normalized form: lowercase, with unreserved `%XX` decoded.
   RFC 3986 makes both case-insensitive (§3.1, §3.2.2), and comparison is their
   commonest use, where a raw `Example.COM` slips past `(string=? (uri-host u)
   "example.com")`. Userinfo is case-sensitive and stays raw. Lowercasing at
   parse, as Python and WHATWG do, was rejected because it breaks the identity
   for uppercase input.

4. **Absent is not empty, in strings.** `#f` is absent; `""` is present and
   empty. This is 0008 carried to the edge. One stated exception: `uri-port`
   returns a `Nat` or `#f`, and an empty port (`http://a:`) reads `#f`, because
   it has no numeric value and §3.2.3 tells producers to omit it. The raw
   authority keeps the `:`.

5. **Decoding is explicit, splits before it decodes, and is strict UTF-8.**
   Every decoded reading (`uri-path-segments`, `uri-query-pairs`,
   `uri-form-pairs`, `uri-decode`) splits the raw text first and percent-decodes
   each piece after. It then checks UTF-8 by hand, over bytes, and raises
   `invalid-utf-8` on overlongs, surrogates, code points above U+10FFFF and
   truncated sequences. U+FFFD is never produced. `(rnrs unicode)` stays
   unreachable, as 0010 items 1 and 4 require.

6. **Bad input raises `&uri-error`; misuse raises an assertion.** `&uri-error`
   is a subtype of `&error`, and carries a reason symbol, a *character* offset
   and the input. It is raised together with `&who` and `&message`, so an
   unhandled one prints usefully. The low layer's byte offset is converted by
   counting UTF-8 lead bytes before it. The accessor is `uri-error-reason`, not
   `uri-error-code`: `(uri vocabulary)` already exports `uri-error-code?`, a
   predicate over symbols, and the two would sit one `?` apart in any program
   importing both. The reasons are exactly the union of the scanner's, `(uri
   charset)`'s and `(uri host)`'s codes, plus `invalid-utf-8`,
   `base-not-absolute` and `ambiguous-components`. They are exported as
   `uri-error-reasons`, a list written out rather than derived from the low
   layer's lists. A test asserts that equality, so a new low-layer code reddens
   it instead of leaking out undocumented; a derived list would pass it by
   construction. A
   non-string argument is a programmer's mistake and stays an
   `assertion-violation`.

7. **`uri-resolve` and `uri=?` accept a `Uri` or a `String` in each position.**
   A string base is parsed with `string->uri` (it must be absolute, §5.2.1), and
   every other string with `string->uri-reference`. The mode is fixed per
   position, so nothing is guessed.

## What this rules out

- **Returning `#f` on bad input.** It drops the reason and the position.
  `uri-string?` answers the yes/no question without a `guard`.
- **Decoded-by-default accessors.** A decoded `%2F` is a `/` that is not a
  separator. Decoding before splitting is the ordering trap 0020 names, in a new
  place.
- **`utf8->string` on decoded bytes.** See the first measured fact.
- **Lenient easy parsing**, and **performance as a goal.** The layer allocates
  freely and validates on every parse. A server keeps the collector.

## Consequences

- 0010 item 3 is superseded, and 0010 gains a header line saying so. Items 1, 2,
  4 and 5 stand: the core stays bytevectors, and `utf8->string` stays at the
  edge, which is where `(uri easy)` sits.
- 0010's objection is answered by evidence, not argument. All 42 §5.4 rows run
  through `uri-resolve` as strings, and the round-trip identity runs over every
  committed corpus input that validates.
- The record's invariant (every `Uri` holds validated components) must survive
  `uri-resolve`, `uri-normalize` and `components->uri`. 0042 is the record of
  where RFC 3986's own algorithms break it and what the easy layer does about it.
