# 0028: the RFC 3986 conformance audit is recognizer-equivalence against an independent whole-URI oracle, earned only if clean

Date: 2026-09-19
Status: accepted
Plan: the conformance AUDIT decision 0027 deferred ("'RFC 3986 compliant' is a
whole-ABNF conformance audit not yet run — earnable, not granted"). Its oracle source
is RFC 3986 Appendix A, the collected ABNF at
`test/conformance/rfc3986/rfc3986.abnf` (itself derived from the vendored RFC text).
References:
[0003](0003-the-normative-reference-is-rfc-3986.md) (RFC 3986 is normative; a
disagreement is adjudicated against the ABNF, NOT a popular library),
[0005](0005-the-corpus-is-the-rfcs-own-vectors.md) / [0012](0012-the-corpus-instruments-abnfgen-and-mutation.md)
(oracle-from-the-RFC, independent of the code; agreement is the check; abnfgen + the
mutator are the deferred generators),
[0011](0011-v01-is-resolution-first.md) (uri-parse is the lenient splitter; validation
is the separate `uri-parse-validate` pass),
[0024](0024-charset-validation-is-the-cores-over-the-split-components.md) /
[0025](0025-the-host-grammar-is-the-cores-over-the-opaque-authority.md) (the M3 charset
and M4 host oracles this audit composes — both independent of the product and
mutation-witnessed),
[0026](0026-authority-form-is-a-shell-splice-parsed-lenient-validated-strict.md) (M9 —
NOT in scope: authority-form is RFC 9112, a separate grammar), and
[0027](0027-v02-releases-as-annotated-tag-still-on-never-run-ci-and-defers-the-compliance-claim.md)
(the release that deferred this claim; item 4 names the audit).

## Context

v0.2.0 is released (f359743, tag v0.2.0) with the "RFC 3986 compliant" claim
DEFERRED: the validating / normalizing / resolving surface is complete and measured,
but "compliant" is a whole-ABNF recognition claim that the feature milestones (M3
charset, M4 host) did not audit as a WHOLE. This milestone is that audit.

An armchair scan already shows the OBVIOUS gaps are closed — `1abc:x`, `+x:y`,
`ht!tp:x` are all rejected `invalid-scheme` (the `scheme = ALPHA *(…)` first-char rule
holds), and even `uri-reference "1abc:x"` (neither a valid `URI` — bad scheme — nor a
valid `relative-ref` — a colon in a `path-noscheme` first segment) is rejected. So M3
and M4 are more conformant than a naive read suggests, and this audit is NOT a
bug-hunt for the obvious: it is a rigorous recognizer-equivalence check that will
either EARN the claim or surface SUBTLE deviations in the interaction between the
lenient structural split and the component validators. The existing charset/host
oracles are COMPONENT-level; the untested conformance questions are STRUCTURAL
(path-type-per-context, the mode→production mapping, empty/edge shapes), so the audit's
new oracle must recognize a WHOLE URI.

## Decision

1. **"RFC 3986 compliant" means RECOGNIZER-EQUIVALENCE of `uri-parse-validate` to the
   ABNF, per mode.** `uri-parse-validate` accepts a bytevector in mode `uri` iff it is a
   `URI` per RFC 3986 Appendix A, `relative-ref` iff a `relative-ref`, `uri-reference`
   iff a `URI-reference`. That language-recognition claim is what "compliant" means for
   a validating parser. Normalization (§6.2.2) and resolution (§5.4) conformance are
   ALREADY separately measured (M5/M6 gates) and are not re-litigated. `uri-parse` (the
   lenient splitter) is deliberately non-validating and is OUT of scope (0011). RFC 9112
   authority-form (M9) is a different grammar and is out of scope.

2. **The oracle is a new INDEPENDENT whole-URI ABNF recognizer, `(uri test abnf-oracle)`,
   ABNF-derived (0003) and composing the existing component oracles.** It recognizes
   `URI` / `URI-reference` / `relative-ref` from Appendix A: the STRUCTURAL grammar —
   `scheme`, the `hier-part` / `relative-part` alternatives, the five path-types and
   their per-context constraints (`path-abempty` with authority, `path-absolute` not
   `//`, `path-noscheme` first-segment-no-colon, `path-rootless`, `path-empty`), and the
   mode→production mapping — composed with the EXISTING `(uri test charset-oracle)` and
   `(uri test host-oracle)` for the component charsets and the authority. It reuses those
   audited, product-independent oracles and adds only the structural layer. It is written
   INDEPENDENTLY of `uri-parse-validate`; their agreement is the check.

3. **The method is a broad DIFFERENTIAL: `uri-parse-validate` ⇄ the oracle over a wide
   input space.** (a) every existing POSITIVE corpus (§1.1.2, the §5.4 targets, the
   charset/host positives) — accepted by both; (b) every existing NEGATIVE corpus
   (charset, host) — rejected by both; (c) EXHAUSTIVE small sweeps — all strings up to a
   fixed length over a reduced alphabet carrying the structural delimiters
   (`: / ? # [ ] @ % .` + a digit, a letter, a sub-delim), in all three modes; (d)
   ADVERSARIAL boundary corpora, hand- and generator-built, per production; and (e) the
   abnfgen POSITIVE generator (0012, deferred until now) generating valid URIs the
   product must accept, if tractable — else a hand-grown structural generator. Every
   disagreement is a candidate deviation.

4. **Each disagreement is adjudicated against the ABNF (0003), resolved one of three
   ways.** (a) a PRODUCT bug (`uri-parse-validate` wrongly accepts or rejects) → FIXED in
   `src`, mutation-witnessed, when the fix is clean and localized; (b) an ORACLE bug (the
   oracle misreads the ABNF) → the oracle is fixed (it is test-side, so a shared-blindspot
   is guarded by the third artifact — the hand corpora — per 0005/0012); (c) a genuine
   DESIGN DEVIATION (a deliberate, defensible divergence, or a fix too large to land
   here) → SURFACED to the maintainer at a gate and DOCUMENTED, never silently kept. The
   arbiter is the collected ABNF; uriparser (M1's noted differential) may be a SECONDARY
   cross-check but is not the arbiter (0003).

5. **The claim is EARNED only if the audit is clean; residual deviations are documented
   and the claim stays deferred.** An audit that can only pass is not an audit. Outcomes:
   (a) CLEAN over the audited space → `uri-parse-validate` is recognizer-equivalent to the
   ABNF, and "RFC 3986 conformant (validation)" becomes CLAIMABLE — but its release-scoped
   README/CHANGELOG flip RIDES A SUBSEQUENT RELEASE (as the M4/M9 claims rode v0.2), not
   this milestone's merge; (b) DEVIATIONS → each fixed or documented, and the claim is
   earned only for the conformant surface with any residual stated. The milestone DELIVERS
   the audit oracle, the differential evidence, the confirmed fixes, and the recorded
   VERDICT — not an automatic claim.

6. **The milestone adds test artifacts and only fixes `src` for confirmed product bugs;
   it does not flip the release claim at its merge.** Deliverables: `(uri test abnf-oracle)`,
   the differential lane(s), any confirmed `src` fixes (witnessed), a decision recording
   the verdict, and the ledger close-out. The README/CHANGELOG "conformant" flip is a
   release act, gated as 0027/0023 gate release claims, not folded into this merge.

## Consequences

- The audit is the EVIDENCE behind — or against — the claim 0027 deferred. A clean audit
  makes "RFC 3986 conformant (validation)" earnable at the next release; deviations become
  `src` fixes or documented boundaries.
- The new `(uri test abnf-oracle)` is the whole-URI analog of the component oracles: a
  fourth, structural reading of the ABNF, independent of the product, its shared-blindspot
  with the product guarded by the hand corpora (0005/0012).
- `uri-parse` stays the lenient splitter (0011); this audit neither changes nor claims it.
- If the audit is clean, the abnfgen positive generator and the host-aware mutator (0012)
  may still be built as standing v0.3 tooling; the audit does not require them if the
  exhaustive + adversarial corpora give the coverage, and any bounded coverage is
  `log`-disclosed, never silently capped.
