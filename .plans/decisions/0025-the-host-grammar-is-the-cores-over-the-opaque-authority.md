# 0025: the host grammar is the core's, over the opaque authority (and M4 closes host-case)

Date: 2026-09-19
Status: accepted
Plan: [the brief](../2026-09-18-chez-uri-project-brief.md) "M4 — the host grammar"
and [the design](../2026-09-18-chez-uri-design.md) §6 (whose IPv6 node-count /
decision-callback-fallback sizing note this record supersedes).
References:
[0003](0003-the-normative-reference-is-rfc-3986.md) (RFC 3986 is normative;
disagreement is adjudicated against the ABNF),
[0005](0005-the-corpus-is-the-rfcs-own-vectors.md) (the corpus + oracle-from-RFC
discipline; two provenances, two counts),
[0007](0007-src-is-pure-r6rs-and-chez-is-confined.md) (src is pure R6RS),
[0009](0009-an-error-names-the-abnf-production-that-failed.md) (an error names the
ABNF production that failed, and carries an offset; item 6: a declared code needs a
reachable path),
[0011](0011-v01-is-resolution-first.md) (M3/M4 are v0.2),
[0012](0012-the-corpus-instruments-abnfgen-and-mutation.md) (abnfgen + the mutator
are deferred v0.2 tooling),
[0019](0019-the-scanner-splits-five-coarse-components-and-the-core-owns-the-authority.md)
(item 3: userinfo/host/port are NOT scanner spans; item 4: the host grammar moves
to the core; item 5: host errors are the core's),
[0020](0020-v01-normalizes-scheme-and-percent-and-defers-host-case.md) (item 2:
host-case normalization is deferred to M4 — closed here),
[0024](0024-charset-validation-is-the-cores-over-the-split-components.md) (M3's
mirror; item 2 deferred `port` and every authority-interior charset to M4), and the
milestone-scope-decision pattern 0020/0021/0022/0023/0024 share.

## Context

M4 is the brief's host-grammar milestone: sub-split the authority into
userinfo/host/port and validate them — `reg-name`, `IPv4address`, `IP-literal` →
`IPv6address` / `IPvFuture`, and `port` — the surface [decision 0024](0024-charset-validation-is-the-cores-over-the-split-components.md)
item 2 explicitly deferred here. It is the last milestone of v0.2's validating
surface (v0.1.0 is released and frozen, tag 264c997; M3 shipped the coarse-component
charsets, merged 3686dc6).

The milestone's forcing question is the analog of M3's — WHERE the host grammar
lives, scanner-side or core-side — and, as in M3, **it is already answered by the
code, not the plan, and it is not a close call.** Three facts decide it:

1. [Decision 0019](0019-the-scanner-splits-five-coarse-components-and-the-core-owns-the-authority.md)
   items 3–5 are accepted (at M2) and are the line the shipped code is built around:
   userinfo/host/port are pure core functions over the `authority` bytevector, the
   host grammar moves to the core, and the host errors are the core's.
   `vocabulary.sls` and `grammar.sls` restate this verbatim.
2. `test/common/vocabulary-tests.sps` already asserts, green and mutation-witnessed,
   that `authority` is one span while `userinfo`/`host`/`port` are NOT spans, and
   that `invalid-userinfo` / `invalid-reg-name` / `invalid-ip-literal` /
   `invalid-dec-octet` / `invalid-port` are OUT of the scanner's error set. The code
   already enforces core-side placement; a scanner-side split would redden it.
3. The generated scanner confirms it: the `authority` span (`uri-scanner.sls`
   `auth-open`/`auth-scan`/`auth-close`) scans the authority as one undifferentiated
   loop, recognizing only `#` / `/` / `?` — the authority's END — and never `@`,
   `:` or `[`/`]` inside it. No host-grammar code exists anywhere in `src/`.

The design's §6 M4 note (it budgets `IPv6address` at 40–60 byte-machine nodes and
says "do not reserve the fallback") predates 0019 and describes the host grammar as
SCANNER/byte-machine work — the same staleness [decision 0024](0024-charset-validation-is-the-cores-over-the-split-components.md)
found in §6's charset note (the sibling memory: the prose lags the code on the
points that matter most). Superseded and reconciled in place below.

## Decision

1. **Placement: the host grammar is the core's; the scanner stays delimiter-only.**
   M4 validates userinfo/host/port in the pure core over the opaque `authority`
   bytevector. The scanner keeps its four structural codes and six coarse spans —
   `(generated uri-scanner)` is NOT regenerated, and the ABI-9 and determinism lanes
   are untouched. This is the existing 0009/0019 seam (0019 item 4: the host grammar
   moves to the core), not a new split. Design §6's IPv6 node-count /
   decision-callback-fallback note is **superseded** and reconciled in place with a
   pointer to this record (as 0008/0009 were amended after 0019, and §6's charset
   note after 0024).

