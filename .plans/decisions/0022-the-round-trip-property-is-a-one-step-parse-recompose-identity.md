# 0022: the round-trip property is a one-step parse∘recompose identity on the once-normalized components

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §7 (the instrument table),
the [brief](../2026-09-18-chez-uri-project-brief.md) "The test instrument comes
first" (instrument #2, the round-trip property)
References:
[0008](0008-one-span-per-component-and-absent-is-not-empty.md) (absent `#f` ≠
present-empty `#vu8()`, carried through parse↔recompose),
[0011](0011-v01-is-resolution-first.md) (v0.1 is non-validating; M7 is the last
milestone before release),
[0015](0015-errata-4547-and-5428-are-adjudicated-against-the-abnf.md) (the
pattern of pinning an RFC boundary as a recorded note, not faking it),
[0020](0020-v01-normalizes-scheme-and-percent-and-defers-host-case.md) and
[0021](0021-reference-resolution-recomposes-at-m6.md) (normalize / recompose, and
the milestone-scope-decision pattern this mirrors)

## Context

M7 is the brief's round-trip property: `parse → normalize → recompose → parse`
must "reach a fixed point, and the second parse's spans must equal the first's."
`(uri recompose)` (§5.3) already shipped at M6 (decision 0021), so M7 is a
verification milestone — a property lane, no new core library — plus this record.

The loose phrasing hides two ways to state the property WRONG, both of which an
independent investigation against the RFC and the actual `(uri collect)` /
`(uri normalize)` / `(uri recompose)` code disproved:

1. **It is not a fixed point of the *normalize* operator.** Normalization is
   applied ONCE, inside the loop; the second parse re-splits bytes, it does not
   re-normalize. And normalize is **not idempotent** over v0.1's non-validating
   domain (decision 0011 accepts malformed `%`): `%%341` normalizes to `%41` on
   the first pass — the leading literal `%` is kept (its next byte is not hex),
   then `%34` decodes to the digit `4` — and `%41` normalizes to `A` on a second
   pass. A `normalize(normalize(x)) == normalize(x)` lane is a **false universal**
   that this input reddens.

2. **recompose is not invertible over *arbitrary* components.** Two scheme-absent
   shapes break `parse(recompose(c)) = c`, both from RFC 3986's own grammar:
   §4.2 (a relative reference whose first path segment contains `:`) and §3.3 (a
   no-authority reference whose path begins `//`). §5.3 recompose deliberately
   omits §4.2's disambiguating `./`.

The reconciling fact, verified against the scanner: **the parser's
first-match-wins never emits either hazard shape.** `parse "a:b"` is
`{scheme=a, path=b}`; `parse "//x"` routes the `//` through the authority
(`{authority=x, path=""}`) — RFC §3.3 forbids a `//`-leading path without an
authority, so the scanner cannot produce one. So the round trip, taken over
*parse outputs reparsed in their own mode*, holds at 100% in every mode — the
hazard is a property of recompose over **hand-built** components. §5.2.2
resolution never reaches it either, but not merely because a target carries a
scheme (a scheme-present `{authority=#f, path="//x"}` would still recompose to
`s://x` and mis-parse): its target components come from parsing the base and
reference, and neither the parse nor merge / remove-dot-segments ever synthesizes
a colon-first-segment scheme-absent path or a `//`-leading no-authority path.

## Decision

1. **The M7 exit criterion is the one-step invariant, with a single
   normalization.** For a corpus input `x` graded in parse mode `m`:

   ```
   r0 = uri-parse(m, x)                      ; require uri-parse-ok?
   n0 = normalize-components(components r0)   ; §6.2.2, applied EXACTLY ONCE
   s  = recompose(n0)                         ; §5.3
   r1 = uri-parse(m, s)                       ; SAME mode m; require uri-parse-ok?
   HOLDS  iff  uri-components=?(components r1, n0)
   ```

   The comparison is `uri-components=?`, which keeps absent (`#f`) distinct from
   present-empty (`#vu8()`). `n0` is the fixed point of the *parse∘recompose*
   round trip, reached after one normalization — not a fixed point of normalize,
   and not reached by iterating normalize to convergence. The re-parse mode must
   equal the first-parse mode (mode `uri` on a relative result raises
   `scheme-required` and makes the equality vacuous).

2. **normalize is NOT asserted to be idempotent.** The lane does not assert
   `normalize(normalize(x)) == normalize(x)`; the exit criterion does not need it
   (the second parse re-splits bytes without re-normalizing). `%%341 → %41 → A`
   is recorded here and **pinned as a case where the one-step invariant still
   HOLDS** (its `n0` path is `/%41`, and re-parsing `/%41` yields `/%41` = `n0`,
   even though `n0` is not itself a normalize fixed point). Any idempotence check
   the suite carries is explicitly scoped to well-formed-`%` inputs and labelled
   non-load-bearing.

