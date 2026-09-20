# 0031: v0.3 releases as the annotated tag v0.3.0 on the reconciled commit, still on never-run CI, and now STATES the earned validation-conformance claim

Date: 2026-09-20
Status: accepted
Plan: the v0.3 RELEASE is the release act for the arc since v0.2.0 — its checklist
DERIVED (as [decision 0027](0027-v02-releases-as-annotated-tag-still-on-never-run-ci-and-defers-the-compliance-claim.md)
derived it for v0.2), against the reconciled tree.
References:
[0017](0017-m1-ships-on-one-cell-and-it-is-not-the-linux-one.md) (CI has never run; each
release that ships on it needs its own recorded amendment),
[0023](0023-v01-releases-as-annotated-tag-on-disclosed-local-evidence.md) /
[0027](0027-v02-releases-as-annotated-tag-still-on-never-run-ci-and-defers-the-compliance-claim.md)
(the v0.1 and v0.2 release templates this record is the v0.3 successor to — tag
semantics, structural doc reconciliation, the honest-claim discipline, the never-run-CI
amendment, the re-measure gate, publish steps gated per action),
[0029](0029-a-collector-resets-in-place-for-per-connection-reuse.md) (#11 —
`uri-collector-reset!`, the one new public export since v0.2), and
[0030](0030-the-rfc-3986-conformance-audit-is-clean-recognition-equivalence-is-earned.md)
(the conformance audit VERDICT this release states: recognition-equivalence earned, and
0028 item 6 rode the claim-flip to THIS release).

## Context

The arc since v0.2.0 (tag on f359743) is complete and merged to main: issue #11
(`uri-collector-reset!` on `(uri collect)` for per-connection reuse, a1b9176 — the one
`src/` change, an additive export) and the RFC 3986 conformance AUDIT (the independent
whole-URI oracle, the differential lane, and the recorded CLEAN verdict, 66929c2 — test
artifacts and records only, no `src/` change). The maintainer ran the full registered
suite (`make test-all`) and confirmed 77/77 green before authorising the audit merge; the
release selection grew 73 → 77 (the two new audit lanes, source and aot). All 30 prior
decisions are `accepted`; `CMakeLists.txt` still declares `VERSION 0.2.0`; the tags are
`v0.1.0`, `v0.2.0`.

So — exactly as v0.2 — the only work is the release ACT, and its two non-mechanical
questions are (a) the evidence basis and (b) the claim. The Linux CI cell has STILL never
run (the billed minutes remain exhausted). And decision 0027 explicitly DEFERRED the "RFC
3986 compliant" claim to "its own audit"; that audit has now run and is clean (0030), so
this release is where the claim is finally stated — precisely, with its boundary, not as
a blanket grant.

## Decision

1. **The v0.3 release ships one already-merged feature (`uri-collector-reset!`) and the
   already-merged audit; the release act itself adds no algorithm, no new `src/` library,
   and no new test lane.** Its deliverables are the documentation reconciliation, this
   record, the ledger close-out, and the tag. #11 and the audit are already measured
   green on main; adding anything executable in the release commit would change the
   re-measured count and break this charter (0023 item 1).

2. **The release is one annotated tag `v0.3.0`** — three-part SemVer, `v` prefix (0023
   item 2) — placed on the squash-merged reconciliation commit on `main`. The bump is a
   MINOR one (0.2.0 → 0.3.0): `uri-collector-reset!` is a new, backward-compatible public
   export, and no existing behaviour changed. `CMakeLists.txt` `VERSION` bumps `0.2.0` →
   `0.3.0`; the `(uri …)` libraries stay unversioned (an R6RS version field is a breaking
   import change, out of scope). Signing is the maintainer's discretion, not a gate.

3. **Doc reconciliation STATES the earned claim and keeps the still-true boundaries.**
   `README.org`'s status flips to v0.3.0; its summary gains `uri-collector-reset!` and the
   audit. The v0.2 "not yet RFC 3986 compliant" caveat is now EARNED for the validation
   surface (0030) and is REWRITTEN from a deferral into a precise positive claim WITH its
   boundary (item 4); the CI-not-run quote, the strict-resolution clause, the round-trip
   §4.2/§3.3 boundary, the not-portable clause, and the normalize-no-dot-segments clause
   stay verbatim as honest boundaries. In `CHANGELOG.md`, `## [Unreleased]` becomes
   `## [0.3.0] - 2026-09-20` with a fresh empty `## [Unreleased]` above it, an audit
   section and an `uri-collector-reset!` section in the measured, mutation-witness voice of
   the prior entries (NOT a strict Added/Changed rewrite — 0023 item 3), and the version
   link refs updated. The frozen `[0.2.0]` and `[0.1.0]` entries are untouched.

