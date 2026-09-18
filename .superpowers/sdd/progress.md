# chez-uri — subagent-driven development ledger

`progress.md` is the spine; `global-constraints.md` binds every task brief. Read
both before starting slice work. Close-outs are recorded here.

M0/M1 predate this ledger. M1 shipped the design, decisions 0001–0017 and the
instrument (no parser) — PR #1, squash-merged as b598f34. The gate M2 would
otherwise open (the mode decision, the span vocabulary, where v0.1 stops) was
settled there: decision 0004 (the ambiguity and the mode field) and the design
doc §3–§5 are written, so M2 goes straight to slice work.

---

M2 — THE GENERIC SPLIT, AND THE MODE DECISION. Branch feat/m2-generic-split.

Plan: .plans/2026-09-18-chez-uri-design.md §3 (the scanner ABI), §4 (the
scheme/first-segment ambiguity), §5 (the libraries and what lands at M2).
Brief: .plans/2026-09-18-chez-uri-project-brief.md "M2 — the generic split".
Decisions in force: 0002 (submodule + ABI 9), 0004 (modes), 0007 (pure R6RS
src), 0008 (one span per component; absent ≠ empty), 0009 (an error names the
ABNF production), 0011 (v0.1 is resolution-first, so the §5.4 ratchet is M6's
and does NOT move here).

Base at start: b598f34 (local main == origin/main, verified in sync).

Measured environment for this milestone (2026-09-18, Darwin arm64): Chez 10.4.1
(machine-type tarm64osx), CMake/CTest 4.3.3. Baseline on main before any slice:
release preset 38/38, no-scheme preset 10/10.

WHAT M2 SHIPS (design §5): five libraries — `(uri vocabulary)` (pure, imports
nothing: span/callback/error names and the mode integers), `(uri grammar)`
(build-time source machine), `(generated uri-scanner)` (committed derived
artifact), `(uri components)` (the seam type), `(uri collect)` (the shell,
callbacks → components). Eight spans, all declared now because a span cannot be
refined into sub-spans later (design §3.1, fact 1): scheme, leading-token,
userinfo, host, port, path, query, fragment. No `authority` span — the presence
of `host` is the presence of the authority. Three modes (design §3.3): 1 uri,
2 relative-ref, 3 uri-reference; 0 refuses. Split on delimiters only; charset
validation is M3/v0.2 (its M2-revisit option, design §6, is declined — v0.1 is
resolution-first).

EXIT CRITERION (brief): chez-http-server can route on a path and read a raw
query. This is NOT a resolution-ratchet move — that ratchet is §5.4 and gated at
M6 (decision 0011). M2's evidence is the property/chunk-invariance lane (a parse
that reaches no error produces the same spans however the bytes arrive, and the
committed artifact agrees with the interpreted grammar), the §1.1.2 example URIs
parsing, and offset-pinned unit tests over hand-built split vectors.

SLICE PLAN (cadence: drive to gates — stop after Slice ⓪ and at the merge gate;
subagents for source surveys and per-slice adversarial review):

  ⓪  the pure seam + the submodule. `(uri vocabulary)` and `(uri components)`
     (both pure, independently testable, including the absent-vs-empty proof);
     `vendor/byte-machine` gitlink-pinned to v0.6.0; `tools/emit-machine.ss`
     scaffold and `make parser-refresh`; the rename-audit reconciliation for
     legitimate byte-machine forms. No grammar yet. — GATE.
  ①  the grammar, modes 1 & 2. `src/uri/grammar.sls` splitting scheme /
     authority(→userinfo/host/port) / path / query / fragment on delimiters;
     the committed `(generated uri-scanner)` and BOTH ABI-9 lanes (fresh emit +
     committed artifact); the three §3.5 rules obeyed; offset-pinned unit tests
     and mutation witnesses.
  ②  mode 3. The leading-token scanner built three times + the zero-width
     on-scheme-confirmed / on-segment-confirmed verdict events; the EOF-verdict
     spike (.plans/spikes/2026-09-18-eof-verdict-and-empty-span.sps) promoted to
     a registered lane.
  ③  `(uri collect)` + the instrument. Callbacks → uri-components (stitching
     leading-token + path on the segment verdict; reading an empty fragment as
     present-and-empty); the property/chunk-invariance lane; the example-URIs
     parse-through lane. Hits the exit criterion.
  CLOSE — merge gate + closing ritual (ask first) + reflection.

