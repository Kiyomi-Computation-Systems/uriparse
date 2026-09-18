# chez-uri: an RFC 3986 URI library for Chez Scheme — project brief

Date: 2026-09-18
Status: draft, for seeding a new repository
Consumer: `chez-http-server`
Sibling: `chez-httparse` (llhttp conformance) — a peer, not a parent
Generator: `byte-machine` (consumed as a submodule, pinned by gitlink)

## Goal

A URI library for Chez Scheme whose normative reference is **RFC 3986 (STD 66)**
and nothing else. Two layers:

1. **A generated scanner** — a `byte-machine` grammar that finds component
   boundaries, validates them against the ABNF, and reports exact byte offsets
   for what it rejects. Streaming, resumable across chunk boundaries, allocating
   nothing proportional to input.
2. **A pure core** — percent coding, normalization, dot-segment removal,
   reference resolution and serialization, as total functions over immutable
   inputs.

The split is Functional Core / Imperative Shell with the seam in the obvious
place: the machine is the only thing that is *fed* bytes, and everything
interesting is a function you can call with a bytevector and compare to a
constant.

### Naming

RFC 3986's term is **URI**. "URL" is informal in that document and is never
defined by its grammar. Name the project and its exports for the spec —
`chez-uri`, `(uri ...)` libraries — and reserve "url" for the WHATWG thing this
project explicitly is not.

## Why this is a separate repository

Settled in conversation, recorded here so the new repo's decision 0001 can cite it:

- **`chez-httparse`'s thesis is llhttp conformance**, byte for byte, against a
  vendored corpus. Every decision record, the ratchet, the trace format and the
  differential oracle serve that one thesis. "Implement RFC 3986" is a different
  thesis with a different normative reference and a different corpus.
- **The URL machine already in `chez-httparse` is not a precedent.** It is there
  for two reasons that do not transfer: its 21 `url.md` fixtures were the last of
  the 274 that repo committed to passing (its decision 0022), and
  `(httparse url-grammar)`'s `url-subgraph` is spliced into the HTTP grammar to
  validate the request target (`src/httparse/grammar.sls:2651`). It is
  load-bearing and cannot move.
- **The boundary rule is already written.** `chez-httparse` decision 0006: general
  capability goes upstream to `byte-machine`, HTTP-specific work stays local. An
  RFC 3986 library is neither, which makes it a **peer consumer** of
  `byte-machine` — the same position `chez-httparse` occupies.
- **Grammar reuse is zero.** llhttp's `URL_CHAR` is documented upstream as
  explicitly not a standard; its host span swallows userinfo and port; its
  host-keeps-the-`?` behaviour is a transcribed quirk. You would share byte-set
  helpers and nothing else.
- **CI is one Linux cell on a tight budget.** Co-located, every HTTP pull request
  pays for URI lanes it cannot affect, and every URI pull request pays for the
  21,630-run chunk scan.
- **Two corpora cannot share one ratchet.** "0 deferred, 274 of 274" means
  something because llhttp's corpus has provenance. A second corpus of different
  provenance behind the same number makes the number worth less.

What you *do* give up is the harness: `test/common/` (28 files),
`test/support/harness/`, the CMake lanes, the emitter pattern, the property and
mutation suites. **Copy it; do not pre-factor it.** The second copy is the only
place you can see both at once and tell what is generic from what is
llhttp-shaped — `trace-format`, for instance, renders llhttp's trace text and is
not generic at all. If a third consumer appears, `byte-machine`'s
`.reference/grammar-author-testing-guide.md` implies it already treats grammar
authors as its audience, and that is the natural home.

## The grammar, and where it stops being a grammar

RFC 3986's core ABNF, for reference while sizing the work:

```abnf
URI           = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
hier-part     = "//" authority path-abempty / path-absolute
              / path-rootless / path-empty
URI-reference = URI / relative-ref
relative-ref  = relative-part [ "?" query ] [ "#" fragment ]
relative-part = "//" authority path-abempty / path-absolute
              / path-noscheme / path-empty

scheme        = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
authority     = [ userinfo "@" ] host [ ":" port ]
userinfo      = *( unreserved / pct-encoded / sub-delims / ":" )
host          = IP-literal / IPv4address / reg-name
port          = *DIGIT
IP-literal    = "[" ( IPv6address / IPvFuture ) "]"
IPvFuture     = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
IPv4address   = dec-octet "." dec-octet "." dec-octet "." dec-octet
dec-octet     = DIGIT / %x31-39 DIGIT / "1" 2DIGIT
              / "2" %x30-34 DIGIT / "25" %x30-35
reg-name      = *( unreserved / pct-encoded / sub-delims )

segment-nz-nc = 1*( unreserved / pct-encoded / sub-delims / "@" )   ; no ":"
pchar         = unreserved / pct-encoded / sub-delims / ":" / "@"
query         = *( pchar / "/" / "?" )
fragment      = *( pchar / "/" / "?" )
pct-encoded   = "%" HEXDIG HEXDIG
unreserved    = ALPHA / DIGIT / "-" / "." / "_" / "~"
sub-delims    = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
```

