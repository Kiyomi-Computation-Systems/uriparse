# 0004: the scheme / first-segment ambiguity is the caller's, and the mode is a settable field

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §4
References: `chez-httparse` decisions 0021 (mechanism) and 0017 (reasoning)

## Context

`scheme` and the first path segment share a prefix language:

- `foo:bar` — `foo` is a **scheme**
- `foo/bar` — `foo` is a **path segment** (`segment-nz-nc`, which excludes `:`)
- `foo` alone, at end of input — a path segment

llhttp dodges this by *requiring* `//` after a scheme, which is why `urn:isbn:x`
and `mailto:a@b` are outside its URL machine entirely. RFC 3986 has no such
luxury: `path-rootless` is a first-class alternative to `hier-part`.

`byte-machine` is forward-only with no backtracking, and `make-span-declaration`
binds a span to its callbacks **at build time**. An optimistically-opened
`scheme` span cannot be renamed when the delimiter disappoints.

## The ambiguity is narrower than it looks

`+` is `sub-delims`; `-` and `.` are `unreserved`. So **`scheme`'s charset is a
strict subset of `segment-nz-nc`'s**, and `scheme` merely additionally requires
its first byte to be `ALPHA`. The two readings stay live over exactly the same
prefix and are decided by the first byte that is either a delimiter (`:` →
scheme; `/`, `?`, `#`, EOF → segment) or a byte inside `segment-nz-nc` and
outside the scheme set (e.g. `_`, `~`, `%`, `!`, `@` → segment).

**There is no point at which the machine must know something it has not yet
seen.** Only the span *name* is undecidable in advance, which is a naming
problem and not a parsing one.

## Decision

1. **The mode is a settable `uint` field named `mode`**, width 8, declared
   initial `0`, read at `make-parser`. This is `chez-httparse` decision 0021's
   mechanism; its 0017's reasoning — that the mode is not derivable from the
   bytes and the fall-through must be an error — transfers unchanged.

   | value | name | production |
   |---|---|---|
   | 0 | *unset* | — |
   | 1 | `uri` | §3 `URI` |
   | 2 | `relative-ref` | §4.2 `relative-ref` |
   | 3 | `uri-reference` | §4.1 `URI-reference` |

2. **`0` refuses at offset 0** with the code `mode-unset`. A field initial
   cannot be made mandatory, so the alternative to a refusing default is a
   silently permissive one — a caller who meant `uri` and forgot would quietly
   accept relative references. A refusal is not a guess. This is the trade
   `chez-httparse` decision 0021 names as "the one thing that got later, not
   better", taken with eyes open: it costs one wasted feed and an error code
   that exists to catch a caller mistake.

3. **Modes 1 and 2 have no ambiguity, and open their spans directly.** The
   caller has removed it. This is almost certainly the real consumer's case:
   RFC 9112 gives a request-target as origin-form, absolute-form,
   authority-form or asterisk-form, and a server knows which it expects from the
   method and context.

4. **Mode 3 opens a neutral span and confirms afterwards.** `leading-token`
   opens over the ambiguous prefix, closes at the delimiter, and *then* a
   zero-width event fires naming the verdict — `on-scheme-confirmed` or
   `on-segment-confirmed`. The event comes after the close because the verifier
   refuses a callback node reachable with a span active (`span-active-at-pause`,
   `verify.sls:1798`); the three routes may converge afterwards because all
   three have closed whatever they opened, which is what the span lattice's
   merge requires.

5. **The leading-token scanner is built three times.** Same handful of nodes,
   different span name, different verdict, converging on one shared
   continuation. That is a duplicated scanner, not a duplicated grammar — the
   two grammars differ in one decision, not throughout, so two whole machines
   would be overkill.

6. **Mode 3's price is stated in the ABI, not hidden.** When the verdict is
   `segment`, the path is the concatenation of the `leading-token` span and the
   `path` span, and `(uri collect)` stitches them. Modes 1 and 2 exist so a
   caller who knows the form never pays this.

## What this rules out

**"Parse in mode 1; on error, re-parse in mode 2."** That is host-level
backtracking. It forces the caller to buffer the entire reference before it can
commit to a reading, which is the one thing a streaming scanner exists to avoid,
and it turns a resumable parse into a two-pass one. Rejected.

**A `decision` callback at the delimiter.** The host knows nothing the machine
does not. It would be an ask with no answer.
