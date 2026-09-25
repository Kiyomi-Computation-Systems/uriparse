# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2026-09-25

Released on macOS arm64 evidence only. The Linux CI cell is configured and committed
but has **still never run** (decisions 0017, 0037). The #24 PR's `linux-amd64` check
was the billing refusal (0 steps, ~3s, "recent account payments have failed"), not a
run. So every count below is measured on macOS arm64 (Chez Scheme 10.4.1, machine-type
tarm64osx; CMake/CTest 4.3.3) and nowhere else: the complete selection is 77/77 and the
no-Scheme layer 11/11, 0 failures, re-measured on the release commit. v0.6.0 extends
v0.5.0's ranged validation to the **authority**: a server judges a `Host` header value
in place, still in the socket's buffer, without copying it. It states **no new
conformance claim**: the ranged form is the same M4 host grammar judge that
`uri-parse-validate` uses. The scoped claim and every boundary read exactly as
v0.3.0 to v0.5.0 (decision 0037).

### `validate-authority` and `authority-host-span` over a range — judge a Host value in place

- **`validate-authority`** and **`authority-host-span`** on `(uri host)` now take an
  optional `start` and `end`, defaulting to 0 and the length, so every one-argument
  call behaves as before:
  - `validate-authority : Bytevector [Nat [Nat]] -> (values (Option Symbol) (Option Nat))`
  - `authority-host-span : Bytevector [Nat [Nat]] -> (values Nat Nat)`

  The verdict on `bv[start, end)` is the verdict on those bytes alone:
  - nothing outside the range is read, so an `@`, `]` or `:` past `end` splits, closes
    or delimits nothing;
  - a `%` whose HEXDIGs would lie past `end` is malformed;
  - **every number returned is relative to `start`**: the fault index, and BOTH host
    bounds, the same rule as `validate-component`.

  A range not within the bytevector is an assertion violation that names the procedure
  called (decision 0036).
