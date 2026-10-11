# 0043: v0.7 releases as the annotated tag v0.7.0 and adds the easy layer, on local evidence, with no new conformance claim

Date: 2026-10-11
Status: accepted
Plan: [the easy-layer plan](../2026-10-11-easy-layer.md), Slice ④. The release checklist is
[0037](0037-v06-releases-as-annotated-tag-and-adds-ranged-authority-validation.md)'s
(v0.6), the template begun at 0023.
References:
[0039](0039-the-first-funded-ci-run-passes-and-settles-0017-item-3.md) (CI has run, once),
[0040](0040-the-easy-layer-is-strings-at-the-edge-one-record-and-a-validated-domain.md),
[0041](0041-the-query-is-split-by-a-core-library-over-its-bytes-never-by-the-grammar.md),
[0042](0042-the-easy-layer-normalizes-dot-segments-and-guards-the-double-slash-shape.md)
(the three records the new libraries are held to),
[0030](0030-the-rfc-3986-conformance-audit-is-clean-recognition-equivalence-is-earned.md)
(the validation claim v0.3 stated and every release since carries unchanged).

## Context

The arc since v0.6.2 (tag on 5ecd88f) is eight merged pull requests:
- #33, a public-release comment sweep;
- #34, the hand-set-mode lane;
- #35, the README rewrite and NOTICE;
- #36 to #40, the easy layer: the plan, decisions 0040 to 0042 and the resolution pin,
  `(uri query)`, and `(uri easy)` in two halves, each with its review fixes.

Two libraries are new: `(uri query)` and `(uri easy)`. No existing library export or
signature changed. The complete selection grew from 78 lanes at v0.6.2 to 85: #34
added one, and the easy layer six (`unit.query`, `unit.easy` and `unit.easy-resolve`,
each in source and AOT). `CMakeLists.txt`
declares `VERSION 0.6.2`.

CI ran once, green, on #28 (0039). Every pull request in this arc was refused over billing
before a single step, verified from each run's annotation. The release is again on local
evidence.

## Decision

1. **The bump is MINOR, 0.6.2 → 0.7.0.** Two new public libraries are a backward-compatible
   addition. `CMakeLists.txt` `VERSION` moves to `0.7.0`. The `(uri …)` libraries stay
   unversioned. The tag is annotated `v0.7.0` on the squash-merged release commit; signing
   follows `tag.gpgSign`.

2. **Documentation is reconciled, and every example is run.**
   - `docs/easy.org` is new: a short guide to `(uri easy)`.
   - `README.org` leads with `(uri easy)` and adds the two libraries to "What it does" and
     the task table. "Scope and limits" says which normalizer removes dot segments, states
     the easy layer's ASCII-only input and strict UTF-8 decoding, and how it writes the
     `//` path.
   - Every Scheme example in both files is extracted and run, and its output compared
     with the file, before the release commit. A whole program must print its
     `#+begin_example`, and an expression must print its `;; =>` value. The checker was
     watched failing on deliberate edits first.
   - `CHANGELOG.md`: `[Unreleased]` becomes `[0.7.0] - 2026-10-11`, with a preamble giving
     the evidence basis and a fresh `[Unreleased]`. The frozen entries are untouched.

3. **No new conformance claim.** Parsing and validation are exactly v0.6.2's, and the
   scoped claim reads as before. The easy layer states what it is held to, as properties
   with witnesses rather than as a conformance claim:
   - all 42 §5.4 rows reproduced through strings;
   - the string round trip, faithful rendering and idempotent normalization, over the 211
     committed corpus inputs that validate;
   - strict UTF-8 decoding;
   - mutation witnesses for each rule, with the two equivalent survivors recorded
     (decisions 0040 to 0042 and the ledger).

4. **Released on local evidence, disclosed, not waived.** The CHANGELOG preamble and the
   tag message carry the billing refusals and the macOS arm64 basis.

5. **The release gate is a fresh measurement on the release tree.** `make test-all` (the
   complete selection) and `make no-scheme` are run on the reconciled tree before its
   commit. The squash merge is pinned with `--match-head-commit`, and the merged tree
   hash is compared with the tested one before tagging.

6. **The publish steps are the closing ritual, asked for before it runs (AGENTS.md).** The
   steps are the release PR's squash merge, the annotated tag and its push. A GitHub
   Release is not cut automatically; if the maintainer wants one, its body is the
   CHANGELOG `[0.7.0]` section.

## Consequences

- chez-http-server is unaffected: it imports none of the new libraries, and nothing it uses
  changed.
- A public release is still blocked on the byte-machine submodule being private (ledger
  NEXT). The tag does not change that.
- What reopens next is a separate choice:
  - the first funded CI run since #28;
  - building URIs from parts (out of the plan's scope);
  - a host-kind accessor;
  - a ranged `(uri query)`, if a server measures the need;
  - turning the example checker into a registered lane.
