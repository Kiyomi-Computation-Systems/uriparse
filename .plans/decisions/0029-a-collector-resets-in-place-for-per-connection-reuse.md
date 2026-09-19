# 0029: a collector resets in place for per-connection reuse

Date: 2026-09-19
Status: accepted
Plan: GitHub issue #11 (a server parses one request-target per request; `uri-parse`
allocates a fresh parser and two `eq-hashtable`s per call). Additive, pure Scheme.
References:
[0002](0002-byte-machine-consumption-the-gitlink-pin-and-the-generated-abi.md)
(byte-machine is consumed by gitlink at v0.6.0 — its runtime exports the primitives
this reuses),
[0008](0008-one-span-per-component-absent-is-not-empty.md) (the collector's mutable
state — the span table, the offset table, and the verdict flags — is exactly what a
reset must clear),
[0016](0016-there-is-no-allocation-lane.md) (there is NO standing allocation lane —
allocation is byte-machine's measured property, and `(uri collect)` allocates on
purpose; so #11's "measure" is a one-shot recorded benchmark, NOT a new lane).

## Context

`(uri collect)`'s `uri-parse` builds a fresh collector every call, and a collector
allocates a byte-machine parser plus two `eq-hashtable`s (the span `table` and the
`offsets` table). A server parsing one request-target per request pays that fixed
per-call cost regardless of input size (the issue's planning research measured it at
~55–65% of a short-target parse). The collector already exposes a streaming interface
(`make-uri-collector` / `uri-collect-feed!` / `uri-collect-finish!`) but no way to
REUSE one across parses.

The one correctness risk is the MODE. The collector's parser is built with the mode as
an embedder field-override (`make-parser`'s fourth argument,
`(list (cons 'mode (uri-mode-value mode-sym)))`). A reset that dropped it would leave
the reused parser in `unset` mode, refusing at offset 0. But byte-machine's
`parser-reset!` restores the parser's field-VALUES (slot 8) from the canonical MERGED
initials (slot 17 — the declared initials with the embedder overrides already applied),
not from the bare declared initials (slot 9): `runtime.sls` states "an embedder-chosen
mode survives a reset" and "a reset returns the parser to its just-constructed state
INCLUDING the … overrides." So the mode survives, and per-connection reuse is sound.

## Decision

1. **A collector gains a `reset!` operation that returns it to its just-constructed
   state, in place.** A new `uri-collector-reset! : Collector -> unspecified` sends the
   collector closure a `reset!` message, which: calls `parser-reset!` on the captured
   parser (resetting its state while PRESERVING the embedder-chosen mode, above),
   `hashtable-clear!`s the span `table` and the `offsets` table, and `set!`s `present`
   `'()`, `rooted?` `#f`, `verdict` `#f`. Nothing is reallocated — the same parser and
   the same two hashtables are cleared and reused.

2. **`uri-parse` and the one-shot path are UNCHANGED.** `uri-parse` still builds a fresh
   collector per call (the correct default for a one-shot caller). `reset!` is opt-in,
   for an embedder holding one collector per connection: `feed!` … `finish!`,
   `reset!`, `feed!` … `finish!`, and so on. The result of a reset-and-reparse is
   byte-identical to a fresh collector's — that is the property the lane pins.

3. **The reuse is measured once, not lane-guarded (0016).** #11 asks to "measure before
   optimising." Decision 0016 forbids a standing allocation lane, so the win is
   confirmed by a ONE-SHOT benchmark (a fresh-collector-per-parse loop vs a
   reset-and-reuse loop over a short target) whose numbers are recorded in the ledger
   close-out as disclosed evidence — not added as a regression lane. The correctness
   lane (reuse-equivalence + mode survival) is the standing guard; the speed is
   evidence, not a gate.

## Consequences

- `(uri collect)` gains one export (`uri-collector-reset!`) and one closure message;
  no new library, no scanner/grammar change, no change to `uri-parse`,
  `uri-parse-validate`, or the authority-form pair.
- A server (chez-http-server) can keep one collector per connection and drop the
  per-request allocation; the issue's workaround (accept the allocation for v1) retires.
- Like M3/M4/M9, this feature does NOT touch the release-scoped README/CHANGELOG at its
  merge; any user-facing note rides the next release.
