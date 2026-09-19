# 0026: authority-form is a shell splice — parsed lenient, validated strict

Date: 2026-09-19
Status: accepted
Plan: [the brief](../2026-09-18-chez-uri-project-brief.md) (§"The one hard design
question" names RFC 9112's four request-target forms; §"Out of scope" draws the
WHATWG-URL "separate machine" line this record distinguishes authority-form from)
and [the design](../2026-09-18-chez-uri-design.md) §5 (the `(uri collect)` shell).
Source grammar: **RFC 9112 §3.2.3** (`authority-form`), reusing RFC 3986 §3.2's
`host` / `port`.
References:
[0003](0003-the-normative-reference-is-rfc-3986.md) (RFC 3986 is normative for the
`host`/`port` productions authority-form reuses; disagreement adjudicated against
the ABNF),
[0004](0004-the-ambiguity-is-the-callers-and-the-mode-is-a-settable-field.md) (the
mode field selects an RFC 3986 production; item 3 names RFC 9112's origin- /
absolute- / authority- / asterisk-forms as the caller's context — authority-form
is the one with no RFC 3986 production, so no mode reaches it),
[0009](0009-an-error-names-the-abnf-production-that-failed.md) (an error names the
rule it enforces, in the spec's spelling, and carries an offset; item 6: a declared
code needs a reachable path),
[0011](0011-v01-is-resolution-first.md) (v0.1 is a lenient splitter, NOT a
validator; the lenient-parse / separate-validate split this record mirrors),
[0019](0019-the-scanner-splits-five-coarse-components-and-the-core-owns-the-authority.md)
(the forward-only scanner does the coarse split; the core/shell owns what the
machine cannot do cleanly — here, a request-target form with no RFC 3986 production),
[0024](0024-charset-validation-is-the-cores-over-the-split-components.md) (item 3:
the offset seam — the shell records each component's absolute start, rebased by
`uri-parse-component-offset`), and
[0025](0025-the-host-grammar-is-the-cores-over-the-opaque-authority.md)
(`(uri host)`'s `validate-authority` / `authority-host-span`, reused here for the
strict path), plus the milestone-scope-decision pattern 0020–0025 share.

## Context

GitHub issue #9: a `CONNECT` request-target is an **authority-form** target —
`host:port`, with no scheme and no `//` — and RFC 9112 §3.2.3 gives it its own
production:

```
authority-form = uri-host ":" port          ; RFC 9112 §3.2.3
```

It is a strict SUBSET of RFC 3986 §3.2's `authority = [ userinfo "@" ] host
[ ":" port ]`: **no `userinfo`**, a **required port** (the `":"` is not optional and
§3.2.3's prose is MUST-level that a real port is sent), and — being neither a `URI`
nor a `relative-ref` — categorically **no path / query / fragment**.

The scanner has no production for it. Decision 0004's three modes are RFC 3986
productions (`uri`, `relative-ref`, `uri-reference`); authority-form has no RFC 3986
production, so none of them parse `host:port` as an authority — measured: in
`relative-ref` mode `example.com:443` raises `scheme-forbidden` (the `:` reads as a
first-segment scheme colon), and in `uri-reference` mode it reads `example.com` as a
scheme and `443` as a path.

But authority-form is NOT a WHATWG-style divergence — the brief's out-of-scope note
reserves "a separate machine with a separate corpus" for a *different normative
reference*. Authority-form reuses RFC 3986's own `host`/`port`; it is exactly "an
RFC 3986 authority in isolation." So the honest reach is not a fourth machine (ABI
churn, a new grammar, a new corpus for the same productions) but the shell splice
the issue proposes: prepend `//`, parse in `relative-ref` mode — which opens an
`authority` span on `//` — and re-map offsets. Measured over an 11-input battery: the
`authority` component lands at spliced offset **2 in every case**, no structural
error ever falls inside the `//` prefix, and only a trailing `/path` / `?query` /
`#fragment` produces a non-empty path/query/fragment. This extends decision 0019's
line: the scanner does the coarse split, the shell owns the authority-form reach.