Everything above is regular and belongs in the machine. Everything below is not,
and belongs in the core:

| RFC 3986 section | Why it is not the machine's job |
|---|---|
| §5.2.4 `remove_dot_segments` | pops previously-emitted segments — a stack, unbounded in path depth |
| §5.2.2 reference resolution | a decision tree over parsed components plus path merging; no scanning |
| §5.3 component recomposition | emits new bytes |
| §6 normalization | case folding, pct-encoding normalization, segment normalization — all emit |
| percent decoding | emits |

## The one hard design question — settle it before M2

`scheme` and the first path segment share a prefix language, and you cannot tell
them apart until the delimiter arrives:

- `foo:bar` — `foo` is a **scheme**.
- `foo/bar` — `foo` is a **path segment** (`segment-nz-nc`, which excludes `:`).
- `foo` alone, at end of input — a path segment.

llhttp dodges this by *requiring* `//` after a scheme, which is why `urn:isbn:x`
and `mailto:a@b` are outside its URL machine entirely. RFC 3986 does not have
that luxury: `path-rootless` is a first-class alternative.

This matters because `byte-machine` is forward-only with no backtracking, and a
span binds to its callback *at build time* (`make-span-declaration`). You cannot
open `scheme-span` optimistically and rename it when the delimiter disappoints.

Three ways out, in preference order:

1. **A mode field, chosen by the caller** — the same shape as `chez-httparse`'s
   request/response selector: a settable `uint` field read at `make-parser`,
   selecting the `URI` entry or the `relative-ref` entry. Its decision **0021**
   is the mechanism to copy; 0017 reached for a `decision` callback first and was
   superseded on mechanism only, but its reasoning — that the mode is not
   derivable from the bytes and the fall-through must be an error — transfers
   unchanged. **This is almost certainly right for the actual consumer.** RFC 9112
   gives a request-target as origin-form, absolute-form, authority-form or
   asterisk-form, and a server knows which it expects from the method and
   context. The ambiguity is the caller's to resolve, and the caller can.
2. **A neutral span plus a confirming event** — open `on-leading-token-data` over
   the ambiguous prefix, close it at the delimiter, then fire a zero-width
   `event` callback (`on-scheme-confirmed` / `on-segment-confirmed`) naming what
   it turned out to be. Uses only existing node kinds: span-start → dispatch →
   span-end → callback. The host buffers the bounds and interprets on the next
   event. This is the honest answer when the caller genuinely does not know.
3. **Two machines**, as `chez-httparse` did for message and url. Probably
   overkill — the two grammars differ in one decision, not throughout.

Recommendation: ship **(1)** with **(2)** available as a third mode for callers
parsing `URI-reference` blind. Record it as decision 0004 before writing M2.

## The test instrument comes first

`chez-httparse` had llhttp as ground truth. **This project has no oracle**, and
that is the single biggest difference in how it must be built. What it has
instead:

- **RFC 3986 §5.4 is a normative test-vector set.** §5.4.1 ("Normal Examples")
  and §5.4.2 ("Abnormal Examples") give roughly fifty reference-resolution cases
  against the base `http://a/b/c/d;p?q`, each with its exact expected target.
  That is a real, citable corpus and it is the anchor for the whole resolution
  layer.
- **§5.2.4 works `remove_dot_segments` by hand** on two inputs, step by step.
- **§1.1.2 gives example URIs across schemes** — ftp, http, ldap, mailto, news,
  tel, telnet, urn — which is exactly the scheme diversity llhttp's corpus lacks
  and a good smoke set for `path-rootless`.

For the scanner, where the RFC gives no vectors, build two instruments:

1. **A property lane**, the pattern `chez-httparse` already has: a parse that
   reaches no error produces the same spans however the bytes arrive, and the
   committed artifact agrees with the interpreted grammar. Both asked of every
   generated input, with a per-kind floor so a lane that selected nothing cannot
   pass vacuously.
2. **A round-trip property**: parse → normalize (§6) → recompose (§5.3) → parse
   must reach a fixed point, and the second parse's spans must equal the first's.

