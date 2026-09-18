# Changelog

All notable changes to this project are documented here. This project has not
been released; everything below is unreleased work toward v0.1.

## [Unreleased]

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