## Decision

1. **Placement: a pure `(uri collect)` shell splice — no scanner or grammar change.**
   M9 adds two exports to `(uri collect)` and touches nothing else in the parse path:
   the `(generated uri-scanner)` artifact, `(uri grammar)`, and the ABI/determinism
   lanes are untouched. The reach is the `//` splice through the existing
   `relative-ref` machine, honouring 0019 (the core/shell owns what the forward-only
   scanner has no clean production for) and the brief's "not a separate machine — it
   reuses RFC 3986's productions" distinction.

2. **Two entry points, mirroring `uri-parse` / `uri-parse-validate` (0011).**
   - `uri-parse-authority-form : Bytevector -> uri-parse-result` — the LENIENT
     structural parse. Splice `//`, parse `relative-ref`, re-map offsets by −2
     (item 3), and reject a result carrying a component authority-form has no room
     for — a non-empty `path`, or a present `query` or `fragment` — as
     `not-authority-form`. LENIENT within the authority: `userinfo`, a missing port,
     and charset faults are NOT judged here, matching `uri-parse`'s non-validating
     stance (a malformed `%` is content, not an error).
   - `uri-parse-authority-form-validate : Bytevector -> uri-parse-result` — the
     STRICT RFC 9112 form. Everything the lenient one does, then `validate-authority`
     (the RFC 3986 host grammar, 0025) over the host:port, then the two
     authority-form-specific rules: reject `userinfo` (`userinfo-forbidden`) and
     require a non-empty port (`port-required`).