SLICE ⓪ OPEN (2026-09-18): ledger seeded; branch cut; byte-machine v0.6.0
source survey commissioned so the grammar and emitter are built against source,
not the reference prose.

SLICE-BOUNDARY CALL. Decision 0002 item 2 forbids landing the submodule in a
slice that invokes no emitter — an unexercised pin only rots. So Slice ⓪ folds
in the emitter and a MINIMAL real grammar (the smallest machine that exercises
span-start/dispatch/span-end/finish end to end), enough to drive both ABI-9
lanes and the determinism lane and make the pin load-bearing on the day it
lands. The full eight-span modes-1&2 split is Slice ①'s work; growing the
grammar across slices is the sibling's own pattern and ships no partial span
vocabulary to any consumer (the merged M2 carries all eight). This puts the
first gate after ALL the risky scaffolding — submodule, emitter, ABI lanes,
determinism lane, rename-audit reconciliation — is green, with the hard
mode-3 ambiguity and the shell deliberately on the far side of it.

Pin: byte-machine v0.6.0 = commit 0245db3 (verified via `rev-parse
v0.6.0^{commit}`; the annotated tag object fc8f4a2 dereferences to it). Url
https://github.com/Kiyomi-Computation-Systems/byte-machine.git, matching the
sibling's .gitmodules.

SLICE ⓪ COMPLETE (2026-09-18). Landed: `(uri vocabulary)` and `(uri
components)` (the pure seam), `vendor/byte-machine` pinned to v0.6.0, the
generator library root wired, and a smoke-machine ABI-9 lane. Evidence: release
43/43 (was 38), no-scheme 10/10, rename audit 56 files clean. Darwin arm64,
Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3.

`(uri vocabulary)` (18 cases / 77 checks) is the modes, the eight spans with
both callbacks each, the eighteen callback names and the M2 split-only error
set. `(uri components)` (15 cases / 33 checks) is the five-field seam type
(scheme, authority, path, query, fragment -- decision 0008 item 7; the
userinfo/host/port spans fold into `authority` in `(uri collect)`, Slice ③),
with absent (`#f`) kept distinct from present-empty (`#vu8()`) at construction,
in the predicates and in equality. Both are pure `(rnrs)` libraries; each runs
in source and aot modes. Three mutation witnesses, each watched red then
reverted: a charset code declared early (the negative M3 assertion + the count),
`#f` read as empty (the absent/empty partition), and the ABI expectation set to
8 (read 9 from the emitted text).

THE SMOKE-MACHINE ABI LANE IS THE PIN'S PROOF, NOT A PROJECT GRAMMAR. It builds
the smallest machine that exercises a byte dispatch, an accept, a reject and an
EOF route, emits it, and reads ABI 9 out of `(byte-machine-make-compiled-machine
9 ...)` in the emitted text -- decision 0002 item 3's "read, never remembered".
It also asserts the emitted library imports `(byte-machine runtime)` and nothing
else upstream, emits no tombstoned /v1 /v2 constructor, renders byte-identically
twice, and runs (accept/reject/eof). This invokes the emitter, so the submodule
is load-bearing the day it lands (decision 0002 item 2). Source only: the ABI is
the same question in both modes, and the source/aot pair returns with the first
real grammar.