For differential testing, the rule to adopt on day one: **no implementation is
authoritative.** Browsers are WHATWG; most libraries are deliberately lax. Run a
differential against two or more independent implementations and treat
disagreement as a case to *adjudicate against the ABNF*, with a decision record
naming the divergence — `chez-httparse`'s decision 0018 rule ("a divergence is
named and witnessed or it fails the lane") transfers unchanged and matters more
here, not less.

## Portability: keep what you inherit

`byte-machine`'s `src/` is pure R6RS — `graph`, `verify`, `compile`, `interpret`,
`runtime` and the four `private/` libraries import `(rnrs)` and each other and
nothing more — and every generated artifact imports `(rnrs)` and
`(byte-machine runtime)` and nothing else. `chez-httparse` preserved that: not one
file under its `src/` mentions `(chezscheme)`.

So **chez-uri's shipped surface is portable by default.** You do not have to earn
it, only avoid breaking it. Two rules:

1. **`src/` imports `(rnrs)`, `(byte-machine ...)` and this project's own
   libraries — nothing else.** Assert it in a lane rather than trusting it. A
   grep-for-`chezscheme`-under-`src/` audit is a few lines of CMake and fits the
   habits this family already has (the rename audit, the plan-header audit).
2. **Where Chez is unavoidable, import it narrowly.** `chez-httparse`'s harness is
   the model: `(only (chezscheme) machine-type scheme-version getenv system
   statistics sstats-bytes real-time with-output-to-string display-condition)` —
   eight enumerated names, so the whole portability surface is readable at a
   glance. `tools/emit-machine.ss` imports `(chezscheme)` wholesale and is the
   counter-example. Copy the harness, not the emitter.

Chez belongs in exactly four places: the test harness, the emitter, any benchmark
runner, and the CMake probe. Carry forward the `BACKEND` argument that
`chez-httparse`'s Scheme lanes already take — `cmake/HttparseSchemeLane.cmake`,
whose error message reads *"Known backends: chez"*. The hook costs nothing now and
is exactly the thing you would otherwise have to retrofit.

**One lane cannot be portable.** Allocation measurement needs `statistics` /
`sstats-bytes`, which have no standard spelling and no common analogue. Decide at
M1 whether chez-uri has an allocation lane at all; if it does, it is Chez-only by
construction and should say so where it is defined.

The core layer is the portable part and should stay that way. Percent coding,
normalization, `remove_dot_segments` and resolution are pure functions over
bytevectors and strings — `(rnrs bytevectors)` gives you `utf8->string` and
`string->utf8`, `(rnrs io ports)` gives you string ports, and none of it needs a
runtime extension.

**Two cautions.**

*Portable by construction is not portable verified.* Nothing in this family has
been run on another implementation. Library resolution (`.sls` naming and search
paths, Racket's `#lang r6rs` wrapping, Guile's own path rules) and the performance
of the generated dispatch are where a port would actually go wrong — the emitted
code is a large mutually-recursive set of internal defines leaning on proper tail
calls, a shape Chez compiles very well and others may not. Keep a portability
claim out of `README.org` until a second implementation is in CI: the house rule
is that a property is measured or it is not claimed.

*One RFC 3986 trap is a portability trap and a correctness trap at once.* §6.2.2.1
normalizes scheme and host case, and it means **ASCII case only**. R6RS's
`string-downcase` lives in `(rnrs unicode)` and performs full Unicode case
folding, which is wrong here and length-changing in general — U+0130 lowercases to
two code points, and U+212A (KELVIN SIGN) lowercases to ASCII `k`, so a host
containing it would compare equal to one that does not. It is also among the most
likely places for two implementations to disagree. Write the ASCII fold by hand,
in the core, and test it against a non-ASCII input that proves it did nothing.

## Milestones

Each milestone exits on a ratchet diff: named vectors move from not-yet-passing
to passing, and nothing else moves.

### M1 — the instrument, with no parser

The §5.4, §5.2.4 and §1.1.2 vectors transcribed as data with a `PROVENANCE` file
citing section numbers. The loader, the comparator, the ratchet, the `pr` /
`release` chunk-size split, and the harness lanes. The `byte-machine` submodule
does **not** land here — nothing invokes the emitter yet, and an unused pin only
rots (`chez-httparse` decision 0002 item 2, and its own M1 correction).

**Exit**: every vector loads with a status; the comparator is
mutation-witnessed — a deliberately corrupted expectation must fail it.

### M2 — the generic split, and the mode decision