2. **Scope: userinfo, host (`reg-name` / `IPv4address` / `IP-literal` →
   `IPv6address` / `IPvFuture`), `port`, plus reused `pct-encoded`.** M4 validates
   the authority interior, per RFC 3986 §3.2:
   - `authority = [ userinfo "@" ] host [ ":" port ]`
   - `userinfo = *( unreserved / pct-encoded / sub-delims / ":" )`
   - `host = IP-literal / IPv4address / reg-name`
   - `port = *DIGIT` (empty port is valid: `host:` splits an empty port)
   - `reg-name = *( unreserved / pct-encoded / sub-delims )`
   - `IP-literal = "[" ( IPv6address / IPvFuture ) "]"`
   - `IPv4address = dec-octet "." dec-octet "." dec-octet "." dec-octet`, each
     `dec-octet` in 0–255
   - `IPv6address` = the `::`-compression counting grammar (up to eight `h16`, one
     optional `::`, an optional trailing `IPv4address` as `ls32`)
   - `IPvFuture = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )`

   This completes the validating surface 0024 deferred, and corrects the brief's
   "port digits" boundary (0024 item 2's deprecated-with-a-pointer line).

3. **The host disambiguation is an ordered union with a permissive tail, so
   `invalid-dec-octet` is only reachable INSIDE brackets.** RFC 3986 §3.2.2 applies
   first-match-wins: a leading `[` commits to `IP-literal` (no `reg-name` starts with
   `[`, so there is no fallback and a malformed literal is `invalid-ip-literal`);
   otherwise `IPv4address` is tried, and a string that fails it — e.g. `999.1.1.1`
   (999 > 255) — **falls through to `reg-name`, which admits digits and dots, so it
   is a VALID host, not an error.** Therefore the `dec-octet` range check (and the
   `h16`/group-count checks) fire ONLY within an `IP-literal`'s `IPv6address`, where
   there is no `reg-name` fallback. `invalid-dec-octet` is reachable through
   `[::ffff:999.1.1.1]`, never through a bare dotted quad (0009 item 6: every
   declared code needs a reachable path). This is M4's counterpart to M3's
   leftmost-error trap: a code that LOOKS reachable bare but is only truly reachable
   in brackets. The negative corpus reaches it only through `[...]`.

4. **The authority split is bracket-aware; offsets rebase onto the
   already-captured authority start.** Split `userinfo` at the single literal `@`
   FIRST (this also consumes userinfo's own `:`); then split `host`/`port` at the
   `:` AFTER the closing `]` for an `IP-literal`, or the first `:` for
   `reg-name`/`IPv4address`. `[::1]:80` → host `[::1]`, port `80` — splitting on the
   first `:` would corrupt it, so the `]`-aware split is load-bearing. The validators
   are pure over a bytevector and return an authority-RELATIVE index; the shell
   ((uri collect)) ALREADY records the authority's absolute start offset (the
   0024 item 3 seam — `assemble-offsets` captures `authority`, exposed by
   `uri-parse-component-offset`), so it rebases relative → absolute exactly as M3's
   `validate-result` does, with NO new offset seam. `userinfo` → `host` → `port` is
   the leftmost order within the authority; the authority is visited after `scheme`
   and before `path` in `uri-parse-validate`'s input-order walk.

5. **The validator lives in a new pure `(uri host)`; `(uri percent)` and
   `(uri charset)` are NOT extended.** `(uri host)` imports only `(uri percent)`'s
   `unreserved-byte?` and `hex-digit-value` (it operates on a raw authority
   bytevector, so it needs neither `(uri components)` nor the shell), and holds the
   bracket-aware split, the userinfo/reg-name/port predicates, the
   `IPv4address`/`dec-octet` check, and the `IPv6address`/`IPvFuture`/`IP-literal`
   validators, pure over a bytevector, applied uniformly across all three modes (the
   mode only gates whether an authority is present). The `IPv6address` validator is a
   **counter** — groups-seen, saw-`::`, per-`h16` hex-digit-count, optional trailing
   `IPv4address` — NOT a transcription of the nine ABNF alternatives (ABNF cannot
   count; the RFC writes nine cases for a three-counter machine), which is precisely
   why the design's scanner-node estimate is moot: as a pure core function it is a
   small function, not a fight with the machine. It is written INDEPENDENTLY of the
   test-side `(uri test host-oracle)`; the two are two readings of the same ABNF, and
   their agreement on every input is the check (0005/0012). This mirrors the
   `(uri charset)` precedent: policy in a new pure library, primitives from
   `(uri percent)`.

6. **The core error vocabulary gains the host codes, kept out of the scanner set.**
   `(uri host)` names `invalid-userinfo`, `invalid-reg-name`, `invalid-ip-literal`,
   `invalid-dec-octet`, `invalid-port`, and reuses `invalid-pct-encoded` (userinfo
   and reg-name admit `pct-encoded`) — each the RFC's own hyphenated spelling (0009
   item 1), living with the core, NOT in `(uri vocabulary)`. `vocabulary-tests.sps`
   already pins these OUT of the scanner set; that pin stays green as the seam guard,
   and each code has a reachable core path (dec-octet/ip-literal via brackets, item
   3; the rest via a bare invalid byte).

