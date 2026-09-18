# 0014: the uriparser differential is a worklist, not a verdict

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §6
Witness: [`.plans/spikes/2026-09-18-uriparser-oracle-probe.c`](../spikes/2026-09-18-uriparser-oracle-probe.c)
References: [0003](0003-the-normative-reference-is-rfc-3986.md),
[0006](0006-ci-covers-the-linux-cell-alone.md),
[0008](0008-one-span-per-component-and-absent-is-not-empty.md)

## Context

[0003](0003-the-normative-reference-is-rfc-3986.md) item 2 says no
implementation is authoritative and that a differential's disagreements are
cases to adjudicate against the ABNF. That leaves the question of *which*
implementation, and it is not a free choice.

[uriparser](https://github.com/uriparser/uriparser) is the one that fits, for a
reason specific to this parser's shape: its `UriTextRangeA` is a
`{first, afterLast}` pointer pair **into the original input**, so subtracting
the base gives byte offsets. That is our span model, component for component.
Every other candidate — `python-hyper/rfc3986`, `uri-js` — hands back decoded
strings, so a diff against one argues about encoding before it ever argues about
parsing.

It also reaches past the scanner: `uriAddBaseUriA` is §5.2 resolution,
`uriNormalizeSyntaxA` is §6, `uriToStringA` is §5.3. One oracle covers M5, M6
and M7 — which is [0011](0011-v01-is-resolution-first.md)'s whole v0.1.

Before any of that could be relied on, one undocumented thing had to be settled:
how uriparser distinguishes *absent* from *present-and-empty*.
[0008](0008-one-span-per-component-and-absent-is-not-empty.md) rests on that
distinction and `Uri.h` does not state it. The probe named above settled it, and
found three more things the documentation omits.

## Decision

1. **The API is used. The test suite is never opened.** uriparser's library is
   BSD-3-Clause; *its test suite is LGPL-2.1-or-later* and its fuzzing code is
   Apache-2.0. Using the API alone makes the licence question disappear rather
   than requiring it to be managed. Nothing under uriparser's `test/` is read,
   transcribed, or vendored.

2. **It is local, opt-in, and off in CI.** Built only under `-DURI_ORACLE=ON`,
   against a locally installed uriparser.
   [0006](0006-ci-covers-the-linux-cell-alone.md)'s one cell does not pay for
   it. This is `chez-httparse` decision 0010's live-oracle shape.

3. **The lane fails on an UNCLASSIFIED disagreement, never on a disagreement as
   such.** Every divergence is either adjudicated against the ABNF and given a
   record naming the production and quoting the clause, or the lane is red.
   `chez-httparse` decision 0018's rule, transferred. **The output of this lane
   is a worklist. It is not a verdict**, and no milestone exits on it.

4. **The version is recorded with every run.** A differential against an unnamed
   version is not reproducible. Probed at **uriparser 1.0.2**.

5. **Three shim rules, from the probe rather than from the documentation.**

   - **An empty range's position is never read.** Empty `userInfo`, `port`,
     `query` and `fragment` point into the input, but empty `host` and empty
     path *segments* point at a static sentinel: `http:///b` reported its host
     at offset 266872 of a nine-byte string. The shim emits `EMPTY` as a value
     distinct from both `ABSENT` and `[from,to)`, and never subtracts or
     dereferences an empty range.

   - **The path is reconstructed as text, not by pointer arithmetic.**
     `pathHead->first .. pathTail->afterLast` is garbage whenever an end segment
     is empty — every path ending in `/`, every path containing `//`.
     `http://a/b/` collapsed to `[9,266922)`. The shim joins the segments with
     `/`, prefixed by `/` iff `(host present && pathHead != NULL) || absolutePath`.
     Verified lossless on `http://a/`, `http://a//b`, `http://a/b/`, `http://a`,
     `foo:/bar`, `b/c` and `/`.

   - **`absolutePath` does not mean the path is absolute**, and `pathHead ==
     NULL` does not mean the path is empty. `Uri.h` says `absolutePath` is
     "always `URI_FALSE` for URIs with host", so `http://a/b` reports `FALSE`;
     and `/` reports `pathHead = NULL` with `absolutePath = TRUE`, for a path of
     `/`.

6. **The comparison is against mode 3 only.** uriparser has no mode — `a:b`
   comes back as scheme `a` plus path `b`, and `b/c` as `path-noscheme`. It
   always parses a `URI-reference`, so it can only be diffed against
   [0004](0004-the-ambiguity-is-the-callers-and-the-mode-is-a-settable-field.md)'s
   mode 3. Modes 1 and 2 are strictness this oracle cannot express.

## The finding that outlived the probe

Rule 5's first bullet is not a uriparser workaround. **Our own machine carries
the same constraint for unrelated reasons** — an empty span closing at
`parser-finish!` re-anchors its mark to 0 and reports `(0 0)` rather than
`(1 1)` (design §3.5 item 3, witnessed by the sibling spike). Two independent
implementations, one invariant: **an empty component carries emptiness, never a
position.**

That belongs in the comparator's design rather than in a note about this
oracle, and `(uri collect)` is written to it
([0008](0008-one-span-per-component-and-absent-is-not-empty.md) item 7).