4. **The honest claim: v0.3 STATES "RFC 3986 conformant (validation)", scoped to
   recognition, and still does NOT claim a blanket whole-library "RFC 3986 compliant".**
   The audit (0030) established that `uri-parse-validate` is RECOGNIZER-EQUIVALENT to RFC
   3986 Appendix A per mode — it accepts a bytevector iff the bytes are that production —
   over an exhaustive length-0..5 sweep (asserted complete), the normative positive
   corpora, the M3/M4 negative corpora, and 213 ABNF-verified adversarial vectors, with
   ZERO deviations. The release states exactly that. It keeps three boundaries in view, so
   the claim is precise rather than blanket: (a) it is RECOGNITION (accept/reject)
   equivalence, not an error-code/offset-equivalence claim (those are separately gated by
   M3/M4); (b) the exhaustive part is bounded (length 5, a 12-byte alphabet), with deeper
   structures covered by the targeted adversarial corpus, not exhaustively; and (c)
   `uri-parse` ITSELF stays lenient by design and accepts bytes the ABNF rejects — the
   conformance is the `uri-parse-validate` recognizer, which is the entry point that makes
   the claim. Normalization (§6.2.2) and resolution (§5.4) conformance remain separately
   measured (M5/M6), not folded into this claim.

5. **This record ratifies releasing v0.3 on STILL-never-run CI, disclosed not waived.**
   As with v0.1 (0023) and v0.2 (0027), the Linux cell still has not run; the release BODY
   carries the CI-never-ran fact and the macOS-arm64-local basis. 0017 item 3 and its two
   never-executed predictions remain OPEN and disclosed; the first funded CI run discharges
   them. The maintainer ratified shipping-with-disclosure ("lets cut a release").

6. **The release-verification gate is a fresh re-measure at the tagged commit.** The counts
   in the tag message and the CHANGELOG `[0.3.0]` body come from re-running, AT the
   post-edit release commit, `ctest --preset release` and `ctest --preset no-scheme`, each
   `--no-tests=error`, date- and platform-stamped, never carried forward by arithmetic
   (0023 item 6). Because the release commit changes only docs (no `src/`, no lane), the
   expected counts are unchanged from the audit merge — 77/77 and 11/11 — but they are
   RE-RUN at the tagged commit, not asserted from this paragraph. This session's mode
   blocks the build, so the maintainer runs the re-measure, as they ran the 77/77 that
   gated the audit merge.

7. **The publish steps run under the "lets cut a release" ratification; a GitHub Release
   stays optional and separately gated.** 0023 item 7 holds the reconciliation PR, its
   merge, the tag, and the tag push to be outward-facing publish actions requiring explicit
   maintainer approval; "lets cut a release" is that approval, and they run in the closing
   ritual over HTTPS (the SSH agent is broken this session). A GitHub Release is NOT cut
   automatically; if the maintainer later wants one, its body is the CHANGELOG `[0.3.0]`
   section verbatim, including the CI disclosure.

## Consequences

- The v0.3 release adds no lane and no algorithm in its own commit; `src/` is byte-identical
  to 66929c2's (which is byte-identical to a1b9176's for `(uri collect)` plus the audit's
  test-only additions). The milestone is documentation, a decision, a re-measure, and a tag.
- v0.3 is the first release to STATE an RFC 3986 conformance claim — scoped to validation
  recognition (0030) — and it ships with 0017 item 3 still OPEN and disclosed. A consumer
  needing cross-platform assurance still waits for the first funded CI run; a consumer
  needing the conformance guarantee now has it for `uri-parse-validate`, with its boundary
  stated.
- What reopens next is a separate choice, not a v0.3 gap: the first funded CI run (0017 item
  3), the deferred abnfgen positive generator / host-aware mutator (0012), a relative-
  reference serializer above recompose (0022), or the next sibling request.