TWO CORRECTIONS TO THE OPENING SLICE-BOUNDARY CALL, both measured:

  1. THE RENAME RECONCILIATION IS A NON-ISSUE HERE, unlike the sibling's. This
     project's rename audit hunts only the token of the repo it was copied from;
     byte-machine is the dependency it HAS and is named freely (RenameAuditSpec's
     own comment says so). So adding the generator root, `URI_GENERATOR_SOURCES`
     and the byte-machine imports needed no allowlist -- there is nothing here
     like the sibling's decision 0011. The audit DID bite once, correctly: a
     comment in generator-abi-tests.sps naming the sibling leaked the forbidden
     token and reddened on the first run. Reworded; the check earning its place.

  2. THE COMMITTED ARTIFACT, THE DETERMINISM LANE AND THE COMMITTED-ARTIFACT ABI
     LANE ARE SLICE ①'s, not Slice ⓪'s. They need the real grammar; without one
     there is no `src/generated/uri-scanner.sls` to commit or re-emit. Slice ⓪'s
     submodule proof is the smoke machine above, which is what the sibling's own
     M2 Slice ⓪ did. Decision 0002 item 4 (committed + determinism) is honored at
     the M2 merge, where the grammar has landed -- not at this gate.

ABI RESOLVED FROM SOURCE, closing the memory note's disputed number: the pin at
v0.6.0 defines `current-abi-version 9` (runtime.sls:109) and the emitter renders
it as the first literal of `byte-machine-make-compiled-machine` (compile.sls:
1020). The brief's 8 was superseded by decision 0002 and is now witnessed by a
lane, not just a record.

ADVERSARIAL REVIEW (subagent, pre-commit). No blockers; decision records honored
and the ledger counts verified exact against the tree. Two "passes right-or-
wrong" gaps closed before commit, each with a fresh mutation witness watched red:

  1. `uri-components=?` exercised the differ-direction on only three of five
     fields -- query, authority, path. Dropping the `scheme` (or `fragment`)
     clause left all cases green while two URIs with different schemes compared
     equal. This is the resolution/recompose oracle M6/M7 assert through, so it
     mattered. A case now differs solely in scheme and solely in fragment;
     witnessed by dropping the scheme clause (`scheme differs` reddened).
  2. Callback-name identity was spot-checked for three spans; a row mistyped to a
     self-consistent wrong name (still a symbol, distinct, count still 18)
     survived. The full `uri-callback-names` list is now pinned by identity;
     witnessed by renaming leading-token's callbacks.

  A third note -- the ABI witness mutates the test's own `expected-abi` rather
  than the pin -- was reviewed and left: it still proves the value is parsed from
  emitted text (non-vacuous) and would catch a pin that moved to another ABI; a
  stronger witness would need to perturb the emitter, which is not cheaply
  available.

GATE ⓪: passed. User: "go ahead with slice 1." Ultracode is on for this session
(a system-reminder confirms it), so the working style is: I drive the grammar
(a single interconnected artifact fan-out would only fracture), and workflows do
the survey and verification the user endorsed, run exhaustively.

SLICE ① OPEN (2026-09-18): `src/uri/grammar.sls` (modes 1 & 2), the emitter, the
committed `(generated uri-scanner)`, the committed-artifact ABI lane and the
determinism lane.