3. **The property's true domain is parse outputs reparsed in-mode — every mode,
   including relative references.** It is broader than "absolute URIs": relative
   references round-trip too (`g`, `../g`, `?q`, `#f`, ``, `./a:b`, `//x`), because
   the scanner never emits the §4.2/§3.3 shapes. The committed corpora — the eight
   §1.1.2 example URIs and the 42 §5.4 targets — are all absolute (scheme
   present) and are graded in mode `uri`, a strict subset that additionally avoids
   the hazards even under recompose-over-arbitrary-components.

4. **recompose is NOT hardened; the two boundary shapes are pinned as expected
   non-round-trips.** Injecting §4.2's `./` into §5.3 would **diverge from the
   RFC's §5.3 recomposition algorithm**, which deliberately omits the guard —
   §4.2's disambiguation is conditional on being a *relative-path reference* and
   is the reference PRODUCER's obligation, not the generic renderer's. (It would
   not "corrupt resolution": a §4.2-faithful guard, keyed on scheme-absent, never
   fires on a resolution target, which always carries a scheme — so the reason to
   refuse it is RFC fidelity, not resolution.) A relative-reference SERIALIZER
   that applies §4.2's `./` is a distinct v0.2 function *above* recompose, whose
   reason to exist is exactly these two shapes. The two shapes are pinned in the
   suite as expected non-round-trips (parsed in mode `uri-reference`), the M7
   analog of the §5.4.2 `http:g` loophole the corpus records (decision 0001)
   and decision 0020's "normalize creates but does not remove dot-segments"
   boundary — a recorded boundary, not a silent gap and not a faked fix.

5. **Two provenances, two counts (decision 0005 item 3).** The normative
   corpora (§1.1.2, §5.4 targets) and the hand-authored round-trip vectors (which
   exercise the normalize delta and the absent/empty recovery the committed
   corpora do not) are a separate, separately-labelled set, never averaged into
   one number with the RFC's own vectors.

## Consequences

- M7 adds no new `src/` library. It adds a property lane and hand-authored
  vectors; `(uri recompose)` is unchanged from M6.
- The lane is a **universal property, not a ratchet**: it is red iff any
  in-scope vector fails the one-step identity. The §4.2/§3.3 witnesses are
  unratcheted negative cases (asserted to break, in mode `uri-reference`).
- The committed corpora alone are insufficient — they carry no uppercase scheme
  and no `%`, so normalization is the identity on them and the lane would test
  the normalize half not at all. Hand vectors are **mandatory**: empty-vs-absent
  recovered through reparse (`http://` vs `http:`, `http://a?` vs `http://a`,
  `http://a#`, `http:///p` vs `http:/p`); normalize-changes-then-stabilizes
  (`HTTP://a/b` → `http`, `%7Efoo` → `~foo`, `%2f` → `%2F`, `%2E` → a literal
  `.`); and the `%%341` non-idempotence boundary.
- This is the last implementation milestone before M8 (release v0.1). It earns
  the brief's round-trip claim by *measuring* it, which is the house rule for
  making a claim at all.

## Sequencing (M7's two slices)

This record states the whole M7 decision; the work lands across two slices, and
the pins named above (the `%%341` HOLDS case, the §4.2/§3.3 expected-non-round-
trip witnesses, and the exhaustive empty/absent hand-vector matrix) are **Slice
①**, so a reader must not expect them in Slice ⓪'s suite.

- **Slice ⓪** (shipped): the `round-trip-diff` machinery (item 1's invariant,
  exactly — one normalize, same-mode reparse, `uri-components=?`), the property
  over the normative corpora (the 8 §1.1.2 examples and the 42 §5.4 targets, mode
  `uri`), the absent/empty smoke through recompose→reparse, and one *teeth* case
  (an encoded reserved delimiter `%23` that must stay encoded — the single class
  of normalize fault the property is sensitive to, item 2's "decodes a reserved
  octet into a delimiter"). Witnessed by recompose faithfulness mutations.
- **Slice ①**: the `%%341` non-idempotence case pinned as one-step-HOLDS; the two
  §4.2/§3.3 shapes pinned as expected non-round-trips in mode `uri-reference`
  (item 4); the exhaustive empty/absent matrix (`http://a#`, `http:///p` vs
  `http:/p`, and the rest) and further normalize deltas; then the merge gate.
