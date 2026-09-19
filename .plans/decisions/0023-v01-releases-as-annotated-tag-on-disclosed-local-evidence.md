# 0023: v0.1 releases as the annotated tag v0.1.0 on the reconciled commit, and this record is the amendment that ships it on never-run CI

Date: 2026-09-18
Status: accepted
Plan: [the brief](../2026-09-18-chez-uri-project-brief.md) "M8 — release v0.1"
(a heading only — the brief intentionally leaves the release checklist to be
DERIVED) and [the design](../2026-09-18-chez-uri-design.md) §6 ("What v0.1
therefore is, and what it must not claim").
References:
[0003](0003-the-normative-reference-is-rfc-3986.md) (RFC 3986 is the normative
reference; disagreement is adjudicated against the ABNF),
[0011](0011-v01-is-resolution-first.md) (v0.1 is resolution-first and
non-validating; M3 charset / M4 host grammar are v0.2),
[0017](0017-m1-ships-on-one-cell-and-it-is-not-the-linux-one.md) (CI has never
run; the M1 merge shipped on macOS-arm64-local evidence — this record is its
release-scoped successor),
[0020](0020-v01-normalizes-scheme-and-percent-and-defers-host-case.md),
[0021](0021-reference-resolution-recomposes-at-m6.md),
[0022](0022-the-round-trip-property-is-a-one-step-parse-recompose-identity.md)
(the core's scope boundaries the release notes must state honestly),
and the milestone-scope-decision pattern 0020/0021/0022 mirror.

## Context

M8 is the brief's "release v0.1" — a heading with no body, so the release
checklist is DERIVED, by this record and a four-lens release-readiness survey
(mechanics, doc reconciliation, the honest claim, verification/scope) synthesized
adversarially against the actual tree.

The v0.1 implementation arc is complete and merged to main: M2 (the generic
split / scanner), M5 (the pure core — percent + normalize), M6 (§5.2.4
remove-dot-segments, §5.2.3 merge, §5.2.2 strict resolution, §5.3 recompose; all
42 RFC §5.4 rows passing), M7 (the round-trip property, measured). `src/` is
UNCHANGED from M7 — nine hand-written `.sls` plus the committed generated
scanner. The code gate is green, re-measured on this tree (not carried forward):
release preset 63/63, no-scheme preset 11/11, 0 failures (Darwin arm64, Chez
10.4.1 machine-type tarm64osx, CMake/CTest 4.3.3, 2026-09-18), exercising both
the source and ahead-of-time lanes plus the import-audit, rename-audit,
provenance, corpus-provenance and both mutation suites. There are zero
`TODO`/`FIXME`/`XXX` in `src`/`tools`/`cmake`, all 22 prior decisions are
`accepted`, `LICENSE` is consistent, and `CMakeLists.txt` already declares
`VERSION 0.1.0`. There are no git tags yet.

So the only work M8 has is the release ACT, and its only non-mechanical question
is the evidence basis. Decision 0017 authorized MERGING M1 on never-run CI, but
it is explicitly scoped "an M1 amendment, not a standing policy," and its two
predictions (the Linux runner's machine-type derivation and the cold-runner AOT
lanes) "have never executed anywhere." The project's own convention — inherited
from byte-machine's decision 0041 and quoted in 0017 — is that an unfunded Tier-1
CI cell is "struck by an explicit amendment, never waived quietly in release
notes." A public v0.1 tag is a strictly larger claim than the M1 merge, so it
needs its OWN recorded ratification rather than silent inheritance of 0017.
"Go for m8" authorizes doing the milestone; it does not substitute for that
amendment. This record is that amendment, and the maintainer ratified
shipping-with-disclosure at the M8 Slice ⓪ gate.

## Decision

1. **M8 ships no algorithm, no new `src/` library, and no new test lane.** Its
   deliverables are the documentation reconciliation, this record, the ledger
   close-out, and the tag. The §5.4 gate and the round-trip property are already
   measured green, so nothing executable is added — adding a lane (a downstream
   consumption smoke) would change the re-measured count and break this charter.
   The survey's optional `docs/` quickstart and downstream-only load smoke are
   **v0.2**, not M8: an untested import-and-call example is itself an unmeasured
   claim (which the house rule forbids), and a load smoke is largely redundant
   with the source and aot conformance/round-trip lanes that already import and
   exercise the public libraries.

2. **The release is one annotated tag `v0.1.0`** — three-part SemVer with a `v`
   prefix, the exact convention of byte-machine (the dependency this repo
   consumes by gitlink: its tags are `v0.1.0`..`v0.6.0`, `v0.6.0` is an annotated
   object on a `docs(release): … (#138)` squash commit). It is placed on the
   squash-merged M8 reconciliation commit on `main`, **NOT** on `aced550`, which
   still carries the stale M7 status line and the unreleased CHANGELOG. No build
   or library metadata changes: `CMakeLists.txt` already declares `VERSION 0.1.0`
   and the `(uri …)` libraries stay unversioned (adding R6RS version fields would
   be a breaking import change, out of scope). Signing (`-s`) is the maintainer's
   key discretion, not a release gate.

3. **Doc reconciliation is structural, and the measured prose is preserved
   verbatim.** `README.org`'s status line flips to a released state; the
   five-caveat "will not claim until it is measured" block and the CI-not-run
   quote block stay verbatim — they ARE the honest claim the release ships. In
   `CHANGELOG.md`, the "This project has not been released" preamble becomes the
   standard Keep-a-Changelog opener, `## [Unreleased]` becomes
   `## [0.1.0] - 2026-09-19` with a fresh empty `## [Unreleased]` above it and
   version link refs appended. The M7..M1 milestone prose is **NOT** regrouped
   into Keep-a-Changelog `Added`/`Changed`: a strict-format content rewrite risks
   dropping the measured, mutation-witness detail that "a property is measured or
   it is not claimed" forbids losing. The reconciliation is headings, a status
   line and refs — not a content rewrite.

4. **The honest claim is taken from the decision records, not improvised.** v0.1
   is a non-validating URI SPLITTER (five coarse components — scheme, authority,
   path, query, fragment — in three modes: uri, relative-ref, uri-reference) plus
   a STRICT §5.2.2 reference RESOLVER plus a COMPLETE pure core (percent
   decode/encode, §6.2.2 scheme-case + percent normalization, §5.2.4
   remove-dot-segments, §5.2.3 merge, §5.3 recompose), with ALL 42 RFC §5.4 rows
   passing and the round-trip property MEASURED. It must **NOT** claim "RFC 3986
   compliant" (it is non-validating and accepts bytes the ABNF rejects:
   `http://exa mple.com/`, `%ZZ`, a malformed `IPv6address`), nor full §6.2.2
   normalization (host case is deferred to the v0.2 host grammar), nor
   portability (no second implementation is in CI). Every clause is grounded in
   decisions 0003/0011/0015/0020/0021/0022 and already mirrored in `README.org`'s
   caveat block; nothing is invented.

5. **This record is the amendment that releases v0.1 on never-run CI, disclosed
   and not waived.** 0017 is M1-scoped and does not, on its own text, authorize
   the public v0.1 tag; the house convention forbids quietly waiving a Tier-1
   cell. So 0023 explicitly ratifies — maintainer-approved at the M8 Slice ⓪ gate
   — releasing v0.1 on macOS-arm64-local evidence with the CI-never-ran fact
   carried into the release BODY (the CHANGELOG `[0.1.0]` section and the tag
   message), not a footnote. 0017 item 3 and its two never-executed predictions
   remain OPEN and disclosed; the first funded CI run discharges them, and a v0.2
   that runs the Linux cell replaces this disclosure with evidence.

6. **The release-verification gate is a fresh re-measure at the tagged commit.**
   The suite counts written into the tag message and the CHANGELOG `[0.1.0]` body
   come from re-running, AT the post-edit release commit, both selections:
   `ctest --preset release` (the complete selection off the dev configure preset
   — there is no separate `prod` test preset; this is what runs the source and
   aot lanes, the import/rename/provenance/corpus-provenance audits and both
   mutation suites) and `ctest --preset no-scheme`, each with `--no-tests=error`.
   The recorded numbers are date- and platform-stamped and never carried forward
   by arithmetic (global-constraints).

7. **Automation stops at a LOCAL annotated tag.** Pushing the tag to `origin`,
   squash-merging the reconciliation PR (the closing ritual), and creating any
   GitHub Release are outward-facing PUBLISH actions requiring explicit,
   per-action maintainer approval — never folded into an automated close-out.
   Creating the local annotated tag and authoring the PR are reversible and
   local, so they are not gated. A GitHub Release is optional (the gitlink pin
   needs only the pushed tag); if cut, its body is the CHANGELOG `[0.1.0]` section
   verbatim, including the CI disclosure.

## Consequences

- M8 adds no `src/` and no lane; the shipped tree is byte-identical to M7's
  `src/`. The milestone is documentation, a decision, a re-measure, and a tag.
- The smallest honest release is ONE PR (README status line + CHANGELOG
  reconciliation + this record + the ledger close-out), then a re-measure and a
  LOCAL tag on the merge commit. Every outward step after that is a separate,
  maintainer-gated action.
- v0.1 ships with 0017 item 3 OPEN and disclosed. A consumer needing
  cross-platform or second-implementation assurance waits for the first funded CI
  run; the release notes say so in the body so the wait is a stated fact, not a
  surprise.
- This is the last milestone of the v0.1 arc. v0.2 (M3 charset validation, M4 the
  host grammar) reopens the "validating" claim, host-case normalization, the
  deferred `docs/` quickstart and the downstream consumption smoke — each a v0.2
  decision, not a v0.1 gap.