- The point (issue #24): RFC 9112 §3.2 requires a 400 for a `Host` field with an invalid
  value. A server that keeps header values as spans of its buffer would otherwise copy
  each `Host` value out first (16 to 64 B per request, growing with the value). The
  ranged form allocates **0 bytes per call** for both procedures, on ordinary hosts and
  on 4000-byte values.
- It judges an RFC 3986 **authority**, not RFC 9110's `Host` (`uri-host [ ":" port ]`),
  which has no userinfo. Refusing a userinfo is the server's rule:
  `authority-host-span`'s host start is not 0 exactly when the value contains an `@`.
  So is deciding whether an empty `Host` is acceptable, since an empty authority is
  valid here.
- `authority-host-span` now has direct checks of its own (15 hand-derived bounds, whole
  and as a span). Other new `unit.host` checks, all mutation-witnessed:
  - agreement with the independent host oracle on the span alone, placed in 11 hostile
    surroundings;
  - pinned `Host` lines;
  - refusal checked by who raised it;
  - allocation that does not grow with the value's length.

  A merge-gate review made the range check and the host split ONE implementation each,
  shared by every ranged judge. After it, all 29 mutants redden. No new lane, and no new
  public export; the release selection is unchanged at 77.

## [0.5.0] - 2026-09-25

Released on macOS arm64 evidence only. The Linux CI cell is configured and committed
but has **still never run** (decisions 0017, 0035). The #21 PR's `linux-amd64` check
was the billing refusal (0 steps, ~3s, "recent account payments have failed"), not a
run. So every count below is measured on macOS arm64 (Chez Scheme 10.4.1, machine-type
tarm64osx; CMake/CTest 4.3.3) and nowhere else: the complete selection is 77/77 and the
no-Scheme layer 11/11, 0 failures, re-measured on the release commit. v0.5.0 adds
**ranged component validation**: `validate-component` judges a span of a larger
bytevector in place, so a server that keeps its request-target in the socket's buffer
validates it without copying. It states **no new conformance claim**: the ranged form
is the same component charset judge (M3) that `uri-parse-validate` uses. The scoped
claim and every boundary read exactly as v0.3.0/v0.4.0 (decision 0035).

### `validate-component` over a range — judge a span in place

- **`validate-component`** on `(uri charset)` now takes an optional `start` and `end`:
  `Symbol Bytevector [Nat [Nat]] -> (values (Option Symbol) (Option Nat))`. They default
  to 0 and the length, so every two-argument call behaves as before, misuse diagnostics
  included. The verdict on `bv[start, end)` is the verdict on those bytes alone:
  - nothing outside the range is read;
  - a `%` whose HEXDIGs would lie past `end` is malformed;
  - the index of the first bad byte is relative to `start`.

  A range not within the bytevector is an assertion violation, and an unknown component
  is named before the range is checked (decision 0034).
- The point (issue #21): RFC 9112 origin-form is `absolute-path [ "?" query ]`. A
  collector parse would read a leading `//` as an authority (`//a@b:c/d` is a valid
  origin-form target, yet `uri-parse-validate 'uri-reference` answers `invalid-port`@6).
  So a server splits at the first `?` and judges the path and the query itself. Until
  now it copied each part first (16/80/512 B at 2/46/500-byte targets), the only
  per-request cost that grew with the target. The ranged form allocates **0 bytes per
  call** for every component at 2 to 4000 bytes.
- It judges a component's CHARSET, not its structure, exactly as before. Where the
  delimiters fall (for example, that an origin-form path begins with `/`) is the caller's
  split to make.
- New `unit.charset` checks, all mutation-witnessed (20 mutants):
  - agreement with the independent oracle on the span alone, under surroundings chosen
    to catch every way of reading outside it;
  - hardcoded pins;
  - refusal of six bad ranges, each required to raise with `validate-component` as its
    who;
  - the component named first;
  - allocation that does not grow with the span's length, for all four components.

  A ranged `validate-authority` is deferred (decision 0034 item 6). No new lane; the
  release selection is unchanged at 77.

## [0.4.0] - 2026-09-20

Released on macOS arm64 evidence only. The Linux CI cell is configured and committed
but has **still never run** (decisions 0017, 0033) — the #18 PR's `linux-amd64` check
was the billing refusal (0 steps, ~3s, "recent account payments have failed"), not a
run — so every count below is measured on macOS arm64 (Chez Scheme 10.4.1, machine-type
tarm64osx; CMake/CTest 4.3.3) and nowhere else: the complete selection is 77/77 and the
no-Scheme layer 11/11, 0 failures, re-measured on the release commit. v0.4.0 adds
**result-level validation** (`uri-parse-result-validate`), so a server holding one
collector per connection (`uri-collector-reset!`, v0.3) can validate its
`uri-collect-finish!` result with no re-parse. It states **no new conformance claim**:
the export is the SAME audited recognizer (RFC 3986 Appendix A recognizer-equivalence
per mode, decision 0030) reached from a parse result — the scoped claim and every
boundary read exactly as v0.3.0 (decision 0033).

### `uri-parse-result-validate` — validate a parse result without re-parsing

- **`uri-parse-result-validate`** on `(uri collect)` — `uri-parse-result ->
  uri-parse-result` — applies the audited component charset (M3) and host grammar (M4)
  judgement to an already-parsed result: an error result passes straight through
  unchanged (the argument itself), a valid result returns itself, and an otherwise-valid
  split whose bytes the ABNF rejects becomes a leftmost-first validation error with its
  absolute offset. `uri-parse-validate` is now `(uri-parse-result-validate (uri-parse
  mode bv))` — behaviour-preserving, outcome-identical for every input (decision 0032).
- The point (issue #18): validation is a pure function of the result — its components
  and its offset seam — so a REUSED collector's `uri-collect-finish!` result reaches the
  same audited verdict as a fresh `uri-parse`, with no re-parse and no second
  implementation. The measured gap it closes (a 46-byte origin-form target): 3680 B on a
  fresh collector, 1584 B on a reset one.
- No product algorithm changed — one additive export and a one-line refactor. New
  `unit.collect` checks pin the delegation, the reset-reused validation path, the
  `eq?` identity semantics, and two INDEPENDENT hardcoded expectations, one per arm of
  the judgement (charset `invalid-pchar`@10 on both the fresh and reset-reused paths;
  authority `invalid-port`@9 through the authority seam), mutation-witnessed. A
  merge-gate review caught two "asserted-but-unpinned" test gaps — a reuse case that
  never reset, and tautological equivalence checks that shared the code under test — and
  they were fixed with the independent pins. No new lane; the release selection is
  unchanged at 77.

## [0.3.0] - 2026-09-20

Released on macOS arm64 evidence only. The Linux CI cell is configured and committed
but has **still never run** (decisions 0017, 0031), so every count below is measured
on macOS arm64 (Chez Scheme 10.4.1, machine-type tarm64osx; CMake/CTest 4.3.3) and
nowhere else: the complete selection is 77/77 and the no-Scheme layer 11/11, 0
failures, re-measured on the release commit. v0.3.0 is the **first release to state an
RFC 3986 conformance claim** — `uri-parse-validate` is **audited recognizer-equivalent**
to RFC 3986 Appendix A per mode — and it adds **per-connection collector reuse**
(`uri-collector-reset!`). The claim is *scoped*: it is recognition (accept/reject)
equivalence, not error-code/offset; the exhaustive part is bounded (length 5, a 12-byte
alphabet) with deeper structures covered adversarially; and `uri-parse` itself stays
lenient by design. It is **not** a blanket whole-library "RFC 3986 compliant" (decision
0031).

### The RFC 3986 conformance audit — recognition-equivalence, verdict clean

- **`(uri test abnf-oracle)`** — an INDEPENDENT whole-URI recognizer of RFC 3986
  Appendix A's structural grammar (the `scheme ":" hier-part` / `relative-part` split,
  the five path-types, and the URI / relative-ref fork — `path-rootless` vs the
  colon-forbidden `path-noscheme`), composing the audited M3 charset and M4 host
  component oracles for every charset question. Read from the ABNF, not from the
  product it grades (decisions 0005, 0028).
- **The differential** — `uri-parse-validate` ⇄ the oracle over an EXHAUSTIVE
  length-0..5 sweep of a 12-byte reduced alphabet in all three modes (814,359
  input×mode pairs, the count asserted equal to an independently computed total so a
  silent cap reddens and the bound is disclosed on a coverage line), the §1.1.2 / §5.4
  positive corpora (both accept), the M3 / M4 negative corpora (both reject), and 213
  deep adversarial vectors each carrying its ABNF verdict as a THIRD independent
  reading. **Zero deviations**: `uri-parse-validate` is recognizer-equivalent to
  Appendix A per mode, as shipped in v0.2.0 (decision 0030).
- The adversarial vectors came from an eight-production adversarial probe with every
  verdict independently re-derived from Appendix A; a merge-gate review aimed at the
  audit artifacts themselves confirmed the verdict (no oracle bug, no shared blind
  spot, no wrong corpus verdict) and hardened the sweep's coverage into an asserted,
  disclosed invariant. Both failure detectors are mutation-witnessed. No product code
  changed — the audit is additive test artifacts and records; the release selection
  grew 75 → 77 (two lanes, source and aot).

### `uri-collector-reset!` — per-connection collector reuse

- **`uri-collector-reset!`** on `(uri collect)` returns a collector to its
  just-constructed state IN PLACE — `parser-reset!` (preserving the embedder-chosen
  mode), and the span table, the offset table, and the verdict flags cleared — with no
  reallocation, so a server can hold one collector per connection instead of allocating
  a parser and two `eq-hashtable`s per request (issue #11, decision 0029). `uri-parse`
  and the one-shot path are unchanged; a reset-and-reparse is byte-identical to a fresh
  collector, pinned in both the components and the offsets, across all three modes and
  across the rooted and verdict transitions.
- Measured once, not a standing lane (decision 0016): ~6.4× on a short target. Six
  mutation witnesses; the merge-gate review corrected a false "verdict unobservable"
  claim (the verdict reset IS observable through the path offset) and added the
  witnessing reuse row that proves it.

## [0.2.0] - 2026-09-19

Released on macOS arm64 evidence only. The Linux CI cell is configured and committed
but has **still never run** (decisions 0017, 0027), so every count below is measured
on macOS arm64 (Chez Scheme 10.4.1, machine-type tarm64osx; CMake/CTest 4.3.3) and
nowhere else: the complete selection is 73/73 and the no-Scheme layer 11/11, 0
failures, re-measured on the release commit. v0.2.0 adds **validation**
(`uri-parse-validate` judges every component's charset and the whole host grammar),
**completes** RFC 3986 §6.2.2.1 normalization (host case), and parses **RFC 9112
authority-form** CONNECT targets — over v0.1's lenient splitter, strict resolver, and
complete pure core. `uri-parse` itself stays lenient by design. It is **not yet** "RFC
3986 compliant": that blanket claim is a whole-ABNF conformance audit this project has
not run, so it is earnable but not granted (decision 0027).

### M9 — authority-form for CONNECT targets

- **`uri-parse-authority-form` / `uri-parse-authority-form-validate`** — RFC 9112
  §3.2.3 authority-form (`host:port`, no scheme, no `//`) parsing on `(uri collect)`,
  via a `//` splice through relative-ref mode with a −2 offset re-map — no scanner or
  grammar change, reusing `(uri host)`. The lenient form mirrors `uri-parse` and
  rejects only a trailing path/query/fragment (`not-authority-form`); the strict form
  adds, leftmost-first, `userinfo-forbidden` (bracket-aware — an `@` inside an
  IP-literal is not userinfo), the host grammar, and `port-required` (an empty port
  `host:` is valid RFC 3986 but not RFC 9112).
- Graded against a hand-derived §3.2.3 corpus (17 rows, both entry points per row,
  exact code + absolute offset), with six mutation witnesses; a merge-gate adversarial
  review surfaced and fixed one code defect (a bracketed-`@` misfire) and one coverage
  gap (decision 0026).

### M4 — the host grammar, and host-case normalization

- **`(uri host)`** — RFC 3986 §3.2 authority validation as pure functions over the
  authority bytevector: the bracket-aware userinfo/host/port split, and the host
  grammar — reg-name, IPv4address, IP-literal → IPv6address (read as a `::`-compression
  counter, not the nine ABNF alternatives) / IPvFuture, and port. `uri-parse-validate`
  now judges the authority too. Reachability is exact: a bare dotted quad like
  `999.1.1.1` is a valid reg-name (§3.2.2 first-match-wins), so `invalid-dec-octet` is
  reachable only inside `[...]`.
- **Host-case normalization** — `normalize-components` now folds the *host* to
  lowercase (§6.2.2.1a), skipping `%XX` triplets so their hex stays uppercase
  (§6.2.2.1b) and leaving userinfo case-sensitive — completing RFC 3986 §6.2.2.1 and
  closing v0.1's last deferred transform (decision 0020).
- Graded three ways (decisions 0024, 0025): the validator agrees with an independent
  ABNF oracle over a shape battery plus exhaustive dec-octet / h16 / group-count
  sweeps; a hand-derived negative corpus is rejected with the exact code and absolute
  offset; the positive corpora are all accepted. Mutation witnesses throughout.

### M3 — charset validation

- **`(uri charset)`** — the coarse-component charset validators (scheme, path, query,
  fragment) as pure functions over bytevectors, reusing `(uri percent)`'s
  `unreserved-byte?` and hex primitives so the validator and the codec cannot disagree
  about a byte, plus a core error vocabulary (`invalid-scheme` / `-pchar` / `-query` /
  `-fragment` / `-pct-encoded`, decision 0024).
- **`uri-parse-validate`** — parse leniently, then judge the component charsets in
  input order (the first error is the leftmost), rebasing the validator's relative
  index onto the offset seam to an absolute offset. `uri-parse` itself stays lenient —
  validation is a distinct entry point, not always-on, because the normalization,
  resolution and round-trip layers depend on the non-validating splitter.
- Graded three ways: agreement with an independent ABNF oracle over all 256 single
  bytes × four components plus a pct-encoded battery; a hand-derived negative corpus
  rejected with the exact code and absolute offset; the positive corpora all accepted.

## [0.1.0] - 2026-09-19

Released on macOS arm64 evidence only. The Linux CI cell is configured and
committed but has **never run** (decision 0017), so every count below is measured
on macOS arm64 (Chez Scheme 10.4.1, machine-type tarm64osx; CMake/CTest 4.3.3)
and nowhere else: the complete selection is 63/63 and the no-Scheme layer 11/11,
0 failures, re-measured on the release commit. v0.1.0 is a resolution-first,
**non-validating** URI splitter and a complete pure core — it is **not** "RFC
3986 compliant" and accepts bytes the ABNF rejects; charset validation and the
host grammar are v0.2 (decisions 0011, 0023, and the README caveats).

### M7 — the round-trip property

- **`property.round-trip`** — RFC 3986's round-trip property, now measured: for
  every committed URI, `parse → normalize (§6.2.2) → recompose (§5.3) → parse`
  reaches a fixed point (the re-parsed, normalized components equal the first
  normalized components, keeping absent `#f` distinct from present-empty). It is
  a **one-step** identity on the once-normalized components, **not** a normalize
  fixed point — normalization is not idempotent over v0.1's non-validating domain
  (`%%341 → %41 → A`), pinned as such (decision 0022).
- Graded over the normative corpora (the 8 §1.1.2 examples and the 42 §5.4
  targets), plus hand vectors that put a real §6.2.2 delta and the full
  empty/absent matrix through the loop (including the §3.2 case `http:///p` vs
  `http:/p`). No new core library — `(uri recompose)` shipped at M6.
- The **§4.2 / §3.3 recompose boundary** is pinned as documented expected
  non-round-trips: `(uri recompose)` is a faithful inverse of parse for every
  parse output, but a hand-built relative path with a colon-first segment or a
  `//`-leading no-authority path does not survive it. §5.3 omits §4.2's `./` on
  purpose; adding it would diverge from the RFC's recomposition algorithm, and
  that disambiguation is a reference producer's job — a v0.2 serializer above
  recompose, not the generic renderer (decision 0022).

### M6 — dot segments and reference resolution

- **`(uri path)`** — the two path routines §5.2 resolution refers to, as pure
  functions over path bytevectors: `remove-dot-segments` (§5.2.4's two-buffer
  loop) and `merge` (§5.2.3). `remove-dot-segments` is graded step-for-step
  against RFC 3986's committed §5.2.4 worked traces, not only their end results.
- **`(uri resolve)`** — RFC 3986 §5.2.2 strict reference resolution over
  components: a base URI's components and a reference's in, the target's out.
  Strict (decision 0015/0001), so `http:g` resolves to `http:g`, never the
  RFC-1630 `http://a/b/c/g`.
- **`(uri recompose)`** — §5.3 component recomposition, components back to a URI
  string, guarded on *defined* not nonempty (an empty-but-present authority still
  emits `//`). It lands at M6 with resolution because §5.2.2 ends by recomposing
  (decision 0021); the round-trip property remains M7.
- **All 42 rows of RFC 3986 §5.4 pass** — the one normative corpus this project
  has, gated at 100% (decision 0011). The two-way ratchet flips them
  `not-yet → passing` and makes both a regression and an unrecorded pass a
  failure. Each library is graded against an oracle derived from RFC 3986
  independently of the code, with mutation witnesses watched red then reverted.

### M5 — the core: percent coding and normalization

- **`(uri percent)`** — percent decode/encode over bytevectors: `pct-decode`
  (decode every valid `%XX`, leave a malformed `%` byte-for-byte — v0.1 is
  non-validating), `pct-encode` (escape by a caller-supplied predicate, uppercase
  hex), the §2.3 `unreserved-byte?` test, and the hex primitives the normalizer
  reuses.
- **`(uri normalize)`** — RFC 3986 §6.2.2 syntax-based normalization over the
  five-field components: the scheme case fold, hex-digit uppercasing, and
  decoding of percent-encoded *unreserved* octets. Host-case normalization is
  **deferred** to the host grammar (v0.2) — the authority is not sub-parsed yet
  and userinfo is case-sensitive — and dot-segment removal is reference
  resolution (M6). Recorded as decision 0020 and pinned by tests, so the
  deferrals cannot silently change.
- Both libraries are pure R6RS over bytevectors (decision 0010), graded against
  an oracle derived from RFC 3986 independently of the code, with mutation
  witnesses watched red then reverted.

### M2 — the generic split, and the mode decision

- **The scanner.** A byte-machine grammar that splits a URI reference into five
  coarse components — scheme, authority, path, query, fragment — for all three
  modes (URI, relative-ref, uri-reference), on delimiters only, judged against an
  oracle derived independently from RFC 3986's ABNF. It ships as a committed,
  reviewable `(generated uri-scanner)` artifact (generated ABI 9) with a
  determinism lane that re-emits, reads the ABI back out, and runs the artifact
  itself against the reference interpreter.
- **The five libraries the design named**: `(uri vocabulary)` (the agreed span,
  callback and error names, and the mode integers), `(uri grammar)` (the source
  machine), `(generated uri-scanner)`, `(uri components)` (the five-field seam
  type, where absent `#f` is never conflated with present-empty `#vu8()`), and
  `(uri collect)` (the shell that assembles components, streaming or one-shot).
- **byte-machine lands as a submodule** pinned to v0.6.0, with `tools/emit-machine.ss`,
  two ABI-9 assertion lanes and the determinism lane (decision 0002), plus a
  src import-audit lane that keeps `src/` pure R6RS (decision 0007).
- **Two forced design decisions.** byte-machine's forward-only model cannot keep
  a leading `/` both as the delimiter of `//`-authority and as path content, so a
  path-absolute's dropped `/` is recovered by an `on-rooted` event (decision
  0018); and, rather than fight the machine to sub-split the authority, the
  scanner emits the five coarse components and the core owns userinfo/host/port
  and the host grammar (decision 0019, redrawing the functional-core line).
- **The scheme / first-segment ambiguity** (mode 3) is resolved with a neutral
  `leading-token` span closed at the delimiter, then a zero-width verdict —
  `on-scheme-confirmed` or `on-segment-confirmed` (decision 0004).
- **Mutation witnesses throughout**, including the two that pin the hardest
  properties: a path-absolute's `on-rooted` recovery (caught in the grammar and
  the determinism artifact at once) and collect's copy discipline (a non-copying
  shell fails only the buffer-reuse case).
- The RFC §5.4 resolution ratchet does **not** move here — resolution is M6, and
  v0.1 is resolution-first (decision 0011).

### M1 — the instrument, with no parser

- **The design and decisions 0001–0015.** The layer split, the scanner's span
  and callback surface, and where v0.1 stops. Three findings changed the
  project brief: spans cannot nest, so the full span vocabulary is declared at
  M2 rather than refined later; an empty span is observable, which carries RFC
  3986's absent-versus-empty distinction with no presence flags at all; and
  byte-machine v0.6.0 emits generated ABI 9, not the 8 the brief was drafted
  against.
- **Two spikes.** `eof-target → span-end → callback → finish` verifies, so
  decision 0004's blind mode holds; and uriparser can serve as a differential
  oracle, with three rules its documentation omits.
- **The corpus.** RFC 3986 §5.4 (42 reference-resolution vectors), §5.2.4 (two
  worked dot-segment traces, step by step) and §1.1.2 (eight example URIs) —
  derived from the vendored RFC text rather than transcribed, with a lane that
  re-derives and compares.
- **The reading machinery**: the loader, the comparator, and a two-way ratchet
  in which a deferred vector that starts passing is as much a violation as a
  claimed vector that breaks.
- **RFC 3986 Appendix A**, the collected ABNF, derived from the same vendored
  text. Decision 0012 makes it the source of the generated positive corpus, on
  the observation that an ABNF is not only an acceptor but a generator.
- **Decision 0016**: there is no allocation lane. The property belongs to
  byte-machine and is measured there; the one thing this project allocates,
  `(uri collect)`, allocates on purpose.
- **CI**: one Linux amd64 cell plus the no-Scheme build layer, Chez built from
  source and cached — **configured and committed, but never run.** The billed
  minutes for the month are exhausted, so M1's evidence is macOS arm64 locally
  and nothing else. Deferred means not run, not passing: decision 0017.
- **The build layer**, ported from chez-httparse under decision 0001's rename
  map: CMake presets, the Makefile, Chez discovery, the source and
  ahead-of-time lanes, and the harness.
- **Mutation witnesses**: 77 in the CMake suite and 67 in the Scheme suite,
  including the eight that make M1's exit criterion true — a comparator that
  always agrees, and a ratchet that fails in only one direction, are both
  caught.

[Unreleased]: https://github.com/Kiyomi-Computation-Systems/uriparse/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/Kiyomi-Computation-Systems/uriparse/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/Kiyomi-Computation-Systems/uriparse/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/Kiyomi-Computation-Systems/uriparse/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/Kiyomi-Computation-Systems/uriparse/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Kiyomi-Computation-Systems/uriparse/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Kiyomi-Computation-Systems/uriparse/releases/tag/v0.1.0
