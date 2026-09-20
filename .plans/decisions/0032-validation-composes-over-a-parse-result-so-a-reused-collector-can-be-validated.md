# 0032: validation composes over a parse result, so a reused collector can be validated

Date: 2026-09-19
Status: accepted
Plan: GitHub issue #18 (a server validates every request-target through
`uri-parse-validate`, which parses on a fresh collector; #11's `uri-collector-reset!`
saves that allocation only on the un-validated streaming path). Additive, pure Scheme.
References:
[0024](0024-charset-validation-is-the-cores-over-the-split-components.md) /
[0025](0025-the-host-grammar-is-the-cores-over-the-opaque-authority.md) (the M3/M4
component and host validators this exposes — the judgement `validate-result` already
composes, leftmost-first, over a parse result),
[0028](0028-the-rfc-3986-conformance-audit-is-recognizer-equivalence-against-an-independent-whole-uri-oracle.md) /
[0030](0030-the-rfc-3986-conformance-audit-is-clean-recognition-equivalence-is-earned.md)
(the audited recognizer this hands the embedder — the SAME code, not a second
implementation, is the whole point),
[0029](0029-a-collector-resets-in-place-for-per-connection-reuse.md) (#11 —
`uri-collector-reset!`; this closes the gap that reset left open: reuse without a
re-parse, but validation still forced one).

## Context

`uri-parse-validate` is `(uri-parse mode-sym bv)` followed by `(or (validate-result r) r)`
(`collect.sls:271-275`). The judgement — `validate-result` — is a `uri-parse-result ->
(Option uri-parse-result)` that walks the present components leftmost-first, rebasing each
core validator's component-relative index through the offset seam to an absolute offset
(`collect.sls:249-263`). It is already a pure function OF A RESULT, not of the bytes; but
it is not exported (the list at `collect.sls:19-27` omits it).

So the audited recognizer (0028/0030) is reachable only through `uri-parse-validate`, which
always builds a fresh collector. Decision 0029 gave a server one collector per connection
(`uri-collector-reset!`), retiring the per-request parser + two-hashtable allocation — but
only on the un-validated path. A server that validates request-targets (origin-form and
absolute-form through the RFC 3986 recognizer) still pays a full fresh-collector parse per
request, because the collected result from `uri-collect-finish!` has no way to reach
`validate-result`. Issue #18 measured it (Darwin arm64, Chez 10.4.1, uriparse at v0.3.0): a
46-byte origin-form target costs 3680 bytes / ~1.2 µs through a fresh collector versus 1584
bytes / ~0.5 µs through a reset one — a cost the validating server cannot avoid, so #11's
benefit does not reach it.

`(uri charset)`'s `validate-component` and `(uri host)`'s `validate-authority` are already
exported, but composing them in an embedder would re-implement `validate-result`'s
leftmost-first walk and its offset rebasing — copying the audited recognizer instead of
calling it, and drifting from it.

## Decision

1. **The post-parse judgement is exposed as a public `uri-parse-result-validate :
   uri-parse-result -> uri-parse-result`.** It applies the audited leftmost-first component
   judgement (0024/0025, audited clean at 0028/0030) to an already-parsed result: it returns
   the result UNCHANGED when the result is not `ok?` (a structural error passes straight
   through, as it must — its components are `#f`) or when every present component is valid,
   and otherwise the validation ERROR result `validate-result` produces (`ok? #f`, the core
   code, the absolute offset). It is exactly the `(if (uri-parse-ok? r) (or (validate-result
   r) r) r)` that lived inside `uri-parse-validate`, lifted to the top level and named.

2. **`uri-parse-validate` is redefined as `(uri-parse-result-validate (uri-parse mode-sym
   bv))` — behaviour-preserving.** The one-shot entry point is unchanged in outcome for
   every input; it now delegates its judgement half to the new function instead of inlining
   it. This is a refactor with a new seam, not a behaviour change: the existing M3/M4
   charset/host lanes (which drive `uri-parse-validate` end to end over the negative and
   positive corpora) are the standing guard that the outcome did not move.

3. **The point (the #11/#18 tie): a reused collector is validated by calling
   `uri-parse-result-validate` on its `uri-collect-finish!` result.** A server holding one
   collector per connection (0029) does `feed!` … `finish!`, then
   `(uri-parse-result-validate result)`, then `reset!` — and gets the SAME audited
   recognizer verdict as `uri-parse-validate` would give, with no re-parse, no second
   implementation, and no fresh allocation. The composability property the lane pins:
   for every mode and input, `(uri-parse-result-validate (uri-collect-finish! c))` after
   feeding `bv` into a collector `c` of that mode equals `(uri-parse-validate mode bv)` —
   ok-for-ok, code-for-code, offset-for-offset. This holds because `finish!` and `uri-parse`
   build the same result record (same components, same offset seam), and the validation is a
   pure function of that record.

4. **The authority-form result validator is DEFERRED (issue #18's optional part, "Not
   needed for v1").** `uri-parse-authority-form-validate` still takes a whole bytevector and
   splices; this change does not add a `uri-parse-result`- or collector-level authority-form
   validator. The authority-form path splices "//" and re-maps offsets (0026), so a
   result-level entry point there is a separate, larger seam than the RFC 3986 recognizer's,
   and no request has measured a need for CONNECT-target reuse. If one arrives it is its own
   additive function.

5. **No new library, no scanner/grammar change, and no release-scoped doc edit at merge.**
   `(uri collect)` gains one export and one top-level definition; the generated scanner,
   the grammar, `uri-parse`, and the authority-form pair are untouched. Like M3/M4/M9 and
   #11 (0029 item / consequence), the user-facing README/CHANGELOG note rides the NEXT
   release, not this merge.

## Consequences

- `(uri collect)` gains one export (`uri-parse-result-validate`); `uri-parse-validate` is
  now one line over it. `src/` otherwise unchanged — no algorithm, no new library, no lane
  registration change: the new checks live in the already-registered `unit.collect` lane and
  reach the audited validators through `(uri collect)`, which itself imports `(uri charset)`
  and `(uri host)` (the lane imports neither directly, and needs no new import — R6RS import
  is not transitive, but `validate-result` lives in the library, which does import them).
- chez-http-server can validate a reused collector's result without the fresh-collector
  parse: the #11 workaround on the VALIDATED target path (issue #18's "accept the allocation
  for v1") retires, alongside the un-validated one #11 already retired.
- The audited recognizer (0028/0030) is now reachable as a function of a parse result, not
  only of raw bytes — an embedder that has already parsed (for its own offsets, or on a
  reused collector) judges that same result rather than re-parsing to validate.
- What stays deferred is a separate choice, not a gap: a `uri-parse-result`/collector-level
  authority-form validator (item 4), if a CONNECT-target-reuse request ever measures the
  need. The next release states the new export in the changelog; this merge does not.
