# 0030: the RFC 3986 conformance audit is clean — recognition-equivalence is earned (the claim-flip rides the next release)

Date: 2026-09-19
Status: accepted
Plan: the recorded VERDICT decision 0028 item 5/6 requires ("the milestone delivers …
the recorded VERDICT"). References:
[0028](0028-the-rfc-3986-conformance-audit-is-recognizer-equivalence-against-an-independent-whole-uri-oracle.md)
(the audit charter this discharges — its item 1 defines the claim, item 3 the method,
item 5 the earn-only-if-clean rule, item 6 the deliverables and the no-flip-at-merge
rule),
[0027](0027-v02-releases-as-annotated-tag-still-on-never-run-ci-and-defers-the-compliance-claim.md)
(the release that DEFERRED "RFC 3986 compliant" — item 4 named this audit as what
would earn it),
[0003](0003-the-normative-reference-is-rfc-3986.md) (the arbiter is the collected ABNF),
[0005](0005-the-corpus-is-the-rfcs-own-vectors.md) /
[0012](0012-the-corpus-instruments-abnfgen-and-mutation.md) (oracle-from-the-RFC; the
third reading guards the shared blind spot),
[0024](0024-charset-validation-is-the-cores-over-the-split-components.md) /
[0025](0025-the-host-grammar-is-the-cores-over-the-opaque-authority.md) (the component
oracles the audit composed).

## Context

Decision 0028 set the audit up as recognizer-equivalence of `uri-parse-validate` to
RFC 3986 Appendix A, per mode, earned only if clean, with the claim-flip riding a
subsequent release rather than the milestone merge. Slices ⓪ and ① ran it. This
decision records what they found.

## Decision

1. **The verdict is CLEAN.** Over the whole audited space, `uri-parse-validate`'s
   accept/reject verdict AGREES with the independent whole-URI oracle
   `(uri test abnf-oracle)` on every input in every mode, and both agree with a hand
   ABNF reading on every adversarial vector. ZERO deviations were found. The audited
   space: (a) the §1.1.2 and §5.4 POSITIVE corpora (both accept); (b) the M3 charset and
   M4 host NEGATIVE corpora (both reject); (c) an EXHAUSTIVE sweep of every string of
   length 0..5 over the 12-byte alphabet `{a 1 ; . : / ? # [ ] @ %}` in all three modes
   — 814,359 input×mode pairs, and the count is ASSERTED equal to the independently
   computed total, so a silent cap reddens; (d) 213 ABNF-verified adversarial rows (60
   hand-authored, 153 from an 8-production adversarial-probe Workflow whose every verdict
   was independently re-derived from Appendix A). The audit had teeth — any swept word or
   any hostile vector could have exposed a product bug — and found none.

2. **"RFC 3986 conformant (validation)" is EARNED, meaning RECOGNITION-equivalence.**
   Per 0028 item 1 the claim is precisely: `uri-parse-validate` accepts a bytevector in
   mode `uri` iff it is a `URI` per Appendix A, `relative-ref` iff a `relative-ref`,
   `uri-reference` iff a `URI-reference`. Over the audited space this holds. The claim is
   therefore claimable — as "RFC 3986 conformant (validation)", never a bare "RFC 3986
   compliant", and scoped to recognition (below).

3. **The claim-flip RIDES THE NEXT RELEASE; it is not in this milestone (0028 item 6).**
   Like the M4 host and M9 authority-form claims that rode v0.2, the README/CHANGELOG
   "conformant (validation)" statement is a RELEASE act, gated as 0027/0023 gate release
   claims. This milestone merges the audit oracle, the differential lane, the adversarial
   corpus, and this verdict — and touches no release-scoped doc.

4. **The boundaries are stated, not buried.** (a) This is RECOGNITION equivalence
   (accept/reject), NOT error-code/offset equivalence — those are separately gated by M3
   (unit.charset) and M4 (unit.host) and are out of this audit's scope (0028 item 1). (b)
   The EXHAUSTIVE part is bounded at length 5 over a 12-byte alphabet; longer and more
   structured inputs are covered by the TARGETED 213-row adversarial corpus, not
   exhaustively — a real bound, disclosed on the lane's `uri-harness: coverage …` line and
   asserted, never silently capped. (c) Normalization (§6.2.2) and resolution (§5.4)
   conformance are separately measured (M5/M6) and not re-litigated. (d) `uri-parse` (the
   lenient splitter) is deliberately non-validating and was never in scope (0011).

5. **The differential is falsifiable and self-verifying — proven, not asserted.** The
   sweep's disagreement detector and the corpus's third-reading detector are both
   mutation-witnessed (an injected oracle bug reddens the sweep; a flipped corpus verdict
   reddens both the oracle-vs-ABNF and product-vs-ABNF checks). After the merge-gate
   review, the coverage bound is DISCLOSED unconditionally and the comparison count is
   ASSERTED against an independent total (a silent cap reddens — witnessed), closing the
   one integrity hole the review found. The audit rests on what the lane verifies and
   emits, not on reading a source constant.

## Consequences

- The claim 0027 deferred is now EARNED for the validation surface; the next release may
  state "RFC 3986 conformant (validation)" with this decision as its evidence, keeping the
  recognition/normalization/resolution distinction and the audited-space boundary.
- No product source changed in the audit: it is purely additive test artifacts and records
  (`(uri test abnf-oracle)`, the differential lane and corpus, decisions 0028 and 0030).
  `uri-parse-validate` was found conformant AS SHIPPED in v0.2.0.
- The deferred abnfgen positive generator and the host-aware mutator (0012) remain optional
  v0.3 tooling; the exhaustive+adversarial coverage did not require them, and any future
  bound stays disclosed and asserted, never silently capped.
