# 0024: charset validation is the core's, over the split components (the scanner stays delimiter-only)

Date: 2026-09-19
Status: accepted
Plan: [the brief](../2026-09-18-chez-uri-project-brief.md) "M3 — charset
validation" and [the design](../2026-09-18-chez-uri-design.md) §6 (whose
grammar-side sizing note this record supersedes).
References:
[0003](0003-the-normative-reference-is-rfc-3986.md) (RFC 3986 is normative;
disagreement is adjudicated against the ABNF),
[0005](0005-the-corpus-is-the-rfcs-own-vectors.md) (the corpus + oracle-from-RFC
discipline; two provenances, two counts),
[0007](0007-src-is-pure-r6rs-and-chez-is-confined.md) (src is pure R6RS),
[0009](0009-an-error-names-the-abnf-production-that-failed.md) (an error names the
ABNF production that failed, and carries an offset; amended by 0019 to move
charset codes to the core),
[0011](0011-v01-is-resolution-first.md) (v0.1 is resolution-first and
non-validating; M3/M4 are v0.2),
[0012](0012-the-corpus-instruments-abnfgen-and-mutation.md) (abnfgen is the
positive generator),
[0019](0019-the-scanner-splits-five-coarse-components-and-the-core-owns-the-authority.md)
(item 5: the scanner's error vocabulary is the four structural codes; host and
charset errors are the core's), and the milestone-scope-decision pattern
0020/0021/0022/0023 mirror.

## Context

M3 is the brief's charset-validation milestone: turn the v0.1 splitter into a
validator that rejects bytes the ABNF forbids, with an error offset. It is the
first milestone of v0.2 (v0.1.0 is released and frozen, tag 264c997).

The milestone's forcing question was WHERE charset validation lives, and the
record conflicted. [The design](../2026-09-18-chez-uri-design.md) §6 (an early
draft) says M3 "changes those [scanner] nodes' fallback edge from accept to error
and adds two nodes per component for `pct-encoded` ... the node count barely
moves" — i.e. GRAMMAR-side, regenerating the `(generated uri-scanner)`
byte-machine artifact. But [decision 0019](0019-the-scanner-splits-five-coarse-components-and-the-core-owns-the-authority.md)
item 5 (accepted at M2, later than the design draft) says the scanner's error
vocabulary is ONLY the four structural codes and that "Host and charset errors
(`invalid-ip-literal`, `invalid-dec-octet`, `invalid-pct-encoded`, …) are the
core's, raised where the core validates."

A four-lens scoping survey (placement, scope+offsets, the ABNF charsets, the
negative corpus) settled it against the actual code, and it is **not a close
call**. Three facts decide it:

1. 0019 item 5 is accepted and is the line the shipped code is built around:
   `vocabulary.sls` and `grammar.sls` restate it verbatim.
2. `test/common/vocabulary-tests.sps` already asserts `invalid-pct-encoded` /
   `invalid-scheme` / `invalid-reg-name` / `invalid-dec-octet` / … **out** of the
   scanner's error set, with a green, mutation-witnessed test. The code already
   enforces core-side placement; going grammar-side would redden it.
3. The design's own amendment banner already concedes "§6's milestone sizing
   shift accordingly" under 0018/0019 — so §6's grammar-side note is the stale
   prose the project expects (the sibling memory note: the prose lags the code on
   the points that matter most).

The one novel argument the survey surfaced FOR grammar-side — that a forward-only
machine "literally cannot" validate the mode-3 scheme before the `:` verdict —
does not survive: byte-machine has uint fields and `field-branch`, so a
scheme-illegal-byte taint could be carried and branched. Grammar-side is
*possible but redundant and costly*, not impossible; core-side wins on the
accepted decision plus zero ABI/determinism blast radius, not on a false
impossibility.

## Decision

1. **Placement: charset validation is the core's; the scanner stays
   delimiter-only.** M3 validates charsets in the pure core over the split
   component bytevectors. The scanner keeps its four structural codes
   (`mode-unset`, `scheme-required`, `scheme-forbidden`, `unexpected-eof`) and its
   six coarse spans — `(generated uri-scanner)` is NOT regenerated, and the ABI-9
   and determinism lanes are untouched. This is the existing 0009/0019 seam
   (structural failures are the scanner's, charset failures the core's), not a new
   split. Design §6's grammar-side note is **superseded** and reconciled in place
   with a pointer to this record (as 0008/0009 were amended after 0019).

2. **Scope: scheme, path, query, fragment (+ `pct-encoded`). `port` and every
   authority-interior charset slip to M4.** M3 validates exactly the four coarse
   components the core holds whole: `scheme` (first byte ALPHA, then
   ALPHA / DIGIT / "+" / "-" / "."), `path` (`pchar` ∪ "/"), `query` and
   `fragment` (`pchar` ∪ "/" ∪ "?"), plus `pct-encoded` (`"%" HEXDIG HEXDIG`) in
   path/query/fragment. `port` (`*DIGIT`) and every authority-interior charset
   (userinfo, host/`reg-name`, `IP-literal`) are DEFERRED to M4, because the
   authority is one opaque bytevector until M4 splits userinfo/host/port and 0009
   item 1 cannot name the specific violated production without that split. This
   **corrects the brief**, which lists "port digits" under M3, and the design's
   `http://exa mple.com/` space-in-host headline — both predate 0019. The mode-2
   first-segment `:` is already the scanner's structural `scheme-forbidden`, so
   the path validator needs no first-segment special case and must NOT re-diagnose
   `:` as a charset error.

3. **Error offsets: the validators are pure and component-relative; the shell
   ((uri collect)) rebases to an absolute input offset.** A charset predicate is
   pure over a component bytevector and returns a component-RELATIVE index; the
   imperative shell records each present span's absolute start offset (from the
   runtime's committed stream offset) and rebases relative → absolute before the
   parse result. The reported offset is ABSOLUTE, to match the scanner's
   structural offsets. The PATH base offset is NOT the raw path-span mark:
   `on-rooted` drops a leading `/` and mode-3 stitches `leading-token` onto the
   path, adjustments only the shell knows. The exact arithmetic MUST be witnessed
   against `collect-tests`' absolute offsets and the three path shapes before it
   is trusted — the runtime's comment is not a substitute for a measured case.
   This is the single genuine core-side cost, and it is cheaper than a scanner
   regeneration.

4. **The validator lives in a new pure `(uri charset)`; `(uri percent)` is NOT
   extended.** `(uri charset)` imports `(uri percent)`'s `unreserved-byte?` and
   `hex-digit-value` and `(uri components)`, and holds the four component
   predicates and the `pct-encoded` validating scan, pure over a bytevector,
   applied uniformly across all three modes (the mode only gates which components
   are present). `(uri percent)` is deliberately total/non-validating (decision
   0011); folding validation in would breach that. `hex-digit-value` already
   returns `#f` for a non-hex byte, so the validating `%`-then-two-`HEXDIG` scan
   reuses it directly. This mirrors the `(uri normalize)`-imports-`(uri percent)`
   precedent: mechanics in `percent`, policy in the new library.

5. **A core error vocabulary, named per ABNF production, kept out of the scanner
   set.** M3 introduces core error codes — `invalid-scheme`, `invalid-pchar`
   (path segments), `invalid-query`, `invalid-fragment`, `invalid-pct-encoded` —
   each in the RFC's own hyphenated spelling (0009 item 1). They live with the
   core, NOT in `(uri vocabulary)` (the scanner's table). Structural and charset
   failures stay distinct codes even at the same byte (0009 item 4).
   `vocabulary-tests.sps`'s assertion that these codes are OUT of the scanner set
   stays green as the seam guard, and each new code must have a reachable core
   path in M3 (0009 item 6: a declared error no path raises is a promise not
   kept).

6. **The negative corpus is hand-derived from the ABNF, tagged
   `(production, absolute-offset)`, with its own provenance.** M3 needs invalid
   inputs to witness rejection, and none exist. They are hand-derived from
   `rfc3986.abnf` INDEPENDENTLY of the code (oracle discipline, 0005/0012),
   covering scheme/path/query/fragment and `pct-encoded`, each tagged with the
   production it violates and its absolute expected offset, each cross-checked
   derive-then-refute. **It does not belong in `test/conformance/rfc3986/`**,
   which is entirely RFC-text-derived by `cmake/UriCorpus.cmake` and guarded by
   the corpus-provenance lane; it is a SEPARATE, separately-labelled provenance
   ("ours, derived from the ABNF, not extracted from the RFC text") with a count
   reported apart from the §5.4 / §1.1.2 positive sets (0005 item 3). It is gated
   by a plain offset-pinned negative lane plus per-production coverage floors, NOT
   a ratchet (the ratchet is the finite normative §5.4 set alone). Hand-deriving
   trades away 0012 item 4's "offset for free," so each offset is defended from
   the ABNF; the abnfgen positive generator and a charset-aware mutator are
   DEFERRED v0.2 tooling (they also serve M4), not silently skipped.

7. **M3 opens v0.2; v0.1.0 stays frozen.** v0.1's disclosed non-claim — "a
   splitter, not a validator; it accepts `http://exa mple.com/`, `%ZZ`, a
   malformed `IPv6address`" — is precisely what M3 turns, and that disclosure is
   updated only WHEN M3 measures the new rejection property, never before. No
   build/library version changes in M3; the version bumps at a v0.2 release.

## Consequences

- M3 adds two pure `src/` libraries — `(uri charset)` and a small core error
  vocabulary — plus a shell change in `(uri collect)` for the offset seam. The
  scanner, the generated artifact, and the ABI/determinism lanes are untouched.
- The milestone is three slices: **⓪** this record + the design-§6 reconciliation
  + the ABNF byte-set oracle + the hand-derived negative corpus (no validator
  code); **①** the absolute-offset seam in `(uri collect)`, witnessed against the
  three path shapes; **②** the `(uri charset)` validator wired through the shell,
  gated by the negative corpus (each vector witnessed red first) and the untouched
  positive corpora.
- `port` and the host grammar's charsets are M4's, recorded here so the brief's
  "port digits" line is a deprecated-with-a-pointer boundary, not a silent gap.
- The "RFC 3986 compliant" claim stays unearned until M4 completes the validating
  surface (host grammar); M3 earns "validates scheme/path/query/fragment
  charsets", measured, and nothing more.
