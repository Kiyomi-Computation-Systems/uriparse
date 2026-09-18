# 0009: an error names the ABNF production that failed

Date: 2026-09-18
Status: accepted, then **amended in part by [0019](0019-the-scanner-splits-five-coarse-components-and-the-core-owns-the-authority.md)**
Plan: [the design](../2026-09-18-chez-uri-design.md) §3.4
References: `chez-httparse` decision 0013 (the shape this replaces)

> **Amendment (0019).** Item 6 lists `invalid-ip-literal` in v0.1's structural
> set, but 0019 moved the host grammar into the core, so `invalid-ip-literal` is
> now a CORE error, not a scanner one. The SCANNER's error vocabulary is the four
> structural codes -- `mode-unset`, `scheme-required`, `scheme-forbidden`,
> `unexpected-eof`. The rule (an error names the production; the offset is not
> part of the identity; structural and charset failures are distinct codes) is
> unchanged and now governs both the scanner's four codes and the core's set.

## Context

`chez-httparse` decision 0013 settled that error identity is llhttp's code and
reason pair — inherited wholesale, because conformance to llhttp was the thesis
and upstream's codes were part of what conformance meant.

**There is nothing to inherit here.** RFC 3986 defines a grammar and does not
define error codes. So the error vocabulary is this project's to invent, which
makes it public API: it is what a consumer branches on, what a fixture asserts,
and what the ratchet pins. Inventing it ad hoc, one error node at a time, is how
it ends up with three spellings of the same failure.

## Decision

1. **An error names the ABNF production that failed**, in the RFC's own
   spelling, hyphenated: `invalid-pct-encoded`, `invalid-dec-octet`,
   `invalid-scheme`, `invalid-reg-name`. Not the node that raised it, not the
   byte that offended, not a prose summary. A reader with the RFC open can find
   the production in one search.

2. **The offset is not part of the identity.** `parser-error-offset` carries it
   already, exactly and for free. An error code that embeds a position produces a
   vocabulary that grows with the input.

3. **The reason string is a sentence naming the production and what was expected
   there.** It is for a human reading a trace. **Nothing asserts on reason text**
   — fixtures assert on the code — so a reworded reason is never a red lane, and
   a renamed code always is.

4. **Structural and charset failures are distinct codes even where they happen at
   the same byte.** `invalid-pct-encoded` (a `%` not followed by two `HEXDIG`) is
   not `invalid-path`. The two are diagnosed at the same offset and mean
   different things to a caller.

5. **Two codes exist that name no production**, and they are the only ones:
   - `mode-unset` — no mode was chosen
     ([0004](0004-the-ambiguity-is-the-callers-and-the-mode-is-a-settable-field.md)
     item 2)
   - `unexpected-eof` — input ended inside a production that was not yet
     satisfiable. The machine default EOF error.

6. **v0.1's set is small, and that is a statement about v0.1, not about the
   rule.** v0.1 splits and does not validate charsets
   ([0011](0011-v01-is-resolution-first.md)), so its structural set is roughly:
   `mode-unset`, `scheme-required` (mode 1 reached a delimiter with no `:`),
   `scheme-forbidden` (mode 2 found a `:` in the first segment),
   `invalid-ip-literal` (an unclosed `[`), `unexpected-eof`. The charset codes
   arrive with the charset lanes and not before — a declared error no reachable
   path raises is a promise the parser does not keep.