3. **The offset re-map is −2, uniform and provably safe.** The spliced `//` puts the
   authority at offset 2 in every case, and a `uri-parse-result` carries an absolute
   offset in exactly two places — every `cdr` of the `offsets` alist (each present
   component's start) and the scalar `error-offset`. Both have 2 subtracted. No
   structural error can land inside the `//` prefix (the `authority` always opens at
   offset 2, so any structural `error-offset` is ≥ 2 and stays ≥ 0). The
   authority-form-specific codes (`not-authority-form` / `userinfo-forbidden` /
   `port-required`) are reported in ORIGINAL coordinates: the forbidden component's
   start, the `@`, and the authority's end respectively. The re-map is witnessed by a
   mutation that drops the −2 (every corpus offset reddens by 2).

4. **The strict path reports the leftmost fault (M3's lesson).** Order: (a) the
   structural `not-authority-form` (path/query/fragment present) — the input is not even
   a bare authority; (b) `userinfo-forbidden` — a genuine userinfo `"@"` is one BEFORE
   the first `"["` (an IP-literal host opens `"["`, and a `"@"` INSIDE `"[...]"` is
   literal bytes, not a delimiter — RFC 3986 §3.2.2). Detected bracket-aware and
   reported at that `"@"`; it SHORT-CIRCUITS (validate-authority is not also run — a
   forbidden userinfo is already the leftmost fault, and its `"@"` precedes the host);
   (c) `validate-authority`'s host/port codes (`invalid-reg-name`, `invalid-ip-literal`,
   `invalid-port`, …), reported at their authority-relative index (= the caller offset,
   authority at 0); (d) `port-required` — no `:` or an empty port — at the authority's
   end, using `authority-host-span` (0025) for the host end. `(uri collect)` already
   imports `(uri host)` (M4). **Amended at the merge gate:** an earlier draft located
   userinfo via `authority-host-span` alone (a bare first-`"@"` scan), which mis-fired
   `userinfo-forbidden` on a bracketed `"@"` like `[a@b]:443`; the bracket-aware rule
   above (a `"@"` before the first `"["`) fixes it, so `[a@b]:443` falls through to
   `validate-authority` → `invalid-userinfo` (as M4 reports for `http://[a@b]`), and a
   corpus row pins both directions.

5. **Three new authority-form error codes, exported from `(uri collect)`.**
   `not-authority-form` (a path/query/fragment is present — the structural floor,
   raised by BOTH functions), `userinfo-forbidden` (authority-form has no
   `userinfo` — strict only), and `port-required` (authority-form requires a
   port — strict only). Each names the RFC 9112 §3.2.3 rule it enforces (0009's
   spelling convention: `port-required` / `userinfo-forbidden` echo the scanner's
   `scheme-required` / `scheme-forbidden`). They are neither scanner codes
   (`(uri vocabulary)`) nor RFC 3986 host codes (`(uri host)`) — they are RFC 9112
   authority-form codes, so they live with the authority-form parser, exported as
   `uri-authority-form-error-codes` / `uri-authority-form-error-code?`. Each has a
   reachable path (item 3's leftmost order gives one input per code).

6. **The corpus is hand-derived from RFC 9112 §3.2.3, labelled, and counted apart.**
   RFC 9112 is NOT vendored (only RFC 3986 is, under `test/vendor/`), so — as with the
   M4 negative corpus (0025 item 7) — the authority-form corpus is HAND-DERIVED from
   §3.2.3, not extracted, and says so in a `PROVENANCE` beside it. It holds valid
   CONNECT targets accepted by BOTH functions (`example.com:443`, `[::1]:443`,
   `[2001:db8::1]:8080`) and one rejection row per class in ORIGINAL coordinates:
   `not-authority-form` (`host:443/p`, `host:443?q`, `host:443#f`), `userinfo-forbidden`
   (`user@host:443`), `port-required` (`host`, `host:`), and a host-charset row through
   `validate-authority` (`ho st:443` → `invalid-reg-name`). It is separate from the
   §1.1.2 / §5.4 / M3 / M4 corpora and gated by exact code + absolute offset, not a
   ratchet. Vendoring RFC 9112 and an authority-form generator stay deferred tooling
   (the 0012 line), not silently skipped.

7. **Sequencing: M9 folds into the v0.2 release; it does NOT touch the release-scoped
   README OR CHANGELOG.** Exactly as M3 and M4 did (0025 item 8), a v0.2 FEATURE
   milestone leaves the release-scoped docs alone: `README.org` is stamped "Status:
   v0.1.0 — released" and describes the frozen tag, and the CHANGELOG `[Unreleased]`
   is left EMPTY for the v0.2 RELEASE milestone to consolidate into one `[0.2.0]`
   section covering M3 + M4 + M9. Adding a lone authority-form entry now — without the
   larger charset/host validation M3/M4 also deferred — would make a lopsided
   changelog and break that precedent. (An earlier draft of this item had M9 write an
   `[Unreleased]` entry; corrected before the merge gate.) M9's honesty obligation is
   discharged NOW in the code docs (the function docstrings), decision 0026, and the
   ledger; the user-facing README/CHANGELOG entries ride with the v0.2 release.

## Consequences

- M9 adds NO `src/` library — two exports and three error codes in `(uri collect)`,
  reusing `(uri host)`'s `validate-authority` / `authority-host-span` and the 0024
  offset seam. `src/uri/host.sls`, the scanner, the generated artifact, and the
  ABI/determinism lanes are untouched.
- The milestone is two slices: **⓪** `uri-parse-authority-form` (the LENIENT parse —
  the splice, the −2 re-map, the `not-authority-form` structural floor) with the
  re-map invariant and the lenient/strict-divergence witnessed, plus the
  hand-derived corpus + `PROVENANCE`; **①** `uri-parse-authority-form-validate` (the
  STRICT RFC 9112 form — `validate-authority` + `userinfo-forbidden` + `port-required`,
  leftmost-ordered) graded against the corpus, then the merge gate.
- With M9, a `CONNECT` server (`chez-http-server`) can parse an authority-form
  request-target directly and, with the `-validate` form, hold it to RFC 9112
  §3.2.3 — retiring the local `//`-splice workaround the issue records. The
  origin-form and absolute-form targets already parse in `relative-ref` / `uri` mode;
  asterisk-form (`*`) is a one-byte literal the caller checks, not a parse.
- `uri-parse` and `uri-parse-validate` are unchanged; the authority-form pair is a
  pure addition, so the existing lanes stay green and M9 adds its own.
