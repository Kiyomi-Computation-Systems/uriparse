# chez-uri: the easy layer — strings in, a record out

Date: 2026-10-11
Status: done; released as v0.7.0 (slices ⓪ to ④ merged as #37 to #41)
Target release: v0.7.0 (additive; nothing existing changes shape)

## Goal

A user who has a URI as a string should get structured answers from it without
learning collectors, modes, bytevectors, or the absent/empty predicates:

```scheme
(import (rnrs) (uri easy))

(define u (string->uri "https://user@Example.com:8443/a/b%20c?q=1&r=two#top"))

(uri-scheme u)          ; "https"
(uri-userinfo u)        ; "user"
(uri-host u)            ; "example.com"   normalized: hosts are case-insensitive
(uri-port u)            ; 8443
(uri-path u)            ; "/a/b%20c"
(uri-path-segments u)   ; ("a" "b c")
(uri-query-pairs u)     ; (("q" . "1") ("r" . "two"))
(uri-fragment u)        ; "top"

(uri->string (uri-resolve u "../x?y"))   ; "https://user@Example.com:8443/x?y"
(uri->string (uri-normalize u))          ; "https://user@example.com:8443/a/b%20c?q=1&r=two#top"
(uri=? "HTTP://a/%7Euser" "http://a/~user")   ; #t
```

**Who it is for:** any program that handles URIs as values, such as config,
links, or API clients. **Who it is not for:** chez-http-server and anything
else on a per-request hot path. Those keep using `(uri collect)`, ranged
validation and the reusable collector. The easy layer allocates freely and
validates every time.

**A layer, not a replacement.** Every easy function is a composition of exports
that already exist. The low layer's libraries and signatures do not change. The
one new core library, `(uri query)`, is new surface, not a change to old surface.

## What it wraps

| easy function | built from |
|---|---|
| `string->uri`, `string->uri-reference`, `string->relative-ref` | `uri-parse-validate` in mode `uri` / `uri-reference` / `relative-ref` |
| `uri-scheme` | `normalize-scheme` |
| `uri-host` | `authority-host-span` over the authority `normalize-components` returns |
| `uri-userinfo`, `uri-port` | `(uri host)` `authority-host-span` over the raw authority |
| `uri-path-segments` | split on `/`, then `pct-decode` per segment |
| `uri-query-pairs`, `uri-form-pairs` | new `(uri query)` `query-pairs` / `form-pairs` |
| `uri-decode`, `uri-encode` | `pct-decode` / `pct-encode` + `unreserved-byte?`, and a strict UTF-8 check |
| `uri->string` | `recompose` |
| `uri-resolve` | `resolve-components` |
| `uri-normalize`, `uri=?` | `normalize-components`, `remove-dot-segments`, `uri-components=?` |
| `uri->components`, `components->uri` | the `uri-components` record itself |

## The rules

These are the invariants. Each one is checked by a test, not just stated.

1. **The domain is validated.** Every `Uri` value holds components that passed
   `uri-parse-validate` in the mode that built it. A lenient easy parse does not
   exist; lenient splitting stays in `(uri collect)`. Two consequences carry
   the rest of the design:
   - Every raw field is ASCII (RFC 3986 admits no other octet), so
     `utf8->string` on a raw field is exact. U+FFFD cannot appear.
   - `uri-normalize` is idempotent. Decision 0022 item 2 showed idempotence is
     false over the lenient domain (`%%341`). Every `%` here begins a valid
     triplet, so that counterexample cannot occur, and a lane asserts the property.

2. **Raw by default, decoded on request.** The record holds the text as
   written, and so does `uri->string`. `(uri->string (string->uri-reference s))`
   is `s` for every valid `s`, which is decision 0022's identity reached through
   strings. Accessors return raw text: `uri-path` is `"/a/b%20c"`, not
   `"/a/b c"`. Decoding is a separate, explicit call. A decoded `%2F` is a `/`
   that is not a path separator, so decoding cannot be the default.

   **Two exceptions: `uri-scheme` and `uri-host` return their §6.2.2-normalized
   form.** That means lowercase, with unreserved `%XX` decoded. RFC 3986 makes
   both case-insensitive (§3.1, §3.2.2), so the fold throws away nothing the RFC
   treats as meaningful. The commonest use of either is a comparison, and a raw
   accessor makes `(string=? (uri-host u) "example.com")` miss `Example.COM`.
   That miss is an allowlist or denylist bypass, not just an inconvenience.
   `uri-authority` and `uri-userinfo` stay raw (userinfo is case-sensitive), so
   `uri-host` and `uri-authority` can differ in case, and the docs say so.

3. **Absent is not empty, in strings too.** `#f` is absent; `""` is present and
   empty (decision 0008, carried to the edge). `(uri-query (string->uri "http://a"))`
   is `#f`; `(uri-query (string->uri "http://a?"))` is `""`. One stated
   exception: `uri-port`, below.

4. **Split before decode.** A query is split on `&` and `=`, and a path on `/`,
   *before* percent-decoding. Decoding first turns `%26` into a live `&`:

   ```
   q=a%26b&r=1   split, then decode  →  (("q" . "a&b") ("r" . "1"))       right
                 decode, then split  →  (("q" . "a") ("b" . #f) ("r" . "1"))  wrong
   ```

   This is the same ordering trap as normalize-before-resolve (decision 0020).

5. **Decoding is strict UTF-8, never U+FFFD.** Chez's `utf8->string` replaces
   invalid bytes with U+FFFD, so `%FF` and `%FE` would decode to *equal*
   strings (measured 2026-10-11, Chez 10.4.1). That is a parser differential.
   Every decoding function checks UTF-8 by hand, over bytes, and raises
   `invalid-utf-8` on overlongs, surrogates, code points above U+10FFFF and
   truncated sequences. `(rnrs unicode)` stays unreachable, as decision 0010
   requires.

6. **Bad input raises a condition; misuse is an assertion.** An invalid URI
   raises `&uri-error` (a subtype of `&error`), which carries a reason symbol,
   a *character* offset into the input, and the input. Passing a non-string is a
   programmer error and stays an `assertion-violation`.

7. **Offsets are characters, not bytes.** The low layer reports byte offsets
   into UTF-8. A string user counts characters. They differ: measured
   2026-10-11, `relative-ref "é:b"` fails `scheme-forbidden` at byte 2, which is
   character 1. The easy layer converts by counting UTF-8 lead bytes before the
   offset.

8. **Nothing renders to a different URI.** Every `Uri` the API returns must
   satisfy: `(string->uri-reference (uri->string u))` has components equal to
   `u`'s. RFC 3986's own algorithms break this in one reachable case (below), and
   the easy layer guards it.

## The API: `(uri easy)`

```
;; Uri: an opaque, immutable record over validated `uri-components`.
;; Mode = (U 'uri 'uri-reference 'relative-ref)

;; --- parsing ---
string->uri           : String -> Uri          ; absolute: a scheme is required
string->uri-reference : String -> Uri          ; absolute or relative
string->relative-ref  : String -> Uri          ; relative only
uri-string?           : String [Mode] -> Boolean   ; Mode defaults to 'uri
uri?                  : Any -> Boolean

;; --- fields (raw, except scheme and host: §6.2.2-normalized) ---
uri-scheme            : Uri -> (Option String)
uri-authority         : Uri -> (Option String)
uri-userinfo          : Uri -> (Option String)
uri-host              : Uri -> (Option String)
uri-port              : Uri -> (Option Nat)
uri-path              : Uri -> String
uri-query             : Uri -> (Option String)
uri-fragment          : Uri -> (Option String)

;; --- decoded readings ---
uri-path-segments     : Uri -> (Listof String)
uri-query-pairs       : Uri -> (Listof (Pairof String (Option String)))
uri-form-pairs        : Uri -> (Listof (Pairof String (Option String)))
uri-decode            : String -> String
uri-encode            : String -> String

;; --- render, resolve, normalize, compare ---
uri->string           : Uri -> String
uri-resolve           : (U Uri String) (U Uri String) -> Uri    ; base, reference
uri-normalize         : Uri -> Uri
uri=?                 : (U Uri String) (U Uri String) -> Boolean

;; --- the way down to the low layer ---
uri->components       : Uri -> Components
components->uri       : Components -> Uri

;; --- errors ---
uri-error?            : Any -> Boolean
uri-error-reason      : UriError -> Symbol
uri-error-offset      : UriError -> Nat
uri-error-input       : UriError -> String
uri-error-reasons     : (Listof Symbol)    ; every reason above, written out
```

The accessor is `uri-error-reason`, not `uri-error-code`, because `(uri
vocabulary)` already exports `uri-error-code?` as a predicate over symbols. Two
names one `?` apart, meaning different things, would collide in any program that
imports both.

### Field semantics

| accessor | absent (`#f`) when | present-empty when | notes |
|---|---|---|---|
| `uri-scheme` | a relative reference | never (the grammar requires 1+ chars) | lowercase: `HTTP:` reads `"http"` |
| `uri-authority` | no `//` | `file:///x` | raw `userinfo@host:port`, case as written |
| `uri-userinfo` | no `@` before the host | `http://@a` | raw, case as written. Bracket-aware via `authority-host-span` |
| `uri-host` | no authority | `file:///x` | normalized: `Ex%41mple.COM` reads `"example.com"`, `[::A]` reads `"[::a]"`. A triplet that is not unreserved keeps its uppercase hex: `%C3%A9.COM` reads `"%C3%A9.com"`. An IP-literal keeps its `[` `]`, because they are part of RFC 3986's `host` production. `mailto:a@b` has *no* host: `a@b` is its path |
| `uri-port` | no port **or an empty port** (`http://a:`) | — | an integer. `080` reads 80. No range check: RFC 3986 `port = *DIGIT` has none, and 65535 is a TCP fact |
| `uri-path` | never | `http://a` | always a string |
| `uri-query` | no `?` | `http://a?` | raw |
| `uri-fragment` | no `#` | `http://a#` | raw |

**The `uri-port` exception to rule 3.** An empty port has no numeric value,
and RFC 3986 §3.2.3 tells producers to omit it. `uri-port` reads it as `#f`.
The raw authority keeps the `:`, so rendering still round-trips. A caller who
needs to tell the two apart has `uri-authority`.

**`uri-path-segments`** splits the raw path on `/`, drops the one empty segment
before a leading `/`, and decodes each segment: `""` → `()`, `"/"` → `("")`,
`"/a/b/"` → `("a" "b" "")`, `"a/b"` → `("a" "b")`, `"/a%2Fb"` → `("a/b")`.
Whether the path was rooted is visible in `uri-path`, not in the list. A path
the guard escaped (`/.//bar`, no authority) reads as the path it names,
`("" "bar")`: its `.` is the escape, not a segment.

**`uri-query-pairs` / `uri-form-pairs`** return `()` for an absent query. The
only difference between them is `+`: literal in the first, a space in the second.

**`uri-decode` / `uri-encode`.** `uri-encode` escapes every octet of the
string's UTF-8 except §2.3 unreserved, so it is safe in any component. For
every string `s`, `(uri-decode (uri-encode s))` is `s`. Non-ASCII input to the
*parsers* is rejected (IRIs are out of scope, decision 0001). `uri-encode` is
how a user gets from `café` to `caf%C3%A9`.

### Resolve, normalize, compare

- **`uri-resolve`** is strict §5.2.2 (as `(uri resolve)` is). Strings are parsed
  as URI references. A base with no scheme raises `base-not-absolute` (§5.2.1),
  whether it came as a string or a `Uri`, and the base is judged before the
  reference is read. It does **not** normalize. The §5.4 targets are un-normalized, and `uri-resolve` must
  reproduce them exactly.

- **`uri-normalize`** is the full §6.2.2 syntax-based normalizer:
  `normalize-components` (scheme and host case, percent-encoding), *then*
  §6.2.2.3 `remove-dot-segments` on the path. The order is load-bearing:
  percent-normalization turns `%2E%2E` into `..`, which the dot removal then
  collapses, so `http://h/a/%2E%2E/b` normalizes to `http://h/b` (§2.3 makes
  them equivalent). It **skips dot removal for a relative-path reference** (no
  scheme, no authority, path not starting with `/`). There, `..` means something:
  `remove-dot-segments("../b")` is `"b"`, which resolves differently. §6.2.3
  scheme-based normalization (default ports, empty path → `/`) is **not** done:
  a generic normalizer cannot know a scheme's defaults.

  This goes further than `(uri normalize)`, which leaves dot segments to
  resolution (README "Scope and limits"). The low layer keeps that split. The
  easy layer closes the normalize-then-resolve trap for its users by doing both.

- **`uri=?`** is `uri-components=?` over the two `uri-normalize`d values. String
  arguments are parsed with `string->uri-reference`.

### The `//` guard, and a correction to decision 0022

Decision 0022 says §5.2.2 resolution never produces a no-authority path
beginning `//`. **That is false.** Measured 2026-10-11 against the low layer:

```
resolve  base foo:/a   ref .//bar   → {scheme foo, authority #f, path "//bar"}
recompose                           → "foo://bar"
re-parse                            → {scheme foo, authority "bar", path ""}   ; a different URI
```

`/.//bar` against `foo:/a` does the same. The cause is that §5.2.4 turns `/.//`
into `//`, and §5.3 then emits the path after no authority. An `http` base hides
the problem, because a present authority keeps the `//` inside the path.
`uri-normalize` would hit it too (`foo:/.//bar`).

**The guard.** When a `Uri` the easy layer builds has no authority and a path
beginning `//`, it prefixes `/.` to the path. `/.//bar` is a valid
`path-absolute`, re-parses unchanged, and `remove-dot-segments` maps it back to
`//bar`, so it is the same resource. The guard runs after `uri-resolve` and
after `uri-normalize`. It is idempotent: normalizing `/.//bar` removes the dot
and the guard puts it back.

The low layer is not changed. Decision 0022 item 4 keeps `recompose` faithful
to §5.3. But the claim gets corrected, and the shape is pinned as an expected
non-round-trip next to the two 0022 already pins.

**`components->uri`** recomposes, re-parses in `uri-reference` mode with
validation, and requires the result to equal its argument. A hand-built set
that would silently change meaning, such as `(#f #f "a:b" #f #f)` (which
re-parses with scheme `a`), raises `ambiguous-components` and is not accepted
under a different meaning. A set whose path is `#f` is an assertion
violation: RFC 3986's path is never undefined, only empty.

### Error reasons

`uri-error-reason` is one of:

- the scanner's `scheme-required`, `scheme-forbidden`, `unexpected-eof`
  (`mode-unset` cannot arise: the easy layer always chooses a mode);
- `(uri charset)`'s `invalid-scheme`, `invalid-pchar`, `invalid-query`,
  `invalid-fragment`, `invalid-pct-encoded`;
- `(uri host)`'s `invalid-userinfo`, `invalid-reg-name`, `invalid-ip-literal`,
  `invalid-dec-octet`, `invalid-port`;
- the easy layer's own: `invalid-utf-8` (decode), `base-not-absolute` (resolve),
  `ambiguous-components` (`components->uri`).

Every reason carries an offset, so `uri-error-offset` is a `Nat`. The low layer
reports one with every error result. `base-not-absolute` and
`ambiguous-components` point at 0: the base as a whole lacks a scheme, and the
recomposed string as a whole re-parses differently.

`uri-error-reasons` exports this list, the way each low-layer library exports
its code list. It is written out in `(uri easy)`, not derived from those lists,
and a test asserts that it is exactly their union plus the easy layer's own
reasons. A new low-layer code then reddens the test instead of passing through
undocumented. A derived list would make that test pass by construction. The raised condition also carries `&who` (the
easy function) and `&message` (`"invalid-reg-name at 7"`), so an unhandled one
prints usefully. For `invalid-utf-8`, the input is the text being decoded and
the offset is where the bad sequence's first `%` sits in it.

## `(uri query)`: the core library

A pure library over bytevectors, next to `(uri host)`. `(uri host)` sub-splits
the authority the scanner holds opaque; this sub-splits the query the same way.
It imports `(rnrs)` and `(uri percent)`.

```
query-pairs : Bytevector -> (Listof (Pairof Bytevector (Option Bytevector)))
form-pairs  : Bytevector -> (Listof (Pairof Bytevector (Option Bytevector)))
```

- Split on `&` only. `;` is not a separator: WHATWG dropped it, and RFC 3986
  names no separator at all.
- Skip empty pieces: `a&&b` has two pairs, and `""` and `"&"` have none.
- Split each piece at its **first** `=`: `a=b=c` → `("a" . "b=c")`. No `=` gives
  an absent value: `a` → `("a" . #f)`, while `a=` → `("a" . "")`.
- Keep order and duplicates: `a=1&a=2` → two pairs, in input order.
- `form-pairs` maps `+` to space on the **raw** bytes, *then* decodes. So
  `x=%2B+y` reads `"+ y"`, where `query-pairs` reads `"++y"`.
- Percent-decode key and value with `pct-decode`, after the split.
- **Total.** Every bytevector splits, and nothing is rejected. Charset is
  `(uri charset)`'s question; UTF-8 is the easy layer's.

A ranged `[start, end)` form, like `validate-component`'s, is not included.
chez-http-server reads the query as a string today. If a server measures the
need, it can be added the way #21 and #24 were.

**Decision 0001 is amended, not reversed.** Its out-of-scope list keeps
`application/x-www-form-urlencoded` out of the *grammar*. The amendment records
that a split exists, in a separate library, over an already-isolated query, and
that the RFC 3986 query stays opaque everywhere else. `form-pairs` reads `+` the
HTML way but does not claim WHATWG conformance. It keeps absent values (WHATWG
reads `a` as `""`) and is strict UTF-8 (WHATWG substitutes U+FFFD). Under
decision 0013, WPT's urlencoded expectations are WHATWG's answers and are not
read.

## Decisions to record (Slice ⓪)

- **0040: the easy layer: strings at the edge, one record, a validated domain.**
  Rules 1–8 above. **Supersedes 0010 item 3** ("no string-level convenience
  layer in v0.1"). 0010 named the cost: two surfaces to keep in agreement,
  where the second is the one no vector exercises. This plan pays it by
  running every committed vector through the easy layer too (Slice ③). 0010
  items 1, 2, 4, 5 stand: the core stays bytevectors, and `utf8->string` stays at
  the edge, which is where `(uri easy)` is.
- **0041: the query is split by a core library over its bytes, never by the
  grammar.** The `(uri query)` section above. **Amends 0001's** out-of-scope
  bullet.
- **0042: the easy layer normalizes dot segments and guards the `//` shape.**
  The resolve/normalize section above, including the measured counterexample.
  **Amends 0022's** claim about §5.2.2 and adds the third pinned shape. The low
  layer's `recompose` is unchanged.

0001, 0010 and 0022 each gain a header line pointing at their amender, which is
the house convention (`.plans/decisions/README.md`).

## Slices

One PR per slice. Gate after ⓪, since the records are what the code is held to.
Each slice opens and closes in `.superpowers/sdd/progress.md` and states its
measured counts there, not here.

### ⓪ Records and the pin (no `src/` change) — GATE

- Write 0040, 0041, 0042; add the amendment headers to 0001, 0010, 0022.
- Pin the 0022 counterexample in `test/common/round-trip-tests.sps` as an
  expected non-round-trip: `(foo:/a, .//bar)` resolves and recomposes to
  `foo://bar`, which re-parses with authority `bar`. The test asserts today's
  RFC-literal behaviour. A change to it must redden, not drift.
- `README.org` "Scope and limits": the recomposition bullet said only
  components built by hand fail to round-trip. It now names the resolution case.
- Seed the milestone in the ledger. CHANGELOG `[Unreleased]` records the pin
  and the README change.

### ① `(uri query)`

- `src/uri/query.sls`, `test/common/query-tests.sps`, and a lane in
  `test/CMakeLists.txt`.
- **Reference 1: hand-derived vectors**, every bullet in the section above as a
  row, including `q=a%26b&r=1`, `a%3Db=c`, `a=b=c`, `a`, `a=`, `=`, `a&&b`, `""`,
  `a;b`, `a+b=c+d` (both readings) and `x=%2B+y` (both readings).
- **Reference 2: an independent oracle**, `(uri test query-oracle)` under
  `test/support/harness/`. It works over lists of octets and imports neither
  `(uri percent)` nor `(uri query)`, so the two cannot share a mistake. It is
  graded against the product by an exhaustive sweep over a small alphabet such as
  `{a = & + % 2 6 B}`. The length is set by measured runtime, as the charset
  sweep's was.
- **Mutations each must be watched failing:** decode before split; `+` → space
  after decoding; split at the last `=`; keep empty pieces; `;` as a separator;
  an absent value collapsed to `""`; duplicates merged or reordered.

### ② `(uri easy)`: parse and read

- The record, `&uri-error`, the three parsers, `uri-string?`, the eight raw
  accessors, `uri-path-segments`, `uri-query-pairs`, `uri-form-pairs`,
  `uri-decode`, `uri-encode`, and the strict UTF-8 check (internal, tested
  through `uri-decode`).
- `test/common/easy-tests.sps` and its lane.
- **Vectors:** each row of the field-semantics table, both its absent and its
  empty case. Case: `HTTP://User@Ex%41mple.COM/` reads scheme `"http"`, host
  `"example.com"`, userinfo `"User"`, and authority `"User@Ex%41mple.COM"`, and
  it renders back unchanged. Port: `http://a:8080`, `http://a:`, `http://a:080`,
  `http://[::1]:443`. UTF-8, positive: `%C3%A9`, `%F0%9F%98%80`. Negative:
  `%FF`, `%C0%AF` (overlong `/`), `%ED%A0%80` (surrogate), `%F4%90%80%80`
  (above U+10FFFF), `%E2%82` (truncated). Offsets: `string->relative-ref "é:b"` →
  `scheme-forbidden` at **1**.
- **Properties:** `(uri-decode (uri-encode s))` = `s` over generated strings,
  non-BMP included. The reason list equals the union of the code lists.
- **Mutations:** `utf8->string` in place of the strict check (`%FF` and `%FE`
  then compare equal); the byte offset passed through (`é:b` reads 2);
  `uri-parse` in place of `uri-parse-validate` (`http://a b/` is accepted); a
  first-`:` port split (`[::1]:443`); `#f` and `""` collapsed in any accessor;
  a raw host or scheme returned (`Example.COM`); the fold applied to the whole
  authority (userinfo `User` reads `user`); the fold applied inside a triplet
  (`%C3` reads `%c3`); and the fold leaking into the record (the render no
  longer round-trips).

### ③ `(uri easy)`: render, resolve, normalize, compare

- `uri->string`, `uri-resolve`, `uri-normalize`, `uri=?`, `uri->components`,
  `components->uri`, and the `//` guard.
- **Reference: the RFC's own vectors.** All 42 §5.4 rows run through
  `uri-resolve` *as strings*, compared with `uri->string`. This is how the second
  surface gets exercised by vectors, which was 0010's objection.
- **Properties over every committed corpus input that validates** (the §1.1.2
  examples, §5.4 bases, references and targets, and the adversarial corpus. WPT
  data is not vendored, despite 0013):
  - `(uri->string (string->uri-reference s))` = `s`.
  - Rule 8 holds for every `Uri` returned by `uri-resolve` and `uri-normalize`.
  - `uri-normalize` is idempotent.
- **Vectors:** `(foo:/a, .//bar)` → `"foo:/.//bar"`; `http://h/a/%2E%2E/b` →
  `http://h/b`; `../b` normalizes to `../b`; `/a/../b` to `/b`; `uri=?` on
  `HTTP://a/%7Euser` and `http://a/~user`; `components->uri` refusing
  `(#f #f "a:b" #f #f)`.
- **Mutations:** drop the guard (rule 8 reddens on the `foo:` vector); dot
  removal *before* percent-normalization (idempotence reddens on
  `/a/%2E%2E/b`); dot removal on relative-path references (`../b`); `uri=?` on
  raw components; `components->uri` without the equality check.

### ④ Docs and release v0.7.0

- `docs/easy.org`: short, ELI5. It covers the example at the top, the
  raw-vs-decoded rule, absent-vs-empty, and when to drop to the low layer.
- `README.org` (the structure #35 introduced):
  - a "What it does" bullet;
  - "Using it" leads with a `(uri easy)` example, and the bytevector example
    follows it for servers;
  - the task table gains `(uri easy)` and `(uri query)` rows;
  - the "Scope and limits" bullet "Normalization does not remove `.` and `..`
    segments" is narrowed to `(uri normalize)`, because `uri-normalize` does
    remove them.
- CHANGELOG `[0.7.0]`, the version bump, and the annotated tag. Then the
  merge gate and the closing ritual, **asked first**.

## Out of scope for this plan

- **Building and modifying:** `make-uri` from parts, per-component encode sets,
  `uri-with-path` and similar. These are the next plan if wanted. `components->uri`
  and `uri-encode` are the way in until then.
- **Host kind** (`reg-name` / IPv4 / IPv6 / IPvFuture). It needs a new `(uri
  host)` export, because the IPv4 recognizer is internal today. Until then,
  brackets mark an IP-literal.
- §6.2.3 scheme-based and §6.2.4 protocol-based normalization; IRIs and IDNA;
  WHATWG URL; a ranged `(uri query)`; a lenient easy parser.

## Settled in review (2026-10-11)

These were open in the first draft. The maintainer settled them, and Slice ⓪'s
records carry them.

1. **The name is `(uri easy)`**, in `src/uri/easy.sls`. A one-part name such as
   `(uri)` would read better, but it resolves to different files across
   implementations (Racket appends `/main`, Chez looks for `uri.sls`). A two-part
   name maps the same way everywhere, as `(uri collect)` does. It also follows
   the `racket/gui/easy` convention.
2. **`uri-scheme` and `uri-host` return the normalized form; the record and
   rendering stay raw.** This is rule 2's exception. The first draft returned
   both as written. Lowercasing at parse (Python and WHATWG) was rejected because
   it breaks the round-trip identity for uppercase input.
3. **`uri-resolve` and `uri=?` accept a `Uri` or a `String` per argument.** The
   parse mode for each position is fixed (the base is parsed absolute, the rest
   as a URI reference). An invalid string raises `&uri-error`, as everywhere else.