THE SPLIT ORACLE. Because a splitter has no normative component-split corpus
(§1.1.2's example URIs "carry no expected decomposition"), the test vectors must
not come from the same head that writes the grammar (the sibling's own rule:
numbers come from the oracle, never the code under test). A workflow fanned out
one agent per reference deriving its decomposition from RFC 3986's ABNF alone,
each cross-checked by an adversary told to refute it: 26/26 derived, **0
disagreements**. The table is the Slice-① test oracle; it confirmed the
load-bearing distinctions independently -- `http:///p` host EMPTY vs `http:/p`
host ABSENT (both path `/p`); `http://@h` userinfo EMPTY; `http://h:` port
EMPTY; `http://a` path EMPTY; `http://a?` query EMPTY.

TWO HARD AMBIGUITIES, BOTH THE SAME SHAPE AS DECISION 0004'S SCHEME/SEGMENT,
found by pressing on the machine rather than the prose (the prose called this
"delimiter work"):

  1. `//` (authority) vs a single `/` (path-absolute). Measured against
     byte-machine v0.6.0: a span's mark is always the cursor at span-start and a
     span cannot be re-marked (`invalid-span-state` on re-entry); there is no
     rewind; a sequence-dispatch keeps the bytes it consumed on a mismatch. So a
     leading `/` cannot be both "held back in case it is path content" and
     "discarded as the first half of `//`". Pre-opening path preserves the
     path-absolute `/` but pollutes the authority case with a spurious `//`;
     not pre-opening splits the authority but drops path-absolute's `/` (and
     cannot even tell `/p` from `p`). Delegated to a focused research subagent
     to find the idiom or the least-bad compromise, with the empirical findings
     handed over so it does not redo them. Two spikes recorded the facts:
     scratchpad/seq-mismatch-spike.sps and preopen-spike.sps.

  2. userinfo vs host, and the `:` that is userinfo content before an `@` but the
     port delimiter after it. `@` occurs only as the userinfo terminator (it is
     in no host production), so the first `@` ends userinfo -- but a forward-only
     machine does not know an `@` is coming, so the leading authority run is
     userinfo-or-host undecided until the delimiter, exactly the leading-token
     shape, and there is no neutral authority span in the vocabulary.

SLICE ① COMPLETE (2026-09-18). The scanner for modes 1 & 2. Evidence: release
47/47 (was 43), no-scheme 11/11 (was 10). Decision 0018 records the `//`
compromise. Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3.

Landed: `src/uri/grammar.sls` (the source machine); `tools/emit-machine.ss` and
the committed `src/generated/uri-scanner.sls` (ABI 9, imports `(byte-machine
runtime)` alone, leads with `#!r6rs`); `make parser-refresh` + the determinism
lane over the committed artifact; the `on-rooted` verdict event in `(uri
vocabulary)`; and the decision-0007 src import-audit lane. The grammar opens
five spans -- scheme, host (the whole authority in this slice), path, query,
fragment -- dispatches the mode field at offset 0 (mode 0/3/other -> mode-unset,
mode 3 pinned until Slice ②), and raises scheme-required / scheme-forbidden /
mode-unset at the oracle's exact offsets.

JUDGED AGAINST AN INDEPENDENT ORACLE. `unit.grammar` (59 cases / 350 checks)
asserts the scanner's output -- spans, the `on-rooted` verdict, and error offsets
-- against decompositions a workflow derived from the ABNF, not from this
grammar. Every row matches, including the load-bearing distinctions
(`http:///p` empty host vs `http:/p` absent host; `http://a` empty path;
`http://a?` empty query), the `on-rooted` recovery of a path-absolute's dropped
slash, query/fragment content-transparency (a `?` and `/` stay inside them), and
chunk-invariance byte-at-a-time (using the COMPLETION callback for presence,
since an empty data fragment is suppressed across a feed boundary).
`determinism.generated-artifact` (26 cases) re-emits byte-identically, reads ABI
9 out of the committed text, and runs the ARTIFACT ITSELF against the interpreter
across the full oracle spread -- so a stale artifact, a hand-edit, or a
compile-vs-interpret divergence all redden.

MUTATION WITNESSES, each watched red then reverted: routing hier-slash1's
fallback past `on-rooted` (path-absolute recovery + determinism both red); a
`(chezscheme)` import and a stripped `#!r6rs` (the import audit both ways).

