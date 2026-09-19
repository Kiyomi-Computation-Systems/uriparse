# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/Kiyomi-Computation-Systems/uriparse/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Kiyomi-Computation-Systems/uriparse/releases/tag/v0.1.0