Five spans — scheme, authority, path, query, fragment — split on delimiters
only, with no charset validation beyond what the split needs. This is the
Appendix B equivalent, and **it is what unblocks `chez-http-server`.** The
submodule and its ABI assertion land here. Decision 0004 (the ambiguity) is
written before the grammar.

**Exit**: `chez-http-server` can route on a path and read a raw query.

### M3 — charset validation

`pct-encoded` in every component that admits it, the scheme charset, `pchar` /
`segment-nz-nc` / `query` / `fragment` sets, port digits. Error offsets for each.

### M4 — the host grammar

`reg-name`, then `IPv4address`, then `IP-literal` → `IPv6address` / `IPvFuture`.

- `dec-octet` **forbids leading zeros** (`01` is invalid), which rules out a bare
  `make-integer-accumulate-node` + range branch. Use the five-alternative form as
  a small dispatch, or accumulate and check the digit count.
- `IPv6address` is nine alternatives with optional prefixes. It is regular, but
  **generate it programmatically** — the way `chez-httparse` generated its keyword
  trie in decision 0006 — and **measure the node count before committing to it.**
  Rough estimate: groups-seen × before/after-`::` × digit-position, call it
  150–250 nodes plus the `ls32` tail. If it comes in far worse than that, the
  fallback is a `decision` callback that hands the bracketed span to Scheme.

### M5 — the core: percent coding and normalization

Percent decode/encode, §6 normalization (scheme and host case, pct-encoding
case, unreserved decoding). Pure functions, tested as such.

### M6 — dot segments and reference resolution

§5.2.4 and §5.2.2. **Gated on the §5.4 vectors passing 100%** — this is the one
milestone with a normative corpus, so it either passes all of it or it is not
done.

### M7 — recomposition and the round-trip property

§5.3, plus the round-trip lane from above.

### M8 — release v0.1

## Out of scope, and say so in a decision record

- **WHATWG URL.** Different normative reference, different results on ordinary
  inputs, and mixing the two is the parser-differential security class. If it is
  ever wanted it is a separate machine with a separate corpus, not a mode.
- **RFC 3987 IRIs**, IDNA, Punycode, Unicode mapping tables.
- **`application/x-www-form-urlencoded`** query splitting. RFC 3986's `query` is
  opaque; `key=value&...` is an HTML convention. `chez-http-server` will want it
  — put it in a clearly separate module, or in the server, and do not let it into
  the URI grammar.
- **URI Templates** (RFC 6570), scheme-specific semantics, and any registry of
  known schemes.

## Decisions to record on day one

Mirroring `chez-httparse`'s numbering habit:

- **0001** — project name, and the scope boundary against `chez-httparse`
- **0002** — `byte-machine` consumption, the gitlink pin, and the generated ABI
- **0003** — the normative reference is RFC 3986; implementation disagreement is
  adjudicated against the ABNF, not against a popular library
- **0004** — the scheme / first-segment ambiguity, and the mode field
- **0005** — what the corpus is, and its provenance by section number
- **0006** — CI covers one cell
- **0007** — `src/` is pure R6RS; Chez is confined to the harness, the
  emitter, the bench runner and the probe, and is imported narrowly where it
  does appear

## Standing risks

1. **No oracle.** The thing that made `chez-httparse` tractable is absent. Budget
   for adjudication, and write the divergence rule before the first disagreement
   rather than after.
2. **`IPv6address` node count.** The one part that could surprise. Measure at M4;
   have the `decision`-callback fallback ready.
3. **"Comprehensive" has no natural stopping point.** M2 unblocks the actual
   consumer. Everything after M2 is for the library's own sake, which is a fine
   reason, but it should be a decision rather than a drift.
4. **Scope creep toward WHATWG**, driven by "but browsers do X." Decision 0003
   exists to answer that in one line.

## Repo scaffolding checklist

- `Makefile` with `build`, `dev`, `test`, `clean`, `prod` as thin wrappers over
  CMake presets
- `CMakePresets.json` mirroring `chez-httparse`: `dev`, `pr`, `release`,
  `no-scheme`
- `vendor/byte-machine` as a submodule, pinned by gitlink, with an ABI assertion
  in the first milestone that emits
- `README.org`, `CHANGELOG.md`, `.plans/`, `.plans/decisions/`
- `LICENSE` — BSD 3-Clause, matching the sibling projects
- CI: one Linux cell, Chez built from source and cached, `pr` then `release` then
  `no-scheme`
- An import-audit lane: nothing under `src/` may mention `(chezscheme)`
- `src/uri/grammar.sls` (source machine) → `src/generated/uri-scanner.sls`
  (committed artifact), with one emitter and one determinism lane