7. **The negative corpus is hand-derived from the ABNF, tagged
   `(production, absolute-offset)`, with its own provenance** — the same discipline
   as M3's (0024 item 6). It covers userinfo / host (`reg-name`, `IPv4address`,
   `IP-literal`, `IPv6address`, `IPvFuture`) / `port` / `dec-octet` and reused
   `pct-encoded`, each row hand-derived from `rfc3986.abnf` independently of the code,
   tagged with the violated production and its ABSOLUTE offset, each cross-checked
   against `(uri test host-oracle)` derive-then-refute. `invalid-dec-octet` and the
   IPv6 group/`h16` faults are reached ONLY through `[...]` (item 3); a two-fault
   authority pins the `userinfo` → `host` → `port` visit order (M3's leftmost
   lesson). It lives in `test/conformance/host/`, separately labelled ("ours,
   derived from the ABNF, not extracted from the RFC text"), counted apart from the
   positive §1.1.2 / §5.4 sets (0005 item 3), and gated by the cross-check plus
   per-production coverage floors, NOT a ratchet.

8. **M4 also closes host-case normalization (decision 0020's deferred half).** Once
   `(uri host)` can isolate the host within the authority, `(uri normalize)`'s
   `normalize-components` applies the §6.2.2.1a ASCII fold to the isolated host
   ONLY — `userinfo` stays case-SENSITIVE and `port` is digits — reusing the
   `ascii-downcase` already written for the scheme (0020 item 2: "no rework, just a
   newly reachable component"). A test pins the host lowercased AND userinfo case
   preserved (`User:S3cret@Example.COM` → `User:S3cret@example.com`). This discharges
   0020's honesty obligation: `normalize-components`' doc and README's "will not
   claim" list drop the "host case deferred" caveat, and v0.2 presents a COMPLETE
   §6.2.2.1 normalizer (scheme case + host case + percent). `uri-parse` (the lenient
   splitter) is unchanged; host-case normalization stays on the existing normalize
   path, distinct from the `uri-parse-validate` validating path.

## Consequences

- M4 adds one pure `src/` library — `(uri host)` — plus a `(uri collect)` wiring
  change (the authority enters the `uri-parse-validate` walk and `component-bytes`
  gains an `authority` case) and a `(uri normalize)` change (isolate + fold the
  host, reusing the split). The scanner, the generated artifact, and the
  ABI/determinism lanes are untouched.
- The milestone is four slices: **⓪** this record + the design-§6 reconciliation +
  the `(uri test host-oracle)` ABNF oracle + the hand-derived negative corpus (no
  validator code); **①** `(uri host)`'s bracket-aware split + the
  userinfo/reg-name/port/`IPv4address`/`dec-octet` validators wired through the
  shell, offsets witnessed against hand-counted authorities; **②** the
  `IPv6address`/`IPvFuture`/`IP-literal` validators (the counter), exhaustive oracle
  agreement over a hand-counted valid/invalid IPv6 battery, and the bracket-only
  `invalid-dec-octet`/`invalid-ip-literal` corpus; **③** host-case normalization
  (0020's close) + the honesty-obligation update to `normalize-components` and
  README.
- With M4 the validating surface is complete AND 0020's last deferred §6.2.2.1
  transform is closed, so v0.2 earns "validates the RFC 3986 charsets, whole
  authority included, and normalizes scheme + host case + percent", measured. The
  broader "RFC 3986 compliant" claim remains a separate audit and still requires the
  first funded CI run (0017 item 3); M4 does not auto-grant it.
- The abnfgen positive generator and the charset/host-aware mutator stay DEFERRED
  v0.2 tooling (0012, 0024 item 6), not silently skipped; the hand-derived corpus is
  the M4 stand-in, as it was for M3.
