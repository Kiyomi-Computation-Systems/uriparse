# 0011: v0.1 is resolution-first — it splits and resolves, it does not validate

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §6

## Context

The brief's own standing risk 3 says it: *"'Comprehensive' has no natural
stopping point. M2 unblocks the actual consumer. Everything after M2 is for the
library's own sake, which is a fine reason, but it should be a decision rather
than a drift."* This is that decision.

The brief's order was M1 → M2 → M3 (charset) → M4 (host) → M5 (percent and
normalization) → M6 (dot segments and resolution) → M7 (recomposition) → M8
(release). Under it, the two milestones with **no oracle at all** sit between the
consumer-unblocking work and the one milestone that has a normative corpus.

## Decision

1. **v0.1 is M1 → M2 → M5 → M6 → M7 → release.** The brief's **M3 (charset
   validation) and M4 (the host grammar) are v0.2.**

2. **The reason is where the evidence is.** §5.4 is the only normative corpus
   this project has, and reference resolution depends on component *splitting*
   (M2) and on nothing in M3 or M4. Taking M5–M7 next reaches "passes all of
   §5.4" on the highest-confidence work available. `chez-http-server` is
   unblocked at M2 under either order, so nothing downstream pays for the
   reordering.

3. **M6 stays gated on the §5.4 vectors at 100%.** It is the one milestone with
   a normative corpus: it either passes all of it or it is not done.

4. **v0.1 is a URI splitter with a complete core — not a validator — and
   `README.org` says so in those words.** It will accept bytes the ABNF rejects:
   `http://exa mple.com/`, `%ZZ`, a malformed `IPv6address`. **"RFC 3986
   compliant" is a claim v0.1 has not earned** and does not make. The house rule
   is that a property is measured or it is not claimed.

5. **The deferred work is deferred, not dropped**, and the milestone numbers stay
   the brief's so that document remains readable. M3 and M4 keep their numbers
   and move to v0.2.

## Two sizing corrections carried into the deferral

**M3 is cheaper than the brief reads.** M2 already builds a byte-dispatch node
per component to find delimiters. Charset validation changes those nodes'
*fallback edge* from "accept" to "error" and adds two nodes per component for
`pct-encoded`. The node count barely moves. **So M3's timing may be revisited at
M2 as a scope decision rather than a re-plan**, and this record is what that
revisit checks its estimate against.

**M4's `IPv6address` is smaller than budgeted.** The brief estimates 150–250
nodes and reserves a `decision`-callback fallback. That is ABNF's shape, not the
grammar's: ABNF cannot count, so the RFC writes nine alternatives for what is a
three-counter machine. `byte-machine` has uint fields, `field-branch` and
`integer-accumulate`; tracking groups-seen, saw-`::` and hex-digit-count and
routing on `:` / `.` / `]` should come in near 40–60 nodes. `dec-octet` falls out
of the same observation — accumulate into a **u8** and the overflow edge *is* the
`> 255` test, leaving one extra check ("a leading `0` means length 1"), which
also rejects `0000`. **Measure at M4 as the brief says; do not reserve the
fallback.**
