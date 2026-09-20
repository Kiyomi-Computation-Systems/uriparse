# 0033: v0.4 releases as the annotated tag v0.4.0 on the reconciled commit, still on never-run CI, and adds the result-level validation entry point without touching the conformance claim

Date: 2026-09-20
Status: accepted
Plan: the v0.4 RELEASE is the release act for the arc since v0.3.0 — its checklist
DERIVED (as [decision 0031](0031-v03-releases-as-annotated-tag-and-states-the-earned-validation-conformance-claim.md)
derived it for v0.3, [0027](0027-v02-releases-as-annotated-tag-still-on-never-run-ci-and-defers-the-compliance-claim.md)
for v0.2, [0023](0023-v01-releases-as-annotated-tag-on-disclosed-local-evidence.md) for
v0.1), against the reconciled tree.
References:
[0017](0017-m1-ships-on-one-cell-and-it-is-not-the-linux-one.md) (CI has never run; each
release that ships on it needs its own recorded amendment),
[0023](0023-v01-releases-as-annotated-tag-on-disclosed-local-evidence.md) /
[0027](0027-v02-releases-as-annotated-tag-still-on-never-run-ci-and-defers-the-compliance-claim.md) /
[0031](0031-v03-releases-as-annotated-tag-and-states-the-earned-validation-conformance-claim.md)
(the v0.1/v0.2/v0.3 release templates this record is the v0.4 successor to — tag
semantics, structural doc reconciliation, the honest-claim discipline, the never-run-CI
amendment, the re-measure gate, publish steps gated per action),
[0030](0030-the-rfc-3986-conformance-audit-is-clean-recognition-equivalence-is-earned.md)
(the validation recognizer-equivalence claim v0.3 STATED and v0.4 carries UNCHANGED), and
[0032](0032-validation-composes-over-a-parse-result-so-a-reused-collector-can-be-validated.md)
(#18 — `uri-parse-result-validate`, the one new public export since v0.3, which rode the
release-deferral rule to THIS release).

## Context

