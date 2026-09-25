# 0037: v0.6 releases as the annotated tag v0.6.0 on the reconciled commit, still on never-run CI, and adds ranged authority validation without touching the conformance claim

Date: 2026-09-25
Status: accepted
Plan: the v0.6 RELEASE is the release act for the arc since v0.5.0. Its checklist is
derived from [0035](0035-v05-releases-as-annotated-tag-and-adds-ranged-component-validation.md)
(v0.5), the fifth application of the template begun at 0023, and checked against the
reconciled tree.
References:
[0017](0017-m1-ships-on-one-cell-and-it-is-not-the-linux-one.md) (CI has never run; each
release that ships on it needs its own recorded amendment),
[0023](0023-v01-releases-as-annotated-tag-on-disclosed-local-evidence.md) /
[0035](0035-v05-releases-as-annotated-tag-and-adds-ranged-component-validation.md) (the
release template),
[0030](0030-the-rfc-3986-conformance-audit-is-clean-recognition-equivalence-is-earned.md)
(the validation recognizer-equivalence claim v0.3 stated and v0.4 to v0.6 carry unchanged),
and [0036](0036-the-authority-judges-take-a-range-with-relative-results.md) (#24, the ranged
`validate-authority` / `authority-host-span`, the one public change since v0.5).

## Context

The arc since v0.5.0 (tag on 4d95118) is one merged change: issue #24, 7d19f9b.
`(uri host)`'s `validate-authority` and `authority-host-span` gained an optional `start`
and `end`, with every returned number relative to `start`. The merge-gate review's cleanups
rode the same PR:
- a new internal `(uri range)` holds the one range check, shared with `validate-component`;
- one `authority-split` serves both procedures;
- a harness library `(uri test ranged)` holds the shared check techniques.

The one-argument calls are unchanged for every input. There is no new public export, no
new lane, and the release selection is unchanged at 77. The #24 merge was gated on release
77/77 and no-scheme 11/11, measured locally on exactly the merged tree. All 36 prior
decisions are `accepted`; `CMakeLists.txt` declares `VERSION 0.5.0`; the tags are `v0.1.0`
through `v0.5.0`.

As before, the only work is the release ACT, with two non-mechanical questions: (a) the
evidence basis, and (b) the claim. The Linux CI cell has STILL never run: the #24 PR's
`linux-amd64` check was the decision-0017 billing refusal (0 steps, no runner, ~3s). Like
v0.4 and v0.5, v0.6 has no new conformance claim to state.

## Decision

1. **The v0.6 release ships one already-merged change (the ranged authority procedures).**
   The release act itself adds no algorithm, no new `src/` library and no new test lane. Its
   deliverables are the documentation reconciliation, this record, the ledger close-out and
   the tag (0023 item 1).

2. **The release is one annotated tag `v0.6.0`, and the bump is MINOR (0.5.0 → 0.6.0).** The
   tag goes on the squash-merged reconciliation commit on `main`. Optional arguments on
   existing exports are a backward-compatible addition, as for v0.5. The version is the
   next minor, with no gap: the maintainer asked for "0.7" and, asked once, chose 0.6.0.
   `CMakeLists.txt` `VERSION` bumps `0.5.0` → `0.6.0`. The `(uri …)` libraries stay
   unversioned. Signing follows `tag.gpgSign`, the maintainer's configuration, not a gate.

3. **Doc reconciliation adds the capability and keeps every claim and boundary verbatim.**
   - `README.org`: the status flips to v0.6.0. The summary gains one clause (judge a `Host`
     value in place, #24). The API paragraph names `validate-authority`,
     `authority-host-span` and their optional range, with results relative to `start`.
   - Kept VERBATIM: every frozen claim and caveat, as listed in 0035 item 3.
   - `CHANGELOG.md`: `[Unreleased]` becomes `[0.6.0] - 2026-09-25`, with a fresh
     `[Unreleased]`, one feature section in the measured mutation-witness voice, and
     updated version links. The frozen `[0.5.0]` to `[0.1.0]` entries are untouched.
   - `(uri range)` is internal and is not advertised; the design doc's library table
     already lists it (0036 item 7).

4. **The honest claim: v0.6 states NO NEW conformance claim and carries v0.3's unchanged.** The
   ranged form is the same M4 host-grammar judge `uri-parse-validate` applies (audited at
   0030), reached over a span. It judges an RFC 3986 AUTHORITY, not RFC 9110's `Host`, which
   forbids userinfo. The CHANGELOG says so and names the server's part: refusing userinfo
   (the host start is not 0 exactly when there is an `@`), and whether an empty `Host` is
   acceptable. The release states a new CAPABILITY, NOT a broadening of conformance.

5. **v0.6 releases on STILL-never-run CI, disclosed not waived** (as 0023 to 0035). The
   CHANGELOG `[0.6.0]` preamble and the tag message carry the CI-never-ran fact and the
   macOS-arm64-local basis. 0017 item 3 remains OPEN.

6. **The release-verification gate is a fresh re-measure at the release commit** (0023 item
   6, as run in 0035 item 6). `ctest --preset release` and `ctest --preset no-scheme` (each
   `--no-tests=error`) are re-run on the reconciled tree before its commit. The squash merge
   is pinned to that head with `--match-head-commit`, and the merged tree hash is compared
   with the tested one before tagging.

7. **The publish steps run in the closing ritual, which is asked for before it runs
   (AGENTS.md).** Those steps are the reconciliation PR's squash merge, the annotated tag
   and its push. A GitHub Release is NOT cut automatically. If the maintainer wants one,
   its body is the CHANGELOG `[0.6.0]` section verbatim.

## Consequences

- The release commit adds no lane and no algorithm; `src/` is byte-identical to 7d19f9b's.
- chez-http-server can consume v0.6.0 by tag and land its RFC 9112 §3.2 invalid-`Host`-value
  rule, copying nothing.
- What reopens next is a separate choice, not a v0.6 gap:
  - the first funded CI run (0017 item 3);
  - the result-level authority-form validator (0032 item 4);
  - tooling (0012, 0022);
  - the next sibling request.
