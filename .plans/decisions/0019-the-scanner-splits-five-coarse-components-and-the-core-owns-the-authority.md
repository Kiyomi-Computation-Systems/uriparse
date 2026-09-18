# 0019: the scanner splits five coarse components, and the core owns the authority

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §2, §3, §5, §6
Amends: [0008](0008-one-span-per-component-and-absent-is-not-empty.md) (the span
vocabulary), [0009](0009-an-error-names-the-abnf-production-that-failed.md) (which
errors are the scanner's), and the design's layer split (§2, §5)
References: [0018](0018-path-absolute-slash-is-recovered-by-an-event.md) (the
first forward-only impossibility)

## Context

M2 Slice ① hit two impossibilities in byte-machine's forward-only, no-rewind,
one-byte model, both proven from source and both requiring workarounds: the `//`
authority vs a `/` path-absolute (decision 0018, recovered by `on-rooted`), and
the userinfo-vs-host leading token with its userinfo-`:`-vs-port-`:` twin (which
would need a neutral `authority-token` span reopened at the first `:` plus two
verdict events — a mechanism decision 0008 never anticipated, and under which its
declared `userinfo` span is not constructible at all).

Two impossibilities in the first parsing slice is a signal about the tool, not a
run of bad luck. With the bytes in hand both are trivial — RFC 3986's own
Appendix B splits a URI into its five components with a single regular
expression, and the authority sub-split is `find("@")`, `find(":")`, slice. What
makes them hard is *specifically* that byte-machine cannot look at the second
byte without committing the first, and cannot rewind. And a URI does not need
that model: it is small and bounded, a request-target is already buffered in the
request line before it is parsed, and a hand-written scan over a bytevector is
just as zero-copy. byte-machine's streaming/resumable/zero-alloc thesis is
load-bearing for HTTP bodies (chez-httparse) and thin for URIs.

The design already splits functional core from imperative shell (§2). The error
was **where the line was drawn**: 0008 pushed it deep into the scanner —
userinfo, host, port, and eventually the whole `IPv6address` grammar — as byte
spans. Those are exactly the productions byte-machine fights and the core finds
trivial.

## Decision

1. **The scanner splits the FIVE coarse components only.** Spans: `scheme`,
   `authority`, `path`, `query`, `fragment`, plus `leading-token` (mode 3) — six
   spans, no more. Its verdict events stay `on-scheme-confirmed`,
   `on-segment-confirmed` (mode 3) and `on-rooted` (decision 0018). This is
   essentially Appendix B, which byte-machine handles well; the one lookahead it
   fights (`//`) is already resolved.

2. **There IS an `authority` span** — this reverses 0008 item 3. It captures the
   whole authority between `//` and the path. There is no nesting problem,
   because there is no sub-span inside it: it is a single coarse span. Its
   presence still carries the authority's presence exactly — empty for
   `http:///p` (fires zero bytes), absent for `http:/p` (never fires) — the
   distinction 0008 exists to keep.

3. **userinfo, host and port are NOT scanner spans.** They are pure functions in
   the core over the `authority` bytevector — a find-and-slice. Because they are
   core functions and not spans, they can be added at any milestone with **no
   change to the scanner ABI**, which dissolves the breaking-change worry that
   drove 0008 to declare eight spans at M2. 0008's own `uri-components` is already
   five fields with `authority` as one (0008 item 7); this decision makes the
   whole stack agree with that shape.

4. **The host grammar moves from the scanner to the core.** `IPv4address`,
   `IPv6address`, `IPvFuture`, `reg-name` and `dec-octet` — the brief's own
   scariest estimate (150–250 byte-machine nodes for `IPv6address` alone) — are
   pure functions over the `authority`/host bytevector, each callable with a
   literal and compared to a constant. This is where the milestone plan's M4
   now lives: in the core, not the scanner.

5. **The scanner's error vocabulary is the four structural codes** — `mode-unset`,
   `scheme-required`, `scheme-forbidden`, `unexpected-eof`. Host and charset
   errors (`invalid-ip-literal`, `invalid-dec-octet`, `invalid-pct-encoded`, …)
   are the core's, raised where the core validates, and they enter a core error
   vocabulary rather than the scanner's. This narrows 0009's M2 scanner set by
   the one host code it had listed (`invalid-ip-literal`).

6. **byte-machine stays — this is a rebalance, not a replacement.** The coarse
   split is still streaming, resumable and allocation-free, still a committed
   reviewable artifact, and still a second consumer that keeps the generator
   honest. What changes is that the structured parsing of bounded substrings —
   the part with the local ambiguities — moves to the layer built for it.

## What this rules out

**The neutral-`authority-token`-plus-verdicts sub-split in the scanner.** It is
constructible (a spike proved reopen-after-close is legal), but it pays real ABI
complexity — `userinfo` becomes a verdict rather than a span, `host`/`port`
become dual-sourced — to keep in the forward-only machine work the core does in
a few lines. Rejected in favour of the layer line above.

**Hand-writing the whole scanner and dropping byte-machine.** Considered. It
would make every lookahead trivial, but it discards the streaming coarse split
and byte-machine's second-consumer role for a problem the rebalance already
solves. Not necessary to get the win.

## Consequences for the plan

- M2's scanner ships five coarse components; `(uri collect)` fills the five-field
  `uri-components` (decision 0008 item 7) directly. The exit criterion — route on
  a path, read a raw query — is unaffected.
- The userinfo/host/port split and the host grammar are core work, folded into
  the M4/M5 core milestones, not a scanner slice. `(uri vocabulary)` carries the
  six scanner spans and four scanner errors; the core's names live with the core.