The arc since v0.3.0 (tag on aae178e) is one merged change: issue #18
(`uri-parse-result-validate` on `(uri collect)`, ea02cf7 — the post-parse validation
judgement lifted from `uri-parse-validate` into a public seam, so a reused per-connection
collector's `uri-collect-finish!` result reaches the audited recognizer with no re-parse).
It is an additive export plus a behaviour-preserving one-line refactor of `uri-parse-validate`;
no algorithm, no new library, no new test lane (the new checks live in the already-registered
`unit.collect`). The maintainer ran the full registered suite and confirmed 77/77 green before
authorising the merge; the release selection is UNCHANGED at 77 (no new lane). All 32 prior
decisions are `accepted`; `CMakeLists.txt` declares `VERSION 0.3.0`; the tags are `v0.1.0`,
`v0.2.0`, `v0.3.0`.

So — exactly as v0.2 and v0.3 — the only work is the release ACT, and its two non-mechanical
questions are (a) the evidence basis and (b) the claim. The Linux CI cell has STILL never run
(the billed minutes remain exhausted; the #18 PR's `linux-amd64` check was the decision-0017
billing refusal, 0 steps). And unlike v0.3 — which had a NEW claim to state (the audit verdict)
— v0.4 states NO new claim: the export is the same audited recognizer reached from a parse
result, so the release adds a capability, not a conformance grant.

## Decision

1. **The v0.4 release ships one already-merged export (`uri-parse-result-validate`); the
   release act itself adds no algorithm, no new `src/` library, and no new test lane.** Its
   deliverables are the documentation reconciliation, this record, the ledger close-out, and
   the tag. #18 is already measured green on main; adding anything executable in the release
   commit would change the re-measured count and break this charter (0023 item 1).

2. **The release is one annotated tag `v0.4.0`** — three-part SemVer, `v` prefix (0023 item 2)
   — placed on the squash-merged reconciliation commit on `main`. The bump is a MINOR one
   (0.3.0 → 0.4.0): `uri-parse-result-validate` is a new, backward-compatible public export and
   no existing behaviour changed (`uri-parse-validate` was refactored over it, outcome-identical
   for every input) — the SAME reasoning that made `uri-collector-reset!` a minor bump for v0.3
   (0031 item 2). `CMakeLists.txt` `VERSION` bumps `0.3.0` → `0.4.0`; the `(uri …)` libraries
   stay unversioned (an R6RS version field is a breaking import change, out of scope). Signing
   is the maintainer's discretion, not a gate.

3. **Doc reconciliation adds the export and keeps every claim and boundary verbatim.**
   `README.org`'s status flips to v0.4.0; its summary gains one sentence for
   `uri-parse-result-validate` alongside `uri-collector-reset!` (the per-connection-reuse
   story). The RFC 3986 conformance sentence, the "not a blanket compliant" caveat, the
   CI-not-run quote, the strict-resolution clause, the round-trip §4.2/§3.3 boundary, the
   not-portable clause, and the normalize-no-dot-segments clause stay VERBATIM — none is
   touched by #18. In `CHANGELOG.md`, `## [Unreleased]` becomes `## [0.4.0] - 2026-09-20` with a
   fresh empty `## [Unreleased]` above it, a single feature section in the measured
   mutation-witness voice of the prior entries (NOT a strict Added/Changed rewrite — 0023 item
   3), and the version link refs updated. The frozen `[0.3.0]`, `[0.2.0]`, `[0.1.0]` entries are
   untouched.

4. **The honest claim: v0.4 states NO NEW conformance claim; it carries v0.3's UNCHANGED.**
   `uri-parse-result-validate` is the post-parse half of `uri-parse-validate` lifted to a public
   name — it applies the SAME audited component/host judgement (0024/0025, audited
   recognizer-equivalent to RFC 3986 Appendix A per mode at 0030). So it inherits that exact
   claim with its exact boundary — recognition (accept/reject) equivalence, not
   error-code/offset; the exhaustive part bounded (length 5, a 12-byte alphabet); `uri-parse`
   itself still lenient by design — and adds nothing to it. The release states the export as a
   new CAPABILITY (validate an already-parsed / reused-collector result without a re-parse),
   NOT as any broadening of conformance. The blanket "RFC 3986 compliant" is still not claimed;
   normalization (§6.2.2) and resolution (§5.4) conformance remain separately measured (M5/M6).

5. **This record ratifies releasing v0.4 on STILL-never-run CI, disclosed not waived.** As with
   v0.1 (0023), v0.2 (0027) and v0.3 (0031), the Linux cell still has not run; the release BODY
   carries the CI-never-ran fact and the macOS-arm64-local basis. The #18 PR's `linux-amd64`
   check was re-confirmed as the decision-0017 billing refusal (0 steps, ~3s, "recent account
   payments have failed" annotation), not a test result. 0017 item 3 and its two never-executed
   predictions remain OPEN and disclosed; the first funded CI run discharges them. The maintainer
   ratified shipping-with-disclosure ("lets make a release").

6. **The release-verification gate is a fresh re-measure at the tagged commit.** The counts in
   the tag message and the CHANGELOG `[0.4.0]` body come from re-running, AT the post-edit
   release commit, `ctest --preset release` and `ctest --preset no-scheme`, each
   `--no-tests=error`, date- and platform-stamped, never carried forward by arithmetic (0023
   item 6). Because the release commit changes only docs (no `src/`, no lane), the expected
   counts are unchanged from #18's merge — 77/77 and 11/11 — but they are RE-RUN at the tagged
   commit, not asserted from this paragraph. This session's mode blocks the build, so the
   maintainer runs the re-measure, as they ran the 77/77 that gated the #18 merge.

7. **The publish steps run under the "lets make a release" ratification; a GitHub Release stays
   optional and separately gated.** 0023 item 7 holds the reconciliation PR, its merge, the tag,
   and the tag push to be outward-facing publish actions requiring explicit maintainer approval;
   "lets make a release" is that approval, and they run in the closing ritual over SSH (fixed
   this session — the `gh auth git-credential` HTTPS workaround is retired unless SSH breaks
   again). A GitHub Release is NOT cut automatically; if the maintainer later wants one, its body
   is the CHANGELOG `[0.4.0]` section verbatim, including the CI disclosure.

## Consequences

- The v0.4 release adds no lane and no algorithm in its own commit; `src/` is byte-identical to
  ea02cf7's. The milestone is documentation, a decision, a re-measure, and a tag.
- v0.4 is the first release since the conformance claim was stated (v0.3) and it does NOT move
  the claim: it ships a new way to REACH the audited recognizer (from a parse result / a reused
  collector), which is a capability for embedders (chez-http-server), not a conformance change.
  The scoped claim and every boundary read identically to v0.3.
- What reopens next is a separate choice, not a v0.4 gap: the first funded CI run (0017 item 3),
  the deferred abnfgen positive generator / host-aware mutator (0012), a relative-reference
  serializer above recompose (0022), the OPTIONAL result/collector-level authority-form
  validator deferred by 0032 item 4, or the next sibling request.