ADVERSARIAL REVIEW (subagent) before commit: no blockers; the grammar verifies,
emits byte-identically, matches the oracle on every input, and honours the
verifier rules. Five findings closed here: (1) the committed artifact lacked
`#!r6rs` -- the emitter now leads with it and the determinism lane prepends the
same prefix so they cannot drift; (2) decision 0007's src-purity lane did not
exist -- added and witnessed; (3) query/fragment content-transparency had no
oracle row, so a `frag-scan` that stopped on `?` would have survived -- two rows
added; (4) the grammar↔vocabulary cross-check ignored callback names -- now
asserted; (5) the determinism differential ran a narrower vector set than the
grammar oracle -- widened to the full spread.

FINDING FROM AUTHORING, benign: a mode-1 scheme with no colon that ends at EOF
(`foo`) flushes its open `scheme` span's data (`"foo"`) before the
`scheme-required` error, because `parser-finish!` delivers an open span's bytes
at the boundary; the byte-delimiter form (`foo/bar`) errors mid-feed with no
flush. Either way the error is what a consumer reads, and `(uri collect)` ignores
spans on an error, so the partial delivery is harmless -- recorded so the slice
that writes collect knows to expect it.

SCOPE CALL (provisional, pending the `//` research). Slice ① resolves ambiguity 1
and covers scheme / authority-as-one-host-span / path / query / fragment for
modes 1 & 2 -- which is correct wherever authority == host (no userinfo, no
port), is what the exit criterion needs (route on a path, read a raw query), and
carries the empty-vs-absent host distinction. The userinfo/host/port sub-split
(ambiguity 2) becomes Slice ①b, so all eight spans are split by the M2 merge
(decision 0008 item 2) without one slice carrying two open research problems.

AMBIGUITY 1 -- THE `//` RESEARCH CAME BACK WITH AN IMPOSSIBILITY PROOF, VERIFIED
HERE (2026-09-18). No clean structure exists, and it is provable from
byte-machine v0.6.0 source, not merely unfound: a span's mark is ALWAYS the
cursor at span-open and is only ever written to pos / 0 / the feed start
(runtime.sls:748,754,1022,1177,1370); the sole span primitives are start and end
(graph.sls:124) -- no cancel, no reset -- and re-opening is refused at verify
(verify.sls:1770-1777); the machine is forward-only (transition-and-cursor-
semantics §1). To read byte 2 you must `advance` past byte 1, and a sequence-
dispatch keeps its matched prefix on a mismatch (measured: `/x` -> path `x`,
the `/` gone). But `//x` needs byte 1's `/` in NO span (delimiter) while `/x`
(path-absolute) needs the SAME byte 1 `/` INSIDE the path span -- an
irrevocable, opposite fate decided before byte 2 is legible. QED.

THE COMPROMISE, MACHINE A ("authority-canonical"), verdict-spike.sps, run and
confirmed here. Two 1-byte dispatches, NO span across the leading `/`; the host
span carries authority presence byte-perfectly (fires iff `//`; EMPTY for
`///p`, non-empty for `//h`, never for path-absolute/rootless/empty); the path
span opens ON the post-authority `/` so it keeps that slash. Its ONE defect:
path-absolute's path span omits its own literal leading `/` (`/p` delivers span
`p`, not `/p`), because that byte was consumed with no span open and no mark
reaches back. Recovered OUT OF BAND: a zero-width `on-rooted` event (and,
redundantly, a `rooted` uint flag) fires EXACTLY in the path-absolute branch, so
`(uri collect)` prepends the `/` -- path component = `(if rooted "/" "") ++
span`. The pre-open alternative is strictly worse: it fires a phantom `//` path
fragment on ALL FIVE authority cases (path fires twice) -- also verified.

GOTCHA to obey when authoring: a byte edge (advance/reexecute) may NOT target a
`finish` terminal -- only an EOF transition may (verify.sls:1213-1214,
`non-eof-into-finish`). Reach finish through a dispatch's eof-target or a
zero-width span chain, never a byte edge.

