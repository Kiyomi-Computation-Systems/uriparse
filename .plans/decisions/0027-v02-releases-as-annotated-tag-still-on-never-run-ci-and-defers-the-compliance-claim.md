# 0027: v0.2 releases as the annotated tag v0.2.0 on the reconciled commit, still on never-run CI, and does not yet claim RFC 3986 compliance

Date: 2026-09-19
Status: accepted
Plan: the v0.2 RELEASE is the M8 analog for v0.2 — a release act, its checklist
DERIVED (as [decision 0023](0023-v01-releases-as-annotated-tag-on-disclosed-local-evidence.md)
derived M8's), against the reconciled tree.
References:
[0003](0003-the-normative-reference-is-rfc-3986.md) (RFC 3986 is normative;
disagreement is adjudicated against the ABNF),
[0011](0011-v01-is-resolution-first.md) (v0.1 was resolution-first / non-validating;
M3 charset + M4 host grammar are v0.2 — now shipped),
[0017](0017-m1-ships-on-one-cell-and-it-is-not-the-linux-one.md) (CI has never run;
each release that ships on it needs its own recorded amendment),
[0023](0023-v01-releases-as-annotated-tag-on-disclosed-local-evidence.md) (the v0.1
release template this record is the v0.2 successor to — tag semantics, structural doc
reconciliation, the honest-claim discipline, the never-run-CI amendment, the
re-measure gate, and publish steps gated per action),
[0024](0024-charset-validation-is-the-cores-over-the-split-components.md) (M3 —
`uri-parse-validate` judges the component charsets),
[0025](0025-the-host-grammar-is-the-cores-over-the-opaque-authority.md) (M4 — the host
grammar + host-case normalization; its item 8 deferred the README/CHANGELOG claim-drop
to THIS release), and
[0026](0026-authority-form-is-a-shell-splice-parsed-lenient-validated-strict.md) (M9 —
authority-form; its item 7 deferred its CHANGELOG entry to THIS release).

## Context

v0.2's implementation arc is complete and merged to main: M3 (`(uri charset)` — the
coarse-component charset validators, `uri-parse-validate`, 3686dc6), M4 (`(uri host)` —
the whole authority host grammar plus host-case normalization, 04bf52a), and M9
(`(uri collect)`'s authority-form pair for RFC 9112 §3.2.3 CONNECT targets, a58e606).
`src/` is otherwise unchanged from v0.1's M7 tree. The code gate is green on main,
re-measured on this tree (not carried forward): release 73/73, no-scheme 11/11, 0
failures (Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3), exercising both the
source and ahead-of-time lanes and every audit and mutation suite. All 26 prior
decisions are `accepted`; `CMakeLists.txt` still declares `VERSION 0.1.0`; the only tag
is `v0.1.0`.

So — exactly as M8 — the only work is the release ACT, and its two non-mechanical
questions are (a) the evidence basis and (b) the claim. The Linux CI cell has STILL
never run (the billed minutes remain exhausted); a v0.2 tag is a strictly larger claim
than the frozen v0.1.0, and [decision 0023](0023-v01-releases-as-annotated-tag-on-disclosed-local-evidence.md)
was explicitly v0.1-scoped ("a v0.2 that runs the Linux cell replaces this disclosure
with evidence"). So v0.2 needs its OWN recorded amendment, the successor to 0023 as
0023 was to 0017. And the "RFC 3986 compliant" claim, which the feature milestones left
EARNABLE-pending-audit, must be settled for a public tag.

## Decision

1. **The v0.2 release ships no algorithm, no new `src/` library, and no new test lane.**
   Its deliverables are the documentation reconciliation, this record, the ledger
   close-out, and the tag. M3/M4/M9 are already measured green; adding anything
   executable would change the re-measured count and break this charter (0023 item 1).

2. **The release is one annotated tag `v0.2.0`** — three-part SemVer, `v` prefix, the
   byte-machine convention (0023 item 2) — placed on the squash-merged reconciliation
   commit on `main`, NOT on `1147724` (which still carries the v0.1.0-stamped README and
   the empty `[Unreleased]`). `CMakeLists.txt` `VERSION` bumps `0.1.0` → `0.2.0`; the
   `(uri …)` libraries stay unversioned (an R6RS version field is a breaking import
   change, out of scope). Signing (`-s`) is the maintainer's key discretion, not a gate.

3. **Doc reconciliation drops the EARNED caveats and keeps the STILL-TRUE ones verbatim.**
   `README.org`'s status flips to v0.2.0 and its summary gains M3/M4/M9. Of the v0.1
   "will not claim" caveats: the "charset and host-grammar validation are v0.2" clause
   and the "not host case" normalizer clause are now EARNED (M3/M4) and are rewritten to
   state what v0.2 DOES; the CI-not-run quote, the strict-resolution clause, the
   round-trip §4.2/§3.3 boundary, the not-portable clause, and the not-blanket-RFC-3986-
   compliant clause (item 4) stay as honest boundaries. In `CHANGELOG.md`,
   `## [Unreleased]` becomes `## [0.2.0] - 2026-09-19` with a fresh empty `## [Unreleased]`
   above it, M3/M4/M9 sections in the measured, mutation-witness voice of the `[0.1.0]`
   entry (NOT a strict Added/Changed rewrite — 0023 item 3), and the version link refs
   updated. The frozen `[0.1.0]` entry is untouched.

4. **The honest claim: v0.2 now VALIDATES and fully NORMALIZES and parses authority-form,
   but still does NOT claim blanket "RFC 3986 compliant".** Over v0.1's splitter +
   strict §5.2.2 resolver + complete core, v0.2 adds: `uri-parse-validate` judging every
   component's charset (M3) AND the whole authority host grammar — userinfo / host as
   reg-name / IPv4address / IP-literal → IPv6address / IPvFuture / port (M4); the last
   §6.2.2.1 transform, host-case normalization (M4), so `normalize-components` now folds
   scheme + host case + percent; and `uri-parse-authority-form` / `-validate` for RFC
   9112 §3.2.3 CONNECT targets (M9). `uri-parse` ITSELF stays lenient by design (the
   M5/M6/M7 splitter). It must STILL NOT claim "RFC 3986 compliant" as a blanket
   property: the validating / normalizing / resolving / authority-form SURFACE is
   complete and measured, but "compliant" is a whole-ABNF conformance claim that needs
   its OWN audit (a systematic accept/reject sweep against the collected ABNF), not an
   automatic grant from three feature milestones. The claim is EARNABLE and NEARER, and
   the release says exactly that rather than either over-claiming or hiding the progress.

5. **This record ratifies releasing v0.2 on STILL-never-run CI, disclosed not waived.**
   0023 released v0.1 on macOS-arm64-local evidence with the CI-never-ran fact in the
   release BODY; v0.2 does the same, because the Linux cell still has not run. 0017 item
   3 and its two never-executed predictions remain OPEN and disclosed; the first funded
   CI run discharges them and replaces this disclosure with evidence. The maintainer
   ratified shipping-with-disclosure ("Do it"), the v0.2 analog of the M8 merge-gate
   ratification.

6. **The release-verification gate is a fresh re-measure at the tagged commit.** The
   counts in the tag message and the CHANGELOG `[0.2.0]` body come from re-running, AT
   the post-edit release commit, `ctest --preset release` and `ctest --preset no-scheme`,
   each `--no-tests=error`, date- and platform-stamped, never carried forward by
   arithmetic (0023 item 6, global-constraints).

7. **The publish steps run under the "Do it" ratification; a GitHub Release stays
   optional and separately gated.** 0023 item 7 holds the reconciliation PR, its merge,
   the tag, and the tag push to be outward-facing publish actions requiring explicit
   maintainer approval; "Do it" is that approval for this release (as the M8 merge-gate
   ratification was for v0.1), and they run in the closing ritual over HTTPS (the SSH
   agent is broken this session). A GitHub Release is NOT cut automatically — the gitlink
   pin needs only the pushed tag; if the maintainer later wants one, its body is the
   CHANGELOG `[0.2.0]` section verbatim, including the CI disclosure.

## Consequences

- The v0.2 release adds no `src/` and no lane; the shipped `src/` is byte-identical to
  M9's. The milestone is documentation, a decision, a re-measure, and a tag.
- v0.2 ships with 0017 item 3 OPEN and disclosed, and with "RFC 3986 compliant" still
  UNCLAIMED pending its own audit. A consumer needing cross-platform assurance waits for
  the first funded CI run; a consumer needing a conformance guarantee waits for the audit
  — both stated in the release body, not a surprise.
- This is the last milestone of the v0.2 arc. What reopens next is a separate choice: the
  RFC 3986 conformance AUDIT (which could earn the compliance claim), the first funded CI
  run (0017 item 3), or v0.3 features — each its own decision, not a v0.2 gap.
