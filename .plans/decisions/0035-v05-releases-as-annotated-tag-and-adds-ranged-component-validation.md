# 0035: v0.5 releases as the annotated tag v0.5.0 on the reconciled commit, still on never-run CI, and adds ranged component validation without touching the conformance claim

Date: 2026-09-25
Status: accepted
Plan: the v0.5 RELEASE is the release act for the arc since v0.4.0. Its checklist is
derived from [0033](0033-v04-releases-as-annotated-tag-and-adds-the-result-level-validation-entry-point.md)
(v0.4), itself derived from 0031 (v0.3), 0027 (v0.2) and 0023 (v0.1), and checked
against the reconciled tree.
References:
[0017](0017-m1-ships-on-one-cell-and-it-is-not-the-linux-one.md) (CI has never run; each
release that ships on it needs its own recorded amendment),
[0023](0023-v01-releases-as-annotated-tag-on-disclosed-local-evidence.md) /
[0033](0033-v04-releases-as-annotated-tag-and-adds-the-result-level-validation-entry-point.md)
(the release template: tag semantics, structural doc reconciliation, the honest-claim
discipline, the never-run-CI amendment, the re-measure gate, publish steps gated per action),
[0030](0030-the-rfc-3986-conformance-audit-is-clean-recognition-equivalence-is-earned.md)
(the validation recognizer-equivalence claim v0.3 stated and v0.4 and v0.5 carry unchanged),
and [0034](0034-validate-component-judges-a-range-so-a-span-is-validated-in-place.md)
(#21, the ranged `validate-component`, the one public change since v0.4, which rode the
release-deferral rule to THIS release).

## Context

The arc since v0.4.0 (tag on 611b04b) is one merged change: issue #21, bb8392a.
`(uri charset)`'s `validate-component` gained an optional `start` and `end`, so an embedder
judges a span of a larger bytevector in place. The two-argument call is unchanged for every
input, misuse diagnostics included. The change adds no algorithm, no new library and no new
test lane: its checks live in the already-registered `unit.charset`, and the release
selection is unchanged at 77. The #21 merge was gated on release 77/77 and no-scheme 11/11,
measured locally on exactly the merged tree. All 34 prior decisions are `accepted`;
`CMakeLists.txt` declares `VERSION 0.4.0`; the tags are `v0.1.0` through `v0.4.0`.

As with v0.2 to v0.4, the only work is the release ACT, and it has two non-mechanical
questions: (a) the evidence basis, and (b) the claim. The Linux CI cell has STILL never run:
the #21 PR's `linux-amd64` check was the decision-0017 billing refusal (0 steps, no runner,
~3s). Like v0.4, v0.5 has no new conformance claim to state.

## Decision

1. **The v0.5 release ships one already-merged change (the ranged `validate-component`).**
   The release act itself adds no algorithm, no new `src/` library and no new test lane. Its
   deliverables are the documentation reconciliation, this record, the ledger close-out and
   the tag (0023 item 1).

2. **The release is one annotated tag `v0.5.0`, and the bump is MINOR (0.4.0 → 0.5.0).** The
   tag goes on the squash-merged reconciliation commit on `main`. Optional arguments on an
   existing export are a backward-compatible addition; no existing call changes behaviour.
   This is the same reasoning as `uri-collector-reset!` (v0.3) and `uri-parse-result-validate`
   (v0.4). `CMakeLists.txt` `VERSION` bumps `0.4.0` → `0.5.0`. The `(uri …)` libraries stay
   unversioned. Signing is the maintainer's discretion, not a gate.

3. **Doc reconciliation adds the capability and keeps every claim and boundary verbatim.**
   - `README.org`: the status flips to v0.5.0. The summary gains one sentence (judge a
     buffer-held span in place, #21), and the API paragraph names `validate-component` and
     its optional range.
   - Kept VERBATIM, since #21 touches none of them: the conformance sentence, the "not a
     blanket compliant" caveat, the CI-not-run quote, the strict-resolution clause, the
     round-trip §4.2/§3.3 boundary, the not-portable clause and the
     normalize-no-dot-segments clause.
   - `CHANGELOG.md`: `[Unreleased]` becomes `[0.5.0] - 2026-09-25`, with a fresh empty
     `[Unreleased]` above it, one feature section in the measured mutation-witness voice,
     and updated version links. The frozen `[0.4.0]` to `[0.1.0]` entries are untouched.

4. **The honest claim: v0.5 states NO NEW conformance claim and carries v0.3's unchanged.** The
   ranged form is the same M3 component charset judge that `uri-parse-validate` applies (the
   judge audited at 0030), reached over a span. It judges a component's CHARSET, not its
   structure, exactly as the two-argument form always has: where the delimiters fall is the
   caller's split. The CHANGELOG says so explicitly, because an origin-form server makes that
   split itself. The release states a new CAPABILITY (judge a span in place, allocating
   nothing), NOT a broadening of conformance.

5. **v0.5 releases on STILL-never-run CI, disclosed not waived** (as 0023/0027/0031/0033). The
   CHANGELOG `[0.5.0]` preamble and the tag message carry the CI-never-ran fact and the
   macOS-arm64-local basis. 0017 item 3 and its two never-executed predictions remain OPEN;
   the first funded CI run discharges them.

6. **The release-verification gate is a fresh re-measure at the release commit.** Counts come
   from re-running `ctest --preset release` and `ctest --preset no-scheme` (each
   `--no-tests=error`) on the post-edit tree, date- and platform-stamped, never carried
   forward by arithmetic (0023 item 6). This session can build, so the re-measure is run
   here, on the reconciled tree before its commit. The squash merge is pinned to that head
   with `--match-head-commit`, so the tagged tree is the measured tree.

7. **The publish steps run under the maintainer's "Do the v0.5 release", in the closing
   ritual, which is asked for before it runs (AGENTS.md).** Those steps are the
   reconciliation PR, its squash merge, the annotated tag and its push. A GitHub Release is
   NOT cut automatically. If the maintainer wants one, its body is the CHANGELOG `[0.5.0]`
   section verbatim, including the CI disclosure.

## Consequences

- The release commit adds no lane and no algorithm; `src/` is byte-identical to bb8392a's.
- chez-http-server can consume the ranged `validate-component` from a tag and retire its
  copy workaround.
- What reopens next is a separate choice, not a v0.5 gap:
  - the first funded CI run (0017 item 3);
  - the deferred ranged `validate-authority` (0034 item 6);
  - the result-level authority-form validator (0032 item 4);
  - v0.5+ tooling (0012, 0022);
  - the next sibling request.