THIS IS A DESIGN DECISION FOR THE MAINTAINER, NOT A SILENT BAKE-IN. `on-rooted`
is a verdict-style event on the public callback ABI, and decision 0008 item 4
set out to avoid sentinel events (though for PRESENCE, which the callback
sequence already carries; the dropped `/` is genuinely new information the
sequence cannot carry). Ambiguity 2 (userinfo/host/port) is the same family and
may want the same event/neutral-span pattern. Holding both for one consolidated
design checkpoint rather than interrupting twice.

REBALANCE (2026-09-18, decision 0019) -- the newest beat, after Slice ① merged
and the `@` research came back. Presenting ambiguity 2, the maintainer asked the
load-bearing question: is byte-machine the right kind of parser here at all,
given two forward-only impossibilities in the FIRST parsing slice? For the
structured parts, no. With the bytes in hand both splits are trivial (RFC 3986's
own Appendix B is one regex; the authority sub-split is find-`@`/find-`:`/slice);
what makes them hard is byte-machine's no-lookahead/no-rewind model, and a URI is
small and bounded, so the streaming thesis is thin. The real error was WHERE the
functional-core line was drawn. Chosen from three options ("rebalance to the
core"): the SCANNER splits the five coarse components (scheme, authority, path,
query, fragment) plus the mode-3 leading-token; userinfo/host/port and the whole
host grammar (the brief's feared 150-250-node IPv6) become pure CORE functions
over the `authority` field -- addable anytime with no scanner-ABI churn, which
also dissolves the breaking-change worry that drove 0008's eight-spans-at-M2.
A rebalance, not a replacement: byte-machine keeps the streaming coarse split.

LANDED: decision 0019; 0008 (span model) and the design (§3.1, §5, §6) amended
in place with pointers; the `host` span renamed `authority` and re-emitted;
`(uri vocabulary)` narrowed to SIX scanner spans, fifteen callbacks, four scanner
errors (`invalid-ip-literal` moves to the core with the host grammar); every
test updated. **Slice ①b (a scanner sub-split) is CANCELLED** -- the sub-split
is core work at M4/M5. `uri-components` needed no change (0008 item 7 already had
five fields with `authority` as one; the stack now agrees with it). Evidence:
release 47/47, no-scheme 11/11 (a rename + vocabulary narrowing, no lanes moved);
grammar 59/350, determinism 26, vocabulary 18/71, all green.

REVISED REMAINING PLAN: Slice ② -- mode 3 (the leading-token scanner + the
scheme/segment verdict events, decision 0004). Slice ③ -- `(uri collect)` -> the
five-field uri-components, the property/chunk-invariance lane, the §1.1.2
example-URIs parse-through. Then the merge gate. The authority sub-split and host
grammar are core milestones (M4/M5), no longer M2 scanner work.

SLICE ② COMPLETE (2026-09-18). Mode 3 (uri-reference). The scheme and the first
path segment share a prefix decided only by the delimiter, so the scanner opens
the neutral `leading-token` span, closes it at the delimiter, and fires a
zero-width verdict -- `on-scheme-confirmed` (a `:` closed it) or
`on-segment-confirmed` (a `/`/`?`/`#`/EOF did); the verdict comes AFTER the close
because the verifier refuses a callback reachable with a span open (fact 2). The
three routes converge on the shared continuation the other modes already use:
scheme-verdict rejoins at `eat-colon`/`hier` (mode-1-style), segment-verdict at
`path-open`, and a leading `/`/`?`/`#`/EOF is a relative reference with no leading
token that goes straight there. `(uri collect)` reads the verdict: the scheme is
the leading token, or the path is the leading token stitched onto the path span.

VALIDATED: `unit.grammar` now 83 cases / 549 checks, adding a twelve-row mode-3
group (both verdicts, the delimiter forms, the empty reference) and mode-3
chunk-invariance byte-at-a-time; the determinism differential runs eight mode-3
vectors through the committed artifact against the interpreter. The EOF-verdict
spike (design §9 item 1) is now exercised as a lane: `g` and `` reach
`eof-target -> span-end -> callback -> finish`, the shape the spike proved.

TWO MUTATION WITNESSES, and they land on OPPOSITE sides of the read-the-failure
rule. Rerouting the leading token's `:` to the segment close makes
`lt-close-scheme`/`say-scheme` unreachable, so the VERIFIER refuses it
(`unreachable-node`) -- a structural guarantee, not a test witness. Swapping
which event each verdict node fires keeps the machine verifiable and is caught
BEHAVIOURALLY: `g:h` reads verdict=segment, scheme=#f, path="gh", every one red.

Evidence: release 47/47, no-scheme 11/11 (no lanes added -- mode 3 grew the
existing grammar and determinism lanes); artifact 22620 -> 28766 bytes, ABI 9,
`make parser-refresh` idempotent. The scanner now splits all three modes into the
five coarse components; only `(uri collect)` and the property/example instrument
remain before the merge gate.

SLICE ③ COMPLETE (2026-09-18). `(uri collect)`, the imperative shell -- the last
of the design's five M2 libraries. It feeds bytes to the committed scanner,
COPIES each delivered fragment (valid only for the callback's dynamic extent),
and assembles the five-field `uri-components`, reading the out-of-band signals:
`on-rooted` prepends a path-absolute's dropped `/`, and the mode-3 verdict says
whether the leading token is the scheme or the first path segment (path =
leading-token stitched onto the path span). It offers a streaming interface
(make-uri-collector / uri-collect-feed! / uri-collect-finish!) with `uri-parse`
as a one-shot convenience. This meets the M2 exit criterion: chez-http-server can
route on `(uri-components-path ...)` and read `(uri-components-query ...)`.

VALIDATED: `unit.collect` (42 cases / 103 checks) judges the ASSEMBLY, the
scanner being judged in unit.grammar. It covers the components across modes 1/2/3
(verdict-based scheme and path stitching, the rooted slash), the absent-vs-empty
distinction carried into the fields, the errors surfacing with `#f` components,
chunk-invariance at the collect level (fed one byte at a time through the
streaming interface, so multi-fragment spans are exercised), and the §1.1.2
example URIs parsing through from the DERIVED corpus. The property lane the
design asks for is now covered three ways: scanner chunk-invariance (grammar),
collect chunk-invariance, and the committed-artifact differential (determinism).

ADVERSARIAL REVIEW: no code blockers -- the assembly is correct and honours every
decision, and a six-mutation battery confirmed the suite catches every assembly
bug. It found ONE test gap: the COPY discipline (design §2, 0018 item 4) shipped
green even with the copy removed, because feeding slices of one immutable buffer
never distinguishes a copy from a retained reference. Closed with a buffer-REUSE
case that refills the same buffer between feeds; witnessed cleanly by a
deferred-slice mutation that fails ONLY that case while the other 41 pass. Two
nits also closed (an empty-fragment pair; the scheme-required error's offset and
absent components; the bad-mode raise). Evidence: release 49/49, no-scheme 11/11.

M2 SHIPPED (pending the merge gate). The generic split: five libraries -- `(uri
vocabulary)`, `(uri grammar)`, the committed `(generated uri-scanner)` (ABI 9),
`(uri components)`, `(uri collect)`. The byte-machine submodule pinned at v0.6.0
with the emitter, the two ABI lanes and the determinism lane. The scanner splits
scheme / authority / path / query / fragment (+ the mode-3 leading token) for all
three modes, delimiter-only, judged against an ABNF-derived oracle; collect
assembles the five-field components. Two forced design decisions along the way:
0018 (`on-rooted` recovers a path-absolute's slash) and 0019 (the rebalance --
the scanner does the coarse split, the core owns the authority sub-split and the
host grammar). The §5.4 resolution ratchet does NOT move here -- it is M6's
(decision 0011). NEXT: the merge gate, then the closing ritual (ask first).
