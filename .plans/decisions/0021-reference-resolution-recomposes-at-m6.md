# 0021: reference resolution recomposes at M6, so §5.3 lands with §5.2

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §5 (the core library table),
§2 (the layer split), §3.2 (absent ≠ empty)
References:
[0005](0005-the-corpus-is-the-rfcs-own-vectors.md) (RFC 3986's own vectors are the
anchor; §5.4 is the only normative corpus, given as strings),
[0008](0008-one-span-per-component-and-absent-is-not-empty.md) (a component is a
bytevector or `#f`; §5.2.2 and §5.3 branch on *defined*, not nonempty),
[0011](0011-v01-is-resolution-first.md) (v0.1 is resolution-first; item 3 gates M6
on all 42 §5.4 rows passing),
[0020](0020-v01-normalizes-scheme-and-percent-and-defers-host-case.md) (the M5→M6
dot-segment ordering hazard; the milestone-scope-decision pattern this mirrors)

## Context

The brief's milestone table splits the resolution work in two:

- **M6 — dot segments and reference resolution**: §5.2.4 `remove_dot_segments`
  and §5.2.2 reference resolution, **gated on the §5.4 vectors passing 100%**.
- **M7 — recomposition and the round-trip property**: §5.3 component
  recomposition, plus the round-trip lane.

Taken literally, that places §5.3 recompose *after* the milestone whose exit
criterion depends on it. Two facts make that ordering unworkable:

1. **§5.2.2 is defined in terms of §5.3.** RFC 3986 §5.2.2's own pseudocode ends
   by producing the target URI `T` and then, in the words of the section, the
   result is obtained "by recomposing ... using the algorithm of Section 5.3."
   Reference resolution's *output* is a string, and the last step of the standard
   algorithm is recomposition. A resolver that stops at components has not
   finished the algorithm the RFC writes.

2. **The corpus and its comparator are string-shaped.** Decision 0005 takes §5.4
   as `(<section> <reference> <target>)` rows whose `target` is a URI **string**
   (`http://a/b/c/g`), and M1's `compare-target : String String (Option String) ->
   (Option String)` compares an expected string to an actual string. To turn a
   §5.4 row green, M6 must produce a resolved *string*.

There are two ways to produce that string, and the choice matters for the oracle:

- **(A) Recompose the resolved components to a string** and compare byte-exact to
  the published §5.4 target.
- **(B) Reparse the expected target string into components** with the M2 parser
  and compare component-wise, deferring recompose to M7.

(B) puts `(uri collect)` — the code under test's sibling — into the *oracle*
path: a resolution bug and a parsing bug could cancel and both stay hidden, and
the RFC's published *string* (the actual normative artifact) would be relitigated
through this project's own parser before it ever reached the comparison. That
violates the discipline decisions 0005 and 0012 hold to — the numbers come from
the oracle, never from the code under test.

## Decision

1. **`(uri recompose)` (§5.3) lands at M6, not M7.** It is a pure total function
   `uri-components -> Bytevector`: append `scheme ":"` if the scheme is defined;
   `"//" authority` if the authority is defined; the path always; `"?" query` if
   the query is defined; `"#" fragment` if the fragment is defined. Emission is
   guarded by **defined** (`#f` vs present), not by nonempty (decision 0008): a
   defined-but-empty authority still emits `//`, a defined-but-empty query still
   emits `?`, and the path is emitted unconditionally (it may be empty).

2. **The §5.4 lane uses path (A): recompose-and-compare-strings.** For each row,
   the lane parses the base (mode 1) and the reference (mode 3) via `(uri
   collect)`, resolves per §5.2.2, recomposes per §5.3, and compares the
   recomposed bytes' `utf8->string` **byte-exact** to the published target. The
   corpus stays a pure string oracle; the parser is not in the grading path for
   the *expected* value.

3. **M7's thesis is unchanged and is not recompose-from-scratch.** M7 owns the
   **round-trip property** — parse → normalize → recompose → parse reaches a fixed
   point, and the second parse's spans equal the first's — over the generated
   corpora (abnfgen, decision 0012), which is a strictly stronger claim than
   "recompose renders a resolved target." Any recompose hardening M7 needs (e.g.
   the round-trip's fixed-point edge cases) builds on the §5.3 function landed
   here. The milestone boundary moves by one library; the theses do not overlap.

4. **Resolution does not normalize; the corpus does not need it.** §5.2.2 is
   resolution, not §6 normalization — they are separate operations. The §5.4 rows
   carry no percent-encoding and no case folding to normalize, so M6's gate
   resolves the components **as parsed**. Decision 0020's ordering note —
   normalize-before-resolve, because `pct-normalize` manufactures dot-segments
   from `%2E` — is a property of the *public composition* a caller builds
   (`normalize` then `resolve`), documented on `(uri resolve)`, and is **not**
   exercised by the raw §5.4 corpus. M6 does not silently normalize inside
   `resolve`; a caller who wants both composes them, in that order.

## Consequences

- M6 ships **three** core libraries, not two: `(uri path)` (§5.2.4 + §5.2.3),
  `(uri resolve)` (§5.2.2), and `(uri recompose)` (§5.3). `(uri resolve)` imports
  `(uri path)`, `(uri recompose)` and `(uri components)`; the §5.4 lane imports
  `(uri collect)` for the base/reference parse.
- The exit gate is unchanged in spirit: all 42 §5.4 rows read `passing` on the
  two-way ratchet, and nothing else moves. The gate is only *reachable* because
  recompose is present to render the target.
- `(uri recompose)` is written once, here, and reused unchanged by M7's round-trip
  lane — there is no second recompose. Splitting it across milestones would have
  meant either a throwaway renderer at M6 or an untestable resolver, and both are
  worse than moving the boundary by one small, fully-specified function.
- This is the M6 analog of decision 0020: a milestone-scope call, forced by the
  RFC's own algorithm and the corpus's shape, recorded before Slice ⓪ rather than
  discovered at the merge gate.
