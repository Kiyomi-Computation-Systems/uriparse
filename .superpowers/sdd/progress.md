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
(decision 0011).

M2 ULTRA REVIEW (2026-09-18, at the merge gate). A six-dimension multi-agent
adversarial pass -- scanner, collect+components, decision fidelity, test quality,
byte-machine ABI/emitter, build/lanes -- each non-nit finding then VERIFIED by an
adversary re-running the code. Nine findings raised; **no code defects**. The
scanner, collect, ABI and build dimensions surfaced no real code bug (a claimed
fingerprint-manifest over-claim was refuted on verification). Two should-fix,
both DECISION-RECORD / COMMENT fidelity, plus worthwhile nits, all closed here:

  - 0009 now carries an in-place amendment note (its item 6 still listed
    invalid-ip-literal as a scanner error; 0019 moved it to the core) -- matching
    how 0008 was amended, so a reader of 0009 is no longer misled on the scanner's
    v0.1 error vocabulary.
  - grammar.sls no longer files invalid-ip-literal to the cancelled Slice ①b (it
    is the core's, 0019 item 5); its callbacks comment now says six spans / three
    verdict events, not five / one.
  - vocabulary-tests comments corrected (six / 15, not eight / 18); the
    determinism import-hygiene check now names all four forbidden upstream
    libraries (verify and interpret were missing); the top-level CMakeLists NOTE
    that claimed there is no emitter is rewritten.
  - A real coverage gap closed: an empty authority was pinned only when a `/`
    followed (`http:///p`); it is now pinned at EOF and before `?`/`#` too
    (`http://`, `//`, `http://?q`, `http://#f`) in the grammar and collect suites
    -- the review verified the code already handled these; the tests were silent.

Evidence after fixes: grammar 84/553, collect 42/105, determinism 34/38, release
49/49, no-scheme 11/11; committed artifact unchanged (comments are not emitted).
The review found the CODE sound to merge; only records and tests needed touch-ups.

M2 CLOSED (2026-09-18). PR #2 squash-merged to main as 798a60b; local main
fast-forwarded; feat/m2-generic-split deleted local and remote. Merged on a RED
linux-amd64 check, named as the documented Actions billing refusal (a 0-step,
~3s run) per decision 0017, NOT a test result -- the local evidence stands in
its place (release 49/49, no-scheme 11/11). The maintainer authorised the
closing ritual explicitly.

REFLECTION. M2 turned an empty src/ into a working splitter and met its exit
criterion: chez-http-server can route on the path and read the raw query. Two
moves shaped the milestone. First, the byte-machine fit question (raised by the
maintainer mid-build) forced decision 0019, the rebalance -- the most
consequential move here: it kept the forward-only, no-backtracking scanner
honest by handing the authority sub-split and the host grammar to the pure
core, where M4's IPv6 becomes a small function rather than a fight with the
machine. Second, both adversarial passes earned their keep on the SAME failure
mode -- a test green for the wrong reason. The per-slice review caught the copy
discipline shipping green with the copy removed (slices of one immutable buffer
never tell a copy from a retained reference); the ultra review caught an
empty-authority gap pinned only before `/`, and decision/comment drift after
0019 -- no code defects, but each would have misled the next reader. The
oracle-from-ABNF discipline held throughout: grammar and test never shared a bug.

NEXT (M3+). The scanner/core seam is set and the core owns the authority, so
M4 adds the host grammar (userinfo/host/port, IPv6) as pure functions over the
authority bytevector with no scanner change; the §5.4 resolution ratchet is
M6's (0011). No M2 debt carried forward -- the tree is clean on main at 798a60b.

---

M5 — THE PURE CORE: PERCENT CODING AND NORMALIZATION. Branch
feat/m5-percent-normalization.

Plan: .plans/2026-09-18-chez-uri-design.md §5 (the core; decision 0010,
bytevectors throughout), §6 (v0.1 is resolution-first). Brief:
.plans/2026-09-18-chez-uri-project-brief.md "M5 — the core: percent coding and
normalization". Decisions in force: 0007 (pure R6RS src), 0008 (absent ≠ empty),
0010 (bytevectors throughout; `(rnrs unicode)` is structurally unreachable
because its case fold is length-changing and Unicode — KELVIN SIGN → ASCII k),
0011 (v0.1 is resolution-first AND a splitter with a complete core, NOT a
validator: it accepts bytes the ABNF rejects, e.g. `%ZZ`).

WHY M5 AND NOT M3. The user chose M5 at the milestone gate: decision 0011
reorders v0.1 to M1 → M2 → M5 → M6 → M7, deferring M3 (charset) and M4 (host)
to v0.2, because §5.4 is the only normative corpus and resolution rides it.

Base at start: 87aff01 (local main == origin/main; M2 merged as 798a60b, its
close-out 87aff01). Measured environment (2026-09-18, Darwin arm64): Chez 10.4.1
(tarm64osx), CMake/CTest 4.3.3. Baseline on the branch before any slice: release
49/49, no-scheme 11/11.

WHAT M5 SHIPS (design §5 library table): two pure-core libraries — `(uri
percent)` (percent decode/encode over bytevectors) and `(uri normalize)` (§6
syntax-based normalization, with the hand-written ASCII fold 0010 requires).
Both are total functions over bytevectors and `uri-components`; each is callable
with a literal and compared to a constant. No scanner, no byte-machine, no
emitter — M5 touches none of the M2 machinery, it operates on the components M2
produces.

SCOPE, AND WHAT v0.1 NORMALIZATION DOES NOT DO (decision 0020, written in Slice
①): v0.1 applies §6.2.2.1 case normalization (the SCHEME → lowercase, and the
hex digits of every valid `%XX` → uppercase) and §6.2.2.2 percent-encoding
normalization (decode `%XX` whose octet is unreserved). It does NOT normalize
HOST case — that
needs the host isolated within the authority, and userinfo is case-sensitive; the
host split is M4/v0.2. It does NOT remove dot-segments (§6.2.2.3 = §5.2.4 = M6).
It does NOT do scheme-based normalization (§6.2.3: default ports, empty-path→"/")
— scheme-specific, out of scope (brief "out of scope"). This keeps 0011's
promise: v0.1 has a complete core, not a validator.

EXIT CRITERION: the pure core can percent-decode/encode a bytevector and
syntax-normalize a `uri-components` per the in-scope §6 rules, tested against an
RFC-3986-derived oracle (the §6.2.2 worked example and a per-rule vector table).
This does NOT move the §5.4 resolution ratchet — that is gated at M6 (0011).

SLICE PLAN (cadence: drive to gates — stop after Slice ⓪ and at the merge gate;
subagents for the RFC-derived normalization oracle and per-slice adversarial
review):

  ⓪  `(uri percent)` — the mechanics. `pct-decode` (decode every valid `%XX`;
     leave a malformed `%` byte-for-byte, per 0011's non-validating stance),
     `pct-encode` (encode by a caller-supplied `safe?` predicate, UPPERCASE hex),
     `unreserved-byte?` (§2.3), and the hex helpers `(uri normalize)` will reuse.
     Pure `(rnrs)`; source+aot lane; TDD with mutation witnesses. — GATE.
  ①  `(uri normalize)` — the §6 policy + decision 0020. The hand-written ASCII
     scheme fold, `pct-normalize` (§6.2.2.1 hex-casing + §6.2.2.2 unreserved
     decode), `normalize-components` (scheme→lowercase; percent-normalize the
     components that carry pct-encoding; host-case DEFERRED). Judged against the
     RFC-derived oracle. Mutation witnesses.
  CLOSE — merge gate + closing ritual (ask first) + reflection.

SLICE ⓪ OPEN (2026-09-18): ledger seeded; branch cut from 87aff01; the RFC
§6.2.2 normalization oracle survey commissioned — derived from RFC 3986
independently of the implementation, so `(uri normalize)`'s tests are graded
against the RFC, not against my own code (the M2 oracle discipline, restated for
a milestone whose §5.4 corpus does not reach it).

SLICE ⓪ COMPLETE (2026-09-18). Landed: `(uri percent)` — the percent mechanics —
and its source+aot lane. Evidence: release 51/51 (was 49), no-scheme 11/11.
Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3.

`(uri percent)` (21 cases / 169 checks) is `pct-decode` (decode every valid
`%XX`, case-insensitive hex in; a malformed `%` left byte-for-byte — total, per
0011's non-validating stance), `pct-encode` (copy the bytes a caller's `safe?`
predicate keeps, escape the rest as `%` + UPPERCASE hex, §2.1), `unreserved-byte?`
(§2.3 exactly: ALPHA / DIGIT / - . _ ~, and `+` is NOT a mark), and the two hex
primitives `hex-digit-value` / `nibble->hex-digit` that `(uri normalize)` reuses
so the §6 policy does not re-derive the hex. Pure `(rnrs)`, bytevectors
throughout (0010); the import-audit (a no-scheme lane) confirms `#!r6rs` and no
`(chezscheme)`.

VALIDATED: seven mutation witnesses, each watched red then reverted — the §2.3
set (a stray `+` admitted), hex-input case-insensitivity (the a-f clause
dropped), uppercase output (`nibble->hex-digit` lowercased), decode totality (a
malformed `%` dropped instead of emitted), decode octet assembly (`16·hi+lo` →
`hi+lo`), the encode predicate (ignored, everything left literal), and the range
boundary (UP-A lowered by one to admit `@`). The last was added AFTER the review
flagged it: the non-hex cases pinned only the far side of each hex range, so a
widened lower bound would have slipped.

ADVERSARIAL REVIEW (subagent, at the slice gate): no code defects. It traced the
decode index guard `(fx<? (fx+ i 2) n)` at every tail position (`%` at
n-1 / n-2 / n-3) and found it exactly right, confirmed `pct-encode` correct
across all 256 octets, that nothing raises (totality holds), and that
`unreserved-byte?` is exactly §2.3. Four nits, all closed here: the round-trip
comment oversold a necessary-not-sufficient property (reworded to say so);
`%3A == %3a` pinned neither side to the octet (both now pinned to 0x3A); the
hex-boundary coverage gap (closed and witnessed, above); and the four §2.3 marks
were magic numbers against the file's own naming convention (now
HYPHEN / DOT / UNDERSCORE / TILDE). Its one un-realizable doubt — fixnum overflow
on a bytevector whose length sits within 3 of most-positive-fixnum — cannot occur
on the 64-bit shipping cells and cannot be constructed on 32-bit (a ~500 MB
bytevector cannot coexist with a length that near the ceiling).

SLICE ⓪ GATE (2026-09-18): stopped for maintainer review; approved to proceed
into Slice ① with the host-case deferral documented.

SLICE ① COMPLETE (2026-09-18). Landed: `(uri normalize)` — RFC 3986 §6.2.2
syntax-based normalization over the five-field components — plus decision 0020,
and its source+aot lane. Evidence: release 53/53 (was 51), no-scheme 11/11.
Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3.

`(uri normalize)` (26 cases / 82 checks) is `normalize-scheme` (the §6.2.2.1a
ASCII lowercase fold, hand-written so `(rnrs unicode)` is never reached — 0010),
`pct-normalize` (§6.2.2.1b hex-uppercasing + §6.2.2.2 unreserved-decoding,
single-pass per §2.4, a malformed `%` left byte-for-byte), and
`normalize-components` (scheme case-folded; authority/path/query/fragment
percent-normalized; authority CASE left alone — host-case is M4/v0.2; absent and
empty preserved per field). It imports `(uri percent)` and `(uri components)` and
re-uses percent's hex primitives. Decision 0020 records the scope and both
deferrals (host-case → M4; dot-segments → M6); README.org and CHANGELOG.md now
state it so the deliverable does not over-claim RFC compliance. (The single-pass
finding also added a case to `(uri percent)`, now 22/170.)

VALIDATED: ten mutation witnesses across `(uri normalize)`, each watched red then
reverted — the scheme fold; decode-iff-unreserved, in BOTH directions (over- and
under-decoding); hex-uppercasing on kept triples; malformed totality; the
host-case deferral being ENFORCED (lowercasing the authority reddens); the
absent-scheme guard; empty-preservation per field; and — decision 0010 item 5's
named obligation — the U+212A KELVIN SIGN differential watched FAILING against a
`string-downcase` fold, which folds it to ASCII `k` (`#vu8(107)`).

ADVERSARIAL REVIEWS. The per-slice `(uri normalize)` review found no code defect;
its two coverage gaps (the absent-scheme guard, empty-preservation per field) and
nits were closed and witnessed here. A merge-gate multi-agent verification then
ran five dimensions — integration, decision-fidelity, oracle-coverage,
build-lanes, completeness — each finding adversarially adjudicated. Integration,
oracle-coverage and build-lanes came back CLEAN; no code defect anywhere. Five
confirmed findings, all closed here:
  - a forward HAZARD worth recording (should-fix): M5's §6.2.2.2 decoding turns
    `%2E` into a literal `.`, so `pct-normalize` MANUFACTURES dot-segments
    (`/a/%2E%2E/b` → `/a/../b`). M5 does not remove them but it creates them, so
    the M5→M6 order is load-bearing and security-relevant — M6 must resolve a
    NORMALIZED path or encoded traversal survives. Recorded in 0020, pinned by a
    test, and noted in `pct-normalize`'s docstring.
  - the single-pass §2.4 invariant (`%2541`) was unpinned: docstrings + tests
    added in both libraries.
  - the U+212A witness 0010 item 5 names was not landed: added and witnessed.
  - two ledger nits: the §6.2.2.2-vs-§6.2.2.1b attribution (fixed) and the stale
    Slice ① record (this close-out).
  One finding was REFUTED on adjudication — a redundant `%40`/`%3A`-in-authority
  coverage request; the reserved-octet gate is already pinned by `%3A stays`.

M5 CLOSED (pending the merge gate). The pure core now percent-codes and
normalizes: `(uri percent)` (decode/encode + the §2.3 set + hex primitives) and
`(uri normalize)` (§6.2.2 scheme-case + percent-normalization). Both are total
functions over bytevectors (0010), graded against an RFC-3986-derived oracle
independent of the code, each decision watched failing. v0.1 is a splitter with a
complete-enough core, not a validator, and it says so (0011, 0020). The §5.4
resolution ratchet does not move here — that is M6's (0011).

M5 MERGED (2026-09-18). PR #3 squash-merged to main as 8f94515; local main
fast-forwarded; feat/m5-percent-normalization deleted local and remote. Merged on
a RED linux-amd64 check, named as the documented Actions billing refusal (decision
0017), not a test result — local evidence stands in its place (release 53/53,
no-scheme 11/11). The maintainer authorised the closing ritual explicitly.

REFLECTION. M5 was a pure-core milestone with a different risk profile from M2:
no scanner, no byte-machine, no scaffolding — the risk was SCOPE correctness, and
the milestone's shape was decided by what v0.1 can honestly do. Three things
stand out. First, the maintainer's own question — "was deferring M3/M4 right,
considering normalization?" — sharpened the scope: M3 (charset) is orthogonal to
normalization, and only M4 (host) touches it, costing exactly ONE of §6.2.2's
three transforms (host case), which is off the consumer's critical path, safer
omitted than faked, and cleanly recoverable at M4. Decision 0020 records that.
Second, the oracle-from-RFC discipline held again: the normalizer was graded
against §6.2.2 derived independently of the code. Third — the milestone's most
valuable catch — the merge-gate verification surfaced the M5→M6 ordering hazard:
`pct-normalize` decodes `%2E` to a literal `.`, so M5 MANUFACTURES dot-segments,
making normalize-before-resolve a security-relevant invariant. It was invisible
to both per-slice reviews (each saw one library); only the cross-cutting
completeness dimension found it. It is now in 0020, pinned by a test, and in the
docstring, so M6's author cannot miss it.

NEXT (M6). Reference resolution (§5.2), gated on the §5.4 corpus at 100% (0011).
It consumes NORMALIZED components (0020's ordering note) and adds `(uri path)`
(§5.2.4 remove_dot_segments, §5.2.3 merge) and `(uri resolve)` (§5.2.2). No M5
debt carried forward — the tree is clean on main at 8f94515.

---

M6 — DOT SEGMENTS AND REFERENCE RESOLUTION. Branch feat/m6-resolution.

Plan: .plans/2026-09-18-chez-uri-design.md §5 (the core library table: `(uri
path)` M6, `(uri resolve)` M6, `(uri recompose)` M7 — pulled to M6, see decision
0021), §2 (the layer split), §3.2 (absent ≠ empty, which §5.2.2/§5.3 branch on).
Brief: .plans/2026-09-18-chez-uri-project-brief.md "M6 — dot segments and
reference resolution". Decisions in force: 0005 (RFC 3986's own vectors are the
anchor; §5.4 is the only normative corpus), 0007 (pure R6RS src), 0008 (absent ≠
empty — §5.2.2 and §5.3 branch on *defined*, not nonempty), 0010 (bytevectors
throughout), 0011 item 3 (M6 is gated on all 42 §5.4 rows passing, 100% or not
done), 0015 (erratum 4547 rejected — `../../../g` and `../../../../g` resolve to
`http://a/g` as published, NOT `http://a/../g`), 0020 (M6 consumes NORMALIZED
components; the M5→M6 dot-segment ordering hazard — `pct-normalize` decodes
`%2E`→`.`, so a resolver must run over a normalized path or encoded traversal
survives), and NEW 0021 (recompose lands at M6).

Base at start: 07842f5 (local main == origin/main; M5 merged as 8f94515, its
close-out 07842f5). Measured environment (2026-09-18, Darwin arm64): Chez 10.4.1
(tarm64osx), CMake/CTest 4.3.3. Baseline on the branch before any slice: release
53/53, no-scheme 11/11.

WHAT M6 SHIPS (design §5 library table): three pure-core libraries — `(uri path)`
(§5.2.4 `remove_dot_segments` + §5.2.3 `merge`, over path bytevectors), `(uri
resolve)` (§5.2.2 strict `transform-references`, over `uri-components`), and `(uri
recompose)` (§5.3 component recomposition, `uri-components` → bytevector). All
total functions over bytevectors and components (0010), each callable with a
literal and compared to a constant. No scanner, no byte-machine — M6 operates on
the components `(uri collect)` produces.

DECISION 0021 (recompose at M6, written at milestone seed). The brief pencils
§5.3 recompose at M7, but two facts force it into M6: (1) §5.2.2's OWN pseudocode
ends "return T" by recomposing per §5.3 — resolution's output is a string; (2)
M1's comparator `compare-target` is string-in / string-out, so the §5.4 lane
needs a resolved *string* per row. The alternative — reparse the expected target
into components and compare component-wise — would put M2's parser into the
oracle path (a resolve bug and a parse bug could cancel) and relitigate the RFC's
string oracle through my own code. So M6 recomposes the resolved components and
compares BYTE-EXACT to the published §5.4 target, keeping the corpus a pure
string oracle. §5.3 recompose lands here; M7 keeps the round-trip PROPERTY
(parse→normalize→recompose→parse fixed point over generated corpora) and any
recompose hardening. This is the M6 analog of 0020, recorded before Slice ⓪.

SCOPE, and what M6 does NOT do: no charset validation (M3/v0.2); no host grammar
(M4/v0.2). Resolution operates on the coarse five-field components M2 splits,
treating the path as opaque bytes — segmentation is a total function of the path
bytes (design §3.1) done inside `(uri path)`, not a scanner span. Resolution
itself does NOT normalize (§6 is a separate operation); the §5.4 corpus is pure
resolution with no normalization applied, and decision 0015 keeps the two
excess-dot-segment rows as published. The normalize-before-resolve composition
(0020's ordering note) is a PUBLIC-API property — documented in `(uri resolve)`
and recorded — not something the raw §5.4 rows exercise.

EXIT CRITERION: all 42 §5.4 rows resolve correctly (100% or not done, 0011 item
3); `remove_dot_segments` reproduces both committed §5.2.4 step traces; `merge`
and `recompose` graded against RFC-derived vectors. The two-way ratchet
(test/conformance/ratchet.txt) flips not-yet→passing for all 42 and NOTHING else
moves — a not-yet that passes is as much a violation as a passing that fails.

SLICE PLAN (cadence: drive to gates — stop after Slice ⓪ and at the merge gate;
subagents for the RFC-derived resolution oracle and per-slice adversarial
review):

  ⓪  `(uri path)` — the mechanics. `remove-dot-segments` (§5.2.4, the 2A–2E
     loop, popping previously-emitted segments) graded against the committed
     13-row step traces (dot-segments.scm); `merge` (§5.2.3, the two branches
     with the rightmost-`/` semantics and the authority+empty-path case) graded
     against RFC-derived vectors. Pure `(rnrs)` over bytevectors; source+aot
     lane; TDD with mutation witnesses. — GATE.
  ①  `(uri resolve)` (§5.2.2 strict transform-references over components) + `(uri
     recompose)` (§5.3, defined-guarded emission) + decision 0021; the §5.4
     resolution lane — parse base + reference via `(uri collect)`, resolve,
     recompose, compare byte-exact against the 42 published targets; ratchet.txt
     flipped not-yet→passing. Judged against the normative corpus. Mutation
     witnesses. — merge gate.
  CLOSE — merge gate + closing ritual (ask first) + reflection.

SLICE ⓪ OPEN (2026-09-18): ledger seeded; branch cut from 07842f5; the RFC
§5.2/§5.3 resolution oracle survey commissioned (derive-then-refute over the
vendored text test/vendor/rfc3986.txt, each derivation cross-checked against the
committed §5.4 and §5.2.4 corpora), so `(uri path)` / `(uri resolve)` / `(uri
recompose)` are graded against the RFC independently of the code — the M2/M5
oracle discipline, restated for the one milestone whose corpus IS normative.

THE ORACLE SURVEY CAME BACK, ALL FOUR SECTIONS CONFIRMED (2026-09-18). A
derive-then-refute workflow (8 agents: one deriver + one adversary per section,
grounded in the vendored RFC and cross-checked against the committed corpora)
returned §5.2.4, §5.2.3, §5.2.2 and §5.3 each with verdict **confirmed**, zero
disputes, zero corrected vectors. The §5.2.4 case table (A→B→C→D→E, the
"complete path segment" qualifier on 2B/2C, 2C's tolerance of an empty output
buffer, 2A-vs-2D) and the §5.2.3 two-branch merge (rightmost-`/` kept, the
authority+empty-path branch (a), the no-slash edge) both matched the
implementation as authored. Its derived stress and merge vectors are the Slice ⓪
oracle beyond the committed traces; its §5.2.2 hand-traces and §5.3 recompose
vectors are held for Slice ①. Saved to scratchpad/m6-oracle.txt.

SLICE ⓪ COMPLETE (2026-09-18). Landed: `(uri path)` — `remove-dot-segments`
(§5.2.4), `remove-dot-segments-trace` (the same run as a per-step trace), and
`merge` (§5.2.3) — plus its source+aot lane. Evidence: release 55/55 (was 53),
no-scheme 11/11. Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3.

`(uri path)` (12 cases / 66 checks) is two pure `(rnrs)` functions over path
bytevectors (decision 0010) — no scanner, no components (design §3.1): `/` is not
in `pchar`, so segmentation is a total function of the path bytes and lives in
the core. `remove-dot-segments` runs §5.2.4's two-buffer loop; the "/./"→"/" and
"/../"→"/" rewrites are a 2- and 3-byte drop (the prefix's trailing `/` becomes
the result's leading one), 2C pops the output's last segment (tolerating an empty
buffer per the RFC's "(if any)"), and the "complete path segment" qualifier is
enforced by matching `/.`/`/..` only as the whole input. `merge` is §5.2.3's two
branches: authority+empty-base-path → `/`++ref, else the base up to and including
its rightmost `/` (or "" with no `/`) ++ ref. Both are TOTAL (decision 0011): no
input raises, and every branch strictly shrinks the input so the loop terminates.

VALIDATED TWO WAYS (decision 0005 discipline). `remove-dot-segments` is graded
step-for-step against the committed §5.2.4 corpus (dot-segments.scm): the test
reads each trace's path from the corpus's own step-1 row, runs
`remove-dot-segments-trace`, and asserts every `(label output input)` triple
equals the corpus row — so a wrong algorithm that reaches the right end result by
the wrong 2A/2B/2C/2D/2E sequence still reddens (the RFC gives these as traces,
not just end results, exactly for this reason). Its result is separately pinned
on six RFC-derived stress vectors that press distinctions the two traces do not
reach (`/../`, `/.`, `..`, `/.foo`, `../g`, `..g`). `merge` is pinned on the six
RFC-derived branch vectors (both branches, the empty-base authority case, the
no-slash edge).

NINE MUTATION WITNESSES, each watched red then reverted: 2C's output pop dropped
(both traces + `/a/..` red); 2B's complete-segment qualifier loosened to a prefix
(`/.foo` red); 2C's likewise (`/..bar` red); 2A's `./` drop shortened to one byte
(`./g`→`/g`); 2D's whole-input match loosened to a prefix (`..g`→empty); a 2B step
MISLABELLED 2E (trace step-label check red — proving the trace grades labels, not
only buffers); merge branch (a) skipped (`http://a`+`g`→`g` not `/g`); merge's
rightmost-`/` dropped (`/b/c/`→`/b/c`, every branch-(b) merge corrupted); merge's
no-slash edge appending the base (`mid`+`g`→`midg`).

ADVERSARIAL REVIEW (subagent, at the slice gate): no code defects. It traced the
implementation against §5.2.4/§5.2.3, the committed corpus and the RFC-derived
oracle, and confirmed totality (no input raises; every branch strictly shrinks
the input, so the loop terminates — including on high bytes and a NUL). One
should-fix and two nits, all TEST coverage, closed here and re-witnessed:
  - should-fix: the trace grades step LABELS, but the two committed traces only
    fire "1"/"2E"/"2B"/"2C" — 2A and 2D labels were unpinned, so a mislabel of
    those cases would survive. Closed with label-sequence checks over BOTH
    spellings of each (`../g` and `./g` for 2A; `.` and `..` for 2D); the first
    fix caught only `../` and was itself witnessed incomplete when a mislabel of
    the `./` branch survived, then widened until mislabelling EITHER 2A branch
    reddens.
  - nit: `merge` with a defined authority over a slashless NON-empty base path
    (branch (b), authority irrelevant) had no test — added (`mid`+`g`→`g`).
  - nit: totality on non-ASCII/NUL bytes was verified by inspection but unpinned
    — added (`/<NUL>/..`→`/`, and a 0xFF-led segment moved verbatim).
Evidence after fixes: 14 cases / 73 checks; release 55/55, no-scheme 11/11.

SLICE ⓪ GATE (2026-09-18): decision 0021 (recompose lands at M6) presented and
APPROVED by the maintainer ("Yes, 0021 sits right — proceed into Slice ①").

SLICE ① COMPLETE (2026-09-18). Landed: `(uri resolve)` (§5.2.2 strict) and `(uri
recompose)` (§5.3), the §5.4 conformance lane, and the ratchet flipped
not-yet→passing for all 42. **THE M6 GATE IS MET: all 42 §5.4 rows resolve to
their published targets.** Evidence: release 61/61 (was 55), no-scheme 11/11.
Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3.

`(uri recompose)` (10 cases / 13 checks) is §5.3, guarded on DEFINED not nonempty
(decision 0008): an empty-but-present authority still emits `//`, an
empty-but-present query still emits `?`, the path is emitted unconditionally, and
an ABSENT authority (`#f`) suppresses the `//` — the `http:g` vs `http://g` flip.
Pure over `(uri components)`. `(uri resolve)` is §5.2.2's pseudocode arm for arm,
STRICT (the non-strict `undefine(R.scheme)` shortcut is never taken, so `http:g`
→ `http:g` not `http://a/b/c/g` — decision 0015/0001; the corpus's `(note ...)`
records the loophole and this implements the strict row). It imports `(uri path)`
for merge + remove-dot-segments and is pure over components; resolution does NOT
normalize (§6 is separate), and the normalize-before-resolve ordering (0020/0021)
is documented on the library as a caller obligation, not baked in.

THE §5.4 GATE, END TO END (decision 0021's recompose-and-compare-strings).
`conformance.resolution` (45 cases / 92 checks) drives the whole stack per row:
`(uri collect)` parses the base (mode `uri`) and the reference (mode
`uri-reference`), `(uri resolve)` transforms, `(uri recompose)` renders, and the
bytes are compared BYTE-EXACT to the RFC's published target via `compare-target`
— so the corpus stays a pure string oracle, no parser in the grading path for the
expected value. A base-sanity case pins that `http://a/b/c/d;p?q` splits as §5.4
assumes (else 42 rows would redden as one resolver bug). The two-way ratchet is
enforced IN the lane: `ratchet-violations` must be empty over all 42 marked
`passing`, so a regression AND an unrecorded pass both fail. `(uri resolve)` is
ALSO judged in isolation — `unit.resolve` (12 cases) checks the §5.2.2 branch
tree at the COMPONENT level against the RFC-derived hand-traces (so a resolve bug
cannot hide behind a parse or recompose bug), pinning the absent/empty
distinctions the corpus does not reach: an empty-but-present R.query is taken
(not the base's), an empty-but-present R.authority is taken.

NINE MUTATION WITNESSES, each watched red then reverted. Recompose: empty
authority no longer emitting `//` (`http://`→`http:`); empty query no longer
emitting `?`; the scheme's `:` dropped (43 conformance rows red — every
scheme-bearing target). Resolve: the empty-path branch ignoring a defined R.query
(`?y` takes base's `q`); a relative path treated as rooted so it skips merge
(`g`→`http://ag`); the merged path not dot-segment-removed (`../../g`→
`http://a/b/c/../../g`); the relative branch dropping the base authority
(`g`→`http:/b/c/g`); the scheme branch merging its path (strict broken:
`http:g`→`http:/b/c/g`). Ratchet: a row flipped back to not-yet while it passes —
the conformance lane reddens with "recorded not-yet, but it passed", proving the
two-way gate is live in the lane, not only in unit.corpus.

DECISION 0021, README.org and CHANGELOG.md all landed with this slice: the
milestone status is refreshed to "M6 — reference resolution, and the §5.4 corpus
at 100%", the strict-resolution and normalize-before-resolve caveats are stated
so the deliverable does not over-claim, and the ratchet.txt header note now
records that M6 flipped the rows (the two-way gate keeps it from drifting).

M6 MERGE-GATE VERIFICATION (2026-09-18, at the merge gate). A five-dimension
multi-agent adversarial pass — resolution-correctness, oracle-non-vacuity,
decision-fidelity, build-lanes, completeness — each finding adversarially
adjudicated (find → re-verify against the RFC/code/corpus). No code DEFECT: the
resolution algorithm was re-derived arm for arm and matched, and totality holds.
The valuable catch was a coverage theme invisible to the per-slice reviews (each
saw one library): the resolve unit tests all used the §5.4 base (non-empty path,
dot-free scheme/authority refs), so THREE resolve paths were unobserved and each
could be DELETED with every lane staying green —

  - remove-dot-segments in §5.2.2 branch A (a scheme-bearing ref's path),
  - remove-dot-segments in branch B (a network-path ref's path),
  - the base-authority flag resolve threads into merge (branch (a) wiring).

All three closed with component-level resolve cases (`g:a/b/../c`→`g:a/c`;
`//g/a/../b`→`http://g/b`; `http://a`+`g`→`http://a/g`) and each witnessed red by
deleting exactly that call. Also closed: branch C keeps Base.path RAW (a nit case
added); the design §5 library table still filed `(uri recompose)` under M7 —
amended in place to M6 with a 0021 pointer (matching how 0008/0019 were amended);
recompose's "emitted unconditionally" docstring reconciled with its `#f`-tolerant
guard, noting the resolve/recompose totality asymmetry; a resolve path
precondition documented. And — the security-relevant one — the normalize-before-
resolve property (0020/0021) was asserted but UNPINNED: added a live
composition check that `/a/%2E%2E/b` normalized-then-resolved collapses to `/b`
(the encoded `../` applied) while resolved RAW stays `/a/%2E%2E/b` (inert). That
closes the loop the M5 merge-gate opened — M5 pinned the normalize half, this
pins the resolve half. Two nits left deliberately: the ratchet header's informal
"deferred" (the file's established word for the not-yet token throughout) and the
conformance lane's `unit` label (consistent with the M1 `uri.unit.corpus` lane
and required for preset selection). Two findings were review artifacts, not
defects — a finder saw source files change mid-review because the mutation
witnesses were running; the tree is quiescent and correct.

Evidence after fixes: unit.resolve 16 cases / 16 checks (was 12/12),
conformance.resolution 47 cases / 94 checks (was 45/92); release 61/61, no-scheme
11/11. The §5.4 gate still stands at 42/42. The review found the CODE sound to
merge; the fixes were coverage, one record, and doc reconciliation.

M6 MERGED (2026-09-18). PR #4 squash-merged to main as b0939d8; local main
fast-forwarded; feat/m6-resolution deleted local and remote. Merged on a RED
linux-amd64 check, confirmed as the documented Actions billing refusal (decision
0017 — a completed/failure run at 3.0s, the 0-step shape M2 and M5 also merged
over), not a test result — local evidence stands in its place (release 61/61,
no-scheme 11/11, §5.4 42/42). The maintainer authorised the closing ritual
explicitly.

REFLECTION. M6 was the milestone with a real normative corpus, and it reached
"all of §5.4 or not done" (decision 0011): 42/42. Three things shaped it. First,
the recompose-at-M6 boundary (decision 0021): §5.2.2 ends by recomposing per
§5.3, and M1's comparator is string-in/string-out, so recompose HAD to ship with
resolve — and choosing recompose-and-compare-strings over reparse-the-target kept
the §5.4 corpus a pure string oracle instead of relitigating the RFC's strings
through this project's own parser. Second, the oracle-from-RFC discipline held
one more time and paid off: a derive-then-refute survey confirmed §5.2.2/§5.2.3/
§5.2.4/§5.3 (zero disputes) BEFORE a line was graded, and remove-dot-segments was
checked step-for-step against the RFC's worked traces, not just their end
results. Third — the milestone's most valuable catch — the merge-gate
verification found a coverage theme the per-slice reviews structurally could not:
because every resolve test used the §5.4 base (non-empty path, dot-free
scheme/authority refs), THREE resolve paths were unobserved and deletable while
every lane stayed green (remove-dot-segments in §5.2.2 branches A and B, the
merge authority-flag wiring). Same failure family as M2's copy-discipline and
M5's empty-authority gap: a test green for the wrong reason, invisible until a
cross-cutting dimension looked. All three are now pinned and witnessed, and the
normalize-before-resolve security property was pinned end to end, closing the
loop M5's merge-gate opened. The pattern across M2/M5/M6 is settled: the
per-slice review catches within-library bugs, the merge-gate verification catches
the coverage a single library cannot see.

NEXT (M7 — the round-trip property). Decision 0021 already moved §5.3 recompose
into M6, so M7 is NOT recompose-from-scratch — it is the ROUND-TRIP PROPERTY the
brief names: parse -> normalize (§6) -> recompose (§5.3) -> parse reaches a fixed
point, and the second parse's spans equal the first's. It rides the existing
`(uri recompose)` and the generated/example corpora (design §7, decision 0012's
abnfgen if it exists yet; §1.1.2 example URIs otherwise), and it is the last
implementation milestone before M8 (release v0.1). No M6 debt carried forward —
the tree is clean on main at b0939d8.

---

M7 — THE ROUND-TRIP PROPERTY. Branch feat/m7-round-trip.

Plan: .plans/2026-09-18-chez-uri-project-brief.md "The test instrument comes
first" (instrument #2: the round-trip property) and "M7 — recomposition and the
round-trip property"; .plans/2026-09-18-chez-uri-design.md §7 (the instrument
table) and §5 (recompose landed M6 per 0021). Decisions in force: 0005 (the
corpora), 0008 (absent ≠ empty, carried through parse↔recompose), 0010
(bytevectors), 0011 (v0.1 is resolution-first; M7 is the LAST implementation
milestone before M8 release), 0012 (abnfgen is the v0.2 positive corpus — NOT
built at v0.1, so M7 rides the COMMITTED corpora + hand vectors), 0020/0021
(normalize/recompose).

Base at start: f414d90 (local main == origin/main; M6 merged as b0939d8, its
close-out f414d90). Measured environment (2026-09-18, Darwin arm64): Chez 10.4.1
(tarm64osx), CMake/CTest 4.3.3. Baseline on the branch before any slice: release
61/61, no-scheme 11/11.

WHAT M7 SHIPS (provisional, pending the round-trip survey): the ROUND-TRIP
PROPERTY as a lane — parse → normalize (§6.2.2) → recompose (§5.3) → parse
reaches a fixed point, and the re-parsed (normalized) components equal the first
normalized components (`uri-components=?`, keeping absent ≠ empty). §5.3 recompose
already shipped at M6 (0021), so M7 adds NO new core library by default — it is a
VERIFICATION milestone (a property lane over the committed corpora + hand
vectors), plus minimal recompose hardening only if the property surfaces a real
gap. This is the house rule "a property is measured or it is not claimed" applied
to the recompose↔parse seam.

THE DESIGN QUESTION (the M7 analog of 0020/0021, to be settled by the survey and
recorded as a decision). The round trip is NOT total over all components: §5.3
recompose is faithful for components that came from a parse in a known mode,
EXCEPT the RFC §4.2 cases —
  - a RELATIVE reference whose first path segment contains `:` (`{scheme=#f,
    path="a:b"}` recomposes to `a:b`, which re-parses as `{scheme=a, path=b}`);
  - a no-authority reference whose path starts with `//` (`{authority=#f,
    path="//x"}` recomposes to `//x`, re-parsing as `{authority=x, path=""}`).
§5.3 does NOT add §4.2's disambiguating `./`. The likely scope: the property is
asserted over ABSOLUTE URIs (with a scheme), which the committed §5.4 targets and
§1.1.2 examples all are, so the corpora avoid the relative-ref hazards; the §4.2
boundary is DOCUMENTED (a producer of a relative reference must apply §4.2), not
faked. The survey confirms the invariant, whether normalize is idempotent, the
exact failure modes, and the slice plan (1 or 2 slices).

SLICE ⓪ OPEN (2026-09-18): ledger seeded (provisional); branch cut from f414d90;
the round-trip property survey commissioned (three investigators — the fixed-point
invariant, the failure modes, the corpus/scope — synthesized adversarially
against the RFC and the actual parse/normalize/recompose code), so the property's
statement and its §4.2 boundary are derived before a lane is written.

THE SURVEY CAME BACK AND RESHAPED THE INVARIANT (2026-09-18). Two findings, both
code-verified, that a naive statement would have gotten WRONG:
  1. The property is a ONE-STEP parse∘recompose identity on the ONCE-normalized
     components, NOT a fixed point of normalize. normalize is provably NOT
     idempotent over v0.1's non-validating domain: `%%341` → `%41` (pass 1: the
     leading literal `%` is kept, `%34` decodes to `4`) → `A` (pass 2). A
     `normalize(normalize(x)) == normalize(x)` lane is a false universal that
     input reddens. The invariant does not need idempotence — the second parse
     re-splits bytes without re-normalizing.
  2. The property holds at 100% over ALL parse outputs reparsed IN-MODE (every
     mode, not just absolute URIs), because the scanner's first-match-wins never
     emits the §4.2 (colon-first-segment) or §3.3 (`//`-leading path) hazard
     shapes. Those breaks are inherent to §5.3 over ARBITRARY components,
     documented not hardened. Recommended plan: TWO slices, decision-first.
Decision 0022 records the invariant, the non-idempotence boundary, the §4.2/§3.3
recompose boundary, and the two-provenance corpus rule.

SLICE ⓪ COMPLETE (2026-09-18). Landed: decision 0022 and the round-trip property
lane over the NORMATIVE corpora, plus a normalize/absent-empty smoke. Evidence:
release 63/63 (was 61), no-scheme 11/11. Darwin arm64, Chez 10.4.1 tarm64osx,
CMake/CTest 4.3.3.

`property.round-trip` (10 cases / 58 checks) drives the whole read+core stack per
input: parse (mode `uri`) → normalize-components (§6.2.2, ONCE) → recompose (§5.3)
→ parse, asserting `uri-parse-ok?` on both and `uri-components=?(reparse, n0)`
(absent ≠ empty). No new src library — recompose shipped at M6 (0021); this is a
verification lane. It grades every committed URI: the 8 §1.1.2 examples and the 42
§5.4 targets (all absolute, mode `uri`) are fixed points. Because those carry no
uppercase scheme and no `%`, normalization is the identity on them, so a compact
smoke puts a real §6.2.2 delta through the loop (scheme fold `HTTP`→`http`;
`%7E`→`~`; `%2f`→`%2F`; `%2E`→ a literal `.`) and the absent/empty distinction
through recompose→reparse (`http://` vs `http:`; `http://a?` vs `http://a`).

WHAT THE PROPERTY DOES AND DOES NOT TEST, stated honestly (decision 0022): it
tests recompose∘parse STABILITY on n0, not normalize CORRECTNESS (that is
unit.normalize's, M5) — a normalize that did nothing would still round-trip. What
reddens is a recompose or parse that is not faithful, or a normalization whose
output does not survive recompose→reparse. Three mutation witnesses, each watched
red then reverted, prove the teeth: recompose dropping the scheme `:` (`ftp//…`
reparse fails); recompose dropping `//` for an empty authority (`http://`→`http:`,
empty authority reparses ABSENT); recompose dropping `?` for an empty query
(`http://a?`→`http://a`, empty query reparses absent) — the last two pin the
absent/empty distinction in both directions THROUGH the round trip.

The exhaustive hand-vector battery (the full empty/absent matrix, more normalize
deltas), the `%%341` non-idempotence pin, and the §4.2/§3.3 expected-non-round-
trip pins (parsed in mode `uri-reference`) are Slice ①, per the survey's
epistemic split (normative corpora vs authored vectors on opposite sides of a
gate, as 0020/0021 were sequenced).

ADVERSARIAL REVIEW (subagent, at the slice gate): no code defect — `round-trip-
diff` is mechanically correct (normalize applied exactly ONCE, same-mode reparse,
`uri-parse-ok?` on both parses, the only PASS return is the `uri-components=?`
equality), the absent/empty half is load-bearing, the ldap `?`-in-query and urn
colon-in-path examples genuinely round-trip, and the wiring resolves every import.
One should-fix and two nits, closed here:
  - should-fix (VACUITY): the four normalize-delta smoke cases were DECORATIVE —
    the property is inherently blind to a normalize that does nothing (identity
    output always round-trips), and `%7E`/`%2f`/`%2E` are all boundary-preserving,
    so `normalize-components := identity` survived the whole lane. The honest fix:
    the comment now states the property tests recompose∘parse STABILITY not
    normalize correctness and names the ONE fault it catches (a normalize that
    decodes a RESERVED octet into a delimiter), and a TEETH case was added —
    `http://a?x%23y` (an encoded `#` in the query must stay encoded) — witnessed
    by making `unreserved-byte?` admit 0x23: normalize then decodes `%23`→`#`,
    recomposes `?x#y`, and the reparse splits a fragment, breaking the round trip.
  - nit (VACUITY): the corpus groups asserted "all eight"/"all 42" but a
    for-each over an empty corpus passes vacuously — added `length` = 8 / = 42
    count checks (the committed files are already guarded by unit.corpus, this
    pins the lane too).
  - nit: `check-round-trips` emitted two failures per break (an uninformative
    "expected a true value" then the diagnostic) — now one `check-fail` with the
    detail.
Decision 0022 gained a Sequencing note: a reader must not expect the `%%341` /
§4.2 / §3.3 / exhaustive-matrix pins in Slice ⓪ — those are Slice ①; Slice ⓪
ships the machinery, the normative corpora, the absent/empty smoke and the one
teeth case. Evidence after fixes: property.round-trip 11 cases / 61 checks;
release 63/63, no-scheme 11/11.

SLICE ⓪ GATE (2026-09-18): decision 0022 presented and ACCEPTED by the maintainer
("accept 22 and drive slice one"). The maintainer asked for a recommendation
first; I recommended accepting 0022 (the one-step/not-idempotence call is forced
by the `%%341` proof; the §4.2/§3.3 documented-not-hardened boundary is correct
because hardening recompose would corrupt §5.2.2 resolution), documenting the
recompose-not-total-inverse limitation in the release notes, deferring the
§4.2-safe relative serializer to v0.2, and proceeding to Slice ①.

SLICE ① COMPLETE (2026-09-18). Landed: the exhaustive round-trip battery on the
existing `property.round-trip` lane — no new src (M7 adds no core library).
Evidence: property.round-trip 25 cases / 82 checks (was 11/61); release 63/63,
no-scheme 11/11. Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3.

Added, all verified empirically against the live stack before assertion: (1) the
EXHAUSTIVE empty/absent matrix through recompose→reparse — fragment `http://a#`
vs `http://a`, the §3.2 case `http:///p` (empty authority, absolute path) vs
`http:/p` (absent), `http://a?#` (query AND fragment empty), `http:#` (fragment
empty, no authority); (2) the §6.2.2 delta reaching the AUTHORITY (`%41`→`A`) and
the FRAGMENT (`%7E`→`~`), not only the path; (3) the NON-IDEMPOTENCE pin — a
direct check that `pct-normalize %%341` = `%41` and `pct-normalize` of THAT = `A`
(so N is not idempotent, the reason the invariant is one-step), and the one-step
round trip HOLDS for `http://h/%%341` (n0 path `/%41` reparses to `/%41`); (4) the
§4.2/§3.3 RECOMPOSE BOUNDARY over HAND-BUILT components — `{scheme=#f, path="a:b"}`
recomposes to `a:b` which reparses as `{scheme=a, path=b}` (a break), and
`{authority=#f, path="//x"}` recomposes to `//x` which reparses with authority
`x` — each paired with a pin that the PARSER NEVER EMITS the hazard shape
(`parse[uri-reference] "a:b"` = `{s=a,p=b}`; `"//x"` = `{a=x,p=""}`), so the round
trip over parse outputs never meets the boundary.

MUTATION WITNESS (Slice ①): the sharpest new case, the §3.2 `http:///p` vs
`http:/p` distinction, watched red — dropping `//` for an empty authority makes
`http:///p` recompose to `http:/p`, whose reparse reads the authority ABSENT, so
the round trip breaks. (The round-trip machinery's other teeth — the scheme colon
and the empty query — were witnessed at Slice ⓪; the boundary and non-idempotence
pins assert concrete values verified against the live stack.)

README.org (status → "M7 — the round-trip property", plus a recompose-boundary
caveat) and CHANGELOG.md landed with this slice.

M7 MERGE-GATE VERIFICATION (2026-09-18, at the merge gate). A three-dimension
multi-agent adversarial pass — lane correctness/non-vacuity, decision/doc
fidelity, completeness — each finding adjudicated. No code DEFECT: `round-trip-
diff` re-verified correct (one normalize, same-mode reparse, `uri-parse-ok?` on
both, the only PASS is the `uri-components=?` equality) and non-vacuous. Findings
closed:
  - should-fix (completeness): decision 0022 item 3 claims the property holds in
    EVERY mode, but only mode `uri` (all-absolute corpora) was MEASURED —
    relative refs appeared only in the §4.2/§3.3 break cases. Added a positive
    relative-reference group (`g`, `g/h`, `../g`, `./g`, `/g`, `?q`, `#f`, ``,
    `g;x=1/../y`, `a/b?c#d`, `./a:b`), all verified HOLD in mode `uri-reference`
    against the live stack before assertion — so the "every mode" claim is now
    measured, and `./a:b` pins the §4.2-SAFE colon form (colon in the second
    segment) beside the unsafe one.
  - should-fix (DECISION FIDELITY, the sharpest): decision 0022 (and its copies
    in CHANGELOG and the test comment) justified not-hardening recompose with
    "hardening would corrupt §5.2.2 resolution" — WRONG and self-contradictory. A
    §4.2-faithful guard (scheme-absent) never fires on a resolution target (which
    always carries a scheme), so it cannot corrupt resolution. The CORRECT reason
    is RFC fidelity: §5.3 deliberately omits the `./`, and the disambiguation is
    the reference PRODUCER's job (a v0.2 serializer above recompose). Fixed in all
    three places, and the §3.3 reasoning sharpened (resolution avoids it because
    R comes from a parse, which §3.3 forbids from emitting a `//`-leading
    no-authority path — not merely because targets carry a scheme).
  - should-fix (stale header): the suite header still said the exhaustive battery
    and §4.2/§3.3 pins "are Slice ①" as if elsewhere, though Slice ① merged them
    into this file — rewritten to describe the whole property.
  - nit: "decision 0015's §5.4.2 loophole note" was a mislabel (0015 is the
    erratum-4547 adjudication; the §5.4.2 `http:g` loophole is the corpus's note
    citing 0001) — corrected in 0022 and the test.
  - nit: the boundary cases dereferenced a `recompose-reparse` result that would
    be `#f` on a future recompose regression, erroring cryptically — added a
    `(uri-components? rp)` check first, so a regression names itself.
  - nit: the reserved-decode teeth were witnessed only for `#` in the query;
    added a second position — `%2F` in the AUTHORITY must stay encoded — witnessed
    red (decoding it makes `http://a%2Fb` → `http://a/b`, authority/path resplit).
Two findings were PARTIAL/non-issues: the round trip is inherently blind to
scheme-fold/hex-upcase/unreserved-decode (disclosed in the HONEST SCOPE block,
those are unit.normalize's, M5); scheme-`%` is unreachable and `//`-with-authority
round-trips (checked, recorded).

Evidence after fixes: property.round-trip 27 cases / 96 checks (was 25/82);
release 63/63, no-scheme 11/11. The review found the CODE sound; the fixes were
one measured claim, one corrected justification, and doc reconciliation.

M7 MERGED (2026-09-18). PR #5 squash-merged to main as 05aa2d8; local main
fast-forwarded (f414d90..05aa2d8); feat/m7-round-trip deleted local and remote.
Merged on a RED linux-amd64 check, confirmed as the documented Actions billing
refusal (decision 0017 — a completed/failure run at ~5s, the 0-step shape M2/M5/
M6 also merged over: `gh run view` reports steps=0, so no test ever executed),
not a test result — local evidence stands in its place (release 63/63, no-scheme
11/11, property.round-trip 27/96). The maintainer authorised the closing ritual
explicitly. (Operational note, not a repo fact: the SSH agent failed for the
whole back half of this session, so the branch push and the main fast-forward
went over HTTPS via `gh auth git-credential`; the API merge and branch-delete
were unaffected.)

REFLECTION. M7 was the milestone with NO new code — decision 0021 shipped §5.3
recompose at M6, so M7's entire deliverable was a property lane and decision
0022. That made its one hazard epistemic, not mechanical: the risk was not a
wrong line but a property STATED so it could not fail. Three moments bear that
out. First, the survey reshaped the invariant before a lane existed: the brief's
"reaches a fixed point" reads like normalize idempotence, but normalize is
provably NOT idempotent over v0.1's non-validating domain (`%%341 → %41 → A`), so
a `normalize(normalize x) == normalize x` lane would have been a false universal
that a single input reddens. The property is a ONE-STEP parse∘recompose identity
on the once-normalized components — derived from the RFC and the actual code, not
transcribed from the brief's prose, the same oracle-from-RFC discipline that held
at M5/M6 turned on the property statement itself. Second, the vacuity theme
recurred, sharper than ever: Slice ⓪'s review found the normalize-delta smoke was
DECORATIVE — the round trip is inherently blind to a normalize that does nothing,
so `normalize := identity` survived the whole lane — the M7 face of "a test green
for the wrong reason" (M2 copy-discipline, M5 empty-authority, M6's three unobserved
resolve paths). The fix named the ONE fault the property can catch (a normalize
that decodes a RESERVED octet into a delimiter) and pinned it with teeth (`%23`
in a query, `%2F` in an authority), so the lane now states its own blind spot
rather than hiding it. Third — the milestone's most valuable catch, and a new
kind — the merge-gate corrected reasoning INSIDE an already-accepted decision:
0022 justified not-hardening recompose with "hardening would corrupt §5.2.2
resolution," which is wrong (a scheme-absent §4.2 guard never fires on a
resolution target, which always carries a scheme) and had already propagated to
the user-facing CHANGELOG. The real reason is RFC fidelity: §5.3 deliberately
omits §4.2's `./`, and that disambiguation is the reference PRODUCER's job (a
v0.2 serializer above recompose). A record being accepted did not make it
correct; the adversarial pass read the justification, not just the code, and the
same gate measured the "holds in every mode" claim that had been asserted from
mode `uri` alone (added a positive relative-reference group, verified against the
live stack). The settled pattern across M2/M5/M6 extends: the per-slice review
catches within-library bugs, and the merge-gate catches what a single library —
or a single decision record — cannot see about itself.

NEXT (M8 — release v0.1). This was the last IMPLEMENTATION milestone; the v0.1
arc is complete — the generic split (M2), the pure core percent/normalize (M5),
§5.4 resolution at 42/42 (M6), and the round-trip property measured (M7). M8 is
release, not code: cut and tag v0.1, reconcile the README status/caveats and the
CHANGELOG's [Unreleased] into a dated release section, and decide what the
version's honest claim is (a resolution-first, non-validating splitter+resolver;
host grammar and charset validation are v0.2 per decision 0011). The one standing
external fact to carry in: CI has still never run (decision 0017), so v0.1's
evidence is macOS arm64 local — the release notes must say so in the body, not a
footnote. No M7 debt carried forward — the tree is clean on main at 05aa2d8.

---

M8 — RELEASE v0.1. Branch feat/m8-release.

Plan: .plans/2026-09-18-chez-uri-project-brief.md "M8 — release v0.1" (a heading
only — the brief intentionally leaves the release checklist to be DERIVED) and
.plans/2026-09-18-chez-uri-design.md §6 ("What v0.1 therefore is, and what it
must not claim"). Decisions in force: 0003 (RFC 3986 is the normative reference;
disagreement adjudicated against the ABNF), 0011 (v0.1 is resolution-first; M3
charset / M4 host grammar are v0.2), 0017 (CI has never run; v0.1's evidence is
macOS arm64 LOCAL — a disclosure, not a footnote), 0020/0021/0022 (the core's
scope boundaries the release notes must state honestly).

Base at start: aced550 (local main == origin/main; M7 merged as 05aa2d8, its
close-out aced550). Measured environment (2026-09-18, Darwin arm64): Chez 10.4.1
(machine-type tarm64osx), CMake/CTest 4.3.3. Baseline on the branch before any
slice, RE-MEASURED on this tree (not carried forward): release preset 63/63
(0 failures), no-scheme preset 11/11 (0 failures) — read from
build/{dev,no-scheme}/test-results/*.xml.

WHAT M8 SHIPS (provisional, pending the release-readiness survey): a v0.1 release
with NO new algorithm and (expected) no new src library — the milestone's work is
release mechanics (a SemVer tag on a release commit), doc reconciliation (the
CHANGELOG's single [Unreleased] into a dated section; README.org's status/caveats
into a released state), the honest v0.1 CLAIM stated from the decisions not
improvised (a non-validating splitter + strict §5.2.2 resolver + complete pure
core; §5.4 at 42/42; round-trip measured; NOT "RFC 3986 compliant"; host grammar
and charset are v0.2), and the mandatory 0017 CI disclosure. CMakeLists.txt
already declares PROJECT_VERSION 0.1.0; there are no git tags yet; docs/ is empty.

THE RELEASE QUESTIONS (the M8 analog of 0020/0021/0022, to be settled by the
survey and recorded as decision 0023): the exact tag semantics (v0.1.0 annotated,
on which commit) and whether a pushed tag / GitHub Release are in scope — both are
OUTWARD-FACING PUBLISH actions that must be maintainer-approved at the gate, never
assumed; the CHANGELOG reconciliation shape (Keep-a-Changelog); whether a v0.1
library release needs a minimal user-facing docs/ quickstart or README suffices;
the release-verification evidence (which suites must be green at the tagged
commit, re-measured and platform-stamped); and the meta-call of releasing on
never-run CI (0017 authorizes shipping-with-disclosure, but the maintainer
ratifies it).

SLICE ⓪ OPEN (2026-09-18): ledger seeded (provisional); branch cut from aced550;
baseline re-measured (release 63/63, no-scheme 11/11); the release-readiness
survey commissioned (four investigators — release mechanics/versioning, doc
reconciliation, the honest claim + disclosures, release verification/scope —
synthesized adversarially into a proposed decision 0023, a slice plan, and an
explicit list of maintainer-gated outward-facing actions), so the release's shape
and its claim are derived before a tag or a doc edit is written.

THE SURVEY CAME BACK (2026-09-18). Verdict: v0.1 is ready to release WITH
disclosure — the code gate is clean and green (re-measured on this tree: release
63/63, no-scheme 11/11, 0 failures, exercising both source and aot lanes plus the
import/rename/provenance/corpus-provenance audits and both mutation suites), zero
TODO/FIXME/XXX in src/tools/cmake, all 22 decisions accepted, LICENSE consistent,
PROJECT_VERSION already 0.1.0. M8 ships NO code and NO new lane; the only work is
the release act. The proposal became decision 0023's seven points: (1) no
algorithm/src/lane; (2) one annotated tag v0.1.0 (byte-machine's SemVer
precedent) on the squash-merged reconciliation commit, NOT aced550, no metadata
change; (3) structural doc reconciliation with the measured prose preserved
verbatim (no Keep-a-Changelog Added/Changed rewrite); (4) the honest claim from
the decisions, not improvised; (5) THIS record is the amendment that releases on
never-run CI, disclosed in the body; (6) a fresh re-measure at the tagged commit;
(7) automation stops at a LOCAL tag — push, squash-merge and any GitHub Release
are maintainer-gated. The synthesizer REJECTED three investigator overreaches as
v0.2, not M8: a docs/quickstart (an untested example is itself an unmeasured
claim), a downstream consumption-smoke lane (would change the count, break the
no-code charter, and is redundant with the source+aot conformance/round-trip
lanes that already import the public libraries), and PGP-signing as a gate
(maintainer key discretion). Plan: ONE slice — no code ships, so a doc/verify
split earns no gate; byte-machine's own precedent is a single docs(release)
squash commit.

SLICE ⓪ GATE (2026-09-18): decision 0023 presented with a recommendation, and the
one genuine judgment isolated for the maintainer — releasing a public v0.1 tag is
a strictly larger claim than the M1 merge decision 0017 covered, and the house
convention (byte-machine 0041, quoted in 0017) forbids waiving an unfunded Tier-1
cell "quietly in release notes," so the tag needs its OWN recorded amendment. I
recommended shipping with disclosure (0023 is that amendment; 0017 item 3 stays
open and disclosed; the first funded run discharges it); the alternative was to
fund a CI run first. The maintainer chose "ship with disclosure" — ACCEPTING
decision 0023 (including point 5's ratification) and authorizing Slice ①.

SLICE ① COMPLETE (2026-09-18). Landed the whole release reconciliation in one
slice — NO src, NO new lane (M8's charter). (1) decision 0023 recorded (the seven
points above, grounded in the survey and decisions 0003/0011/0015/0017/0020/0021/
0022, with byte-machine's tag precedent verified: v0.6.0 is an annotated object on
a docs(release) squash commit, tags v0.1.0..v0.6.0). (2) README.org status line
flipped "M7 — the round-trip property (the last milestone before v0.1)" → "v0.1.0
— released 2026-09-19"; the five-caveat non-claims block and the CI-not-run quote
block kept VERBATIM. (3) CHANGELOG.md reconciled structurally: the "has not been
released" preamble → the Keep-a-Changelog opener; "## [Unreleased]" → "## [0.1.0]
- 2026-09-19" with a fresh empty "## [Unreleased]" above and compare/tag link refs
appended; the decision-0017 CI-never-ran + macOS-arm64-local disclosure placed in
the [0.1.0] section BODY (not a footnote); the M7..M1 milestone prose preserved
unchanged. Evidence, RE-MEASURED on the post-edit tree (docs-only, so unchanged
from baseline but measured not assumed): release 63/63, no-scheme 11/11, 0
failures. Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3.

M8 MERGE-GATE VERIFICATION (2026-09-18, at the merge gate). A three-lens
adversarial doc-fidelity pass — contradiction/stale-language sweep, honest-claim
accuracy against the actual exports, decision-0023 fidelity — plus adjudication.
Verdict: MERGE-READY, NO confirmed defects. The honest-claim and decision-fidelity
lenses found nothing; the adjudicator spot-checked their load-bearing claims — the
real exports (resolve-components, recompose, uri-parse), the five negative
disclosures intact at README.org:30-62, the CI-never-ran disclosure in the
CHANGELOG [0.1.0] BODY (not a footnote), the counts re-measured 63/63 + 11/11, and
every decision-0023 citation resolving. Two contradiction-lens findings were
DISMISSED as failing the strict bar: (1) README.org:9's "in portable R6RS" tagline
vs caveat 5's "Not portable" — defensible dialect-naming (R6RS is Scheme's
portable STANDARD, and the property so claimed — source importing only
(rnrs)/(byte-machine …)/own libs — IS lane-measured; caveat 5 disclaims the
ARTIFACT's cross-implementation portability, a different subject), pre-existing
prose the docs-only diff never touched, surfaced to the maintainer as the one
optional one-word polish; (2) README.org:101's "docs/ = user-facing documentation
only" Layout row on an intentionally, 0023-recorded-empty reserved dir (a
directory-ROLE label, not a contents claim). No fixes were made — the doc-set
makes exactly the honest claim the records require (non-validating, not "RFC 3986
compliant", CI-never-ran disclosed in the body). Evidence unchanged: release
63/63, no-scheme 11/11, 0 failures. The doc-set is safe to tag v0.1.0; the tag,
its push, the squash-merge and any GitHub Release remain maintainer-gated
(decision 0023 point 7).

M8 RELEASED (2026-09-19). At the merge gate the maintainer ratified releasing on
never-run CI with disclosure (accepting decision 0023) and chose "merge + tag +
push" (no GitHub Release). The clock had crossed midnight, so the release date was
corrected 2026-09-18 → 2026-09-19 across the shipping artifacts (README status
line, CHANGELOG [0.1.0] heading, decision 0023 point 3, and this ledger's Slice ①
quotes) before the merge — v0.1 is dated the day it was actually cut, the same
re-measure discipline applied to a date. Then the closing ritual: PR #6
squash-merged to main as 264c997; local main fast-forwarded; feat/m8-release
deleted local and remote. The release GATE was RE-MEASURED at 264c997 (the tag
target, not the branch tip): release 63/63, no-scheme 11/11, 0 failures (Darwin
arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3, 2026-09-19), exercising both
source and aot lanes plus the import/rename/provenance/corpus-provenance audits
and both mutation suites. The annotated tag v0.1.0 (unsigned — signing is the
maintainer's key operation, decision 0023 point 2) was cut on 264c997 carrying
the honest claim, the re-measured counts, and the 0017 CI disclosure, and pushed
to origin (tag object 5cc4d10 → 264c997), so v0.1.0 is consumable by the submodule
gitlink pin. Merged and released over a RED linux-amd64 check, the documented
Actions billing refusal (decision 0017 — a completed/failure run at ~5s with 0
steps, confirmed by `gh run view`), not a test result; local macOS-arm64 evidence
stands in its place, disclosed in the tag and the CHANGELOG body. (Operational
note, not a repo fact: the SSH agent stayed broken for this whole session, so
every push — branch, force-push, tag, and the main fast-forward — went over HTTPS
via `gh auth git-credential`; the API merge and branch-delete were unaffected.)

REFLECTION — M8, AND THE v0.1 ARC. M8 was the milestone that shipped NO code at
all: not a src library, not even a test lane (M7 at least added the round-trip
lane). Its deliverable was a tag, reconciled docs, and one decision — so its whole
risk was, like M7's, epistemic, but sharper: a release is the moment a project
states its claim OUT LOUD, and the failure mode is claiming one micron more than
was measured. Three things carried it. First, the survey earned its keep by
turning a one-line brief heading ("M8 — release v0.1") into a seven-point decision
AND, more valuably, by ISOLATING the single judgment that was genuinely the
maintainer's — releasing on never-run CI — from the mechanical work around it. The
house convention (0017, quoting byte-machine 0041) is that an unfunded Tier-1 cell
is "struck by an explicit amendment, never waived quietly in release notes," and
0017 was M1-scoped; a lesser process would have let the M1 waiver silently cover
the larger release claim. Instead decision 0023 is that amendment, the maintainer
ratified it explicitly, and nothing was rubber-stamped. Second, the discipline
that ran through every prior milestone held to the last inch: the honest claim was
taken from the decision records verbatim, not improvised; the measured milestone
prose was PRESERVED rather than rewritten into Keep-a-Changelog Added/Changed
buckets (which would have dropped the mutation-witness detail the project sells);
the counts were re-measured at the tag commit, not carried forward by arithmetic;
and the CI-never-ran fact went in the release BODY, not a footnote. Third, the
"green for the wrong reason" theme that caught M2's copy-discipline, M5's
empty-authority gap, M6's three unobserved resolve paths and M7's decorative
normalize smoke had a final, quieter echo: the merge-gate's job was to catch an
overclaim or a stale pre-release contradiction the release might smuggle in, and
the strict bar dismissed both candidates — the one real judgment (the "in portable
R6RS" tagline) was SURFACED to the maintainer, not silently "fixed." The arc is
now whole: M1 the instrument with no parser, M2 the generic split, M5 the pure
core, M6 §5.4 at 42/42, M7 the round-trip property measured, M8 the honest
release. Its through-line was an oracle derived from the RFC independently of the
code, mutations watched red then reverted, and the rule "a property is measured or
it is not claimed" — which at the release became the SHAPE of the claim: v0.1 is
exactly what it measured and nothing more, its unmeasured edges (cross-platform
CI, the host grammar, charset validation) disclosed rather than papered over.

NEXT (v0.2, no longer this ledger's milestone sequence). v0.1 is released; the
resolution-first arc (decision 0011) is complete. v0.2 reopens what v0.1 honestly
deferred: M3 (charset validation — turning the scanner's per-component
byte-dispatch fallback edges from "accept" to "error", design §6's cheap estimate
to check against), M4 (the host grammar — userinfo/host/port sub-split, IPv6
address, and host-case normalization, which unblocks the deferred half of decision
0020), plus the deferred docs/quickstart and a downstream consumption smoke
(decision 0023 overreaches, now in-scope), and — the standing external debt — the
FIRST FUNDED CI RUN, which discharges decision 0017 item 3 and replaces v0.1's
local-only disclosure with real cross-platform evidence. The tree is clean on main
at 264c997, tagged v0.1.0.

Post-release: PR #7 (610d007) added a README "Parsing a URI" example, squash-merged
as ecfa4a0. Not a milestone (no ledger reflection); verified by running, not gated
by a lane. It is on main but NOT in the v0.1.0 tag (which stays at 264c997).

---

M3 — CHARSET VALIDATION (v0.2). Branch feat/m3-charset-validation.

Plan: .plans/2026-09-18-chez-uri-project-brief.md "M3 — charset validation"
(pct-encoded in every component that admits it, the scheme charset,
pchar/segment-nz-nc/query/fragment sets, port digits, error offsets for each) and
.plans/2026-09-18-chez-uri-design.md §6. Decisions in force: 0003 (RFC 3986 is
normative, adjudicated against the ABNF), 0005 (the corpus + oracle-from-RFC
discipline; two provenances two counts), 0007 (src is pure R6RS), 0009 (an error
NAMES the ABNF production that failed, and carries an offset), 0010 (bytevectors),
0011 (v0.1 was resolution-first; M3/M4 are v0.2), 0012 (abnfgen is the positive
generator), 0019 (the scanner splits five coarse components delimiter-only; the
core owns the authority AND — item 5 — the charset errors).

Base at start: ecfa4a0 (local main == origin/main; v0.1.0 released as 264c997,
its close-out 453ecbc, the README example ecfa4a0). Measured environment
(2026-09-19, Darwin arm64): Chez 10.4.1 (tarm64osx), CMake/CTest 4.3.3. Baseline
on the branch before any slice, RE-MEASURED: release 63/63, no-scheme 11/11, 0
failures.

THE FORCING QUESTION (the M3 analog of 0020/0021/0022 — settled by the survey and
recorded as decision 0024): WHERE does charset validation live? The record
conflicts. Design §6 (early) says M3 changes the SCANNER nodes' fallback edges
accept→error and adds pct-encoded sub-nodes — GRAMMAR-side, regenerating the
(generated uri-scanner) artifact. But decision 0019 item 5 (accepted at M2, the
line the code is built around; restated in vocabulary.sls:138-147 and
grammar.sls:80-87) says the scanner's error vocabulary is ONLY the four structural
codes and that "Host and charset errors (invalid-ip-literal, invalid-dec-octet,
invalid-pct-encoded, …) are the CORE's, raised where the core validates" —
CORE-side, over the split component bytevectors, scanner stays delimiter-only.
Design §6 predates 0019's redraw of the functional-core line, so it is LIKELY
STALE PROSE (the project's own memory note: the prose lags the code on the points
that matter most). The survey adjudicates this — the answer reshapes the whole
milestone (core = pure R6RS, no ABI change; grammar = regenerate the scanner,
re-pass the ABI-9 + determinism lanes and contradict 0019).

Sub-questions the survey settles: the exact M3 component scope (scheme, path,
query, fragment charsets — and does PORT slip to M4, since the authority is one
opaque bytevector until M4 splits userinfo/host/port?); the ERROR-OFFSET mechanism
(collect.sls accumulates span BYTES but tracks no start offset — a core validator
finding a bad byte at component index i needs the component's absolute start
offset to satisfy 0009); where the validator lives (extend (uri percent) vs a new
(uri charset)/(uri validate)); and the NEGATIVE corpus — none exists yet (only
positive vectors + the committed ABNF), so M3 must derive invalid vectors from the
ABNF independently of the code (oracle discipline), each tagged with the production
it violates and its expected offset.

SLICE ⓪ OPEN (2026-09-19): ledger seeded (provisional); branch cut from ecfa4a0;
baseline re-measured (release 63/63, no-scheme 11/11); the M3 scoping survey
commissioned (four investigators — placement grammar-vs-core, scope+offsets,
the ABNF charsets+pct, the negative corpus+oracle — synthesized adversarially into
a proposed decision 0024, a slice plan, and blockers), so the placement question
and M3's exact scope are settled before a line of validator is written.

THE SURVEY CAME BACK (2026-09-19). Verdict: CORE placement, NOT a close call.
0019 item 5 governs and the code already enforces it — vocabulary-tests.sps
asserts invalid-pct-encoded/invalid-scheme/… OUT of the scanner set with a green
mutation-witnessed test — so going grammar-side would redden an existing test to
reverse an accepted decision. Design §6's grammar-side note is the stale prose the
design's own amendment banner already conceded. The one novel "grammar is
impossible" argument was walked back (byte-machine could carry a scheme-taint
field; it is redundant, not impossible). Decision 0024's seven points: (1) core
placement, scanner stays delimiter-only; (2) scope = scheme/path/query/fragment +
pct-encoded, with PORT and all authority-interior charsets DEFERRED to M4
(correcting the brief's "port digits" — the authority is one opaque span until M4
and 0009 can't name the production without the split); (3) offsets rebased in the
shell (collect) from the runtime stream offset, witnessed not assumed; (4) a new
pure (uri charset), NOT an extension of the deliberately-non-validating
(uri percent); (5) a core error vocabulary (invalid-scheme/-pchar/-query/
-fragment/-pct-encoded) named per ABNF production, kept out of the scanner set;
(6) a hand-derived negative corpus, tagged (production, absolute-offset), separate
provenance and count, gated by a cross-check + coverage floors (not a ratchet);
(7) M3 opens v0.2, v0.1.0 frozen. The synthesizer pruned four overreaches:
carried-forward node/byte counts (re-measure, don't assert), building the
abnfgen/mutator in M3 (deferred v0.2 tooling), and pulling port/host charset
forward. Plan: three slices (⓪ decision+oracle+corpus; ① the offset seam in
collect; ② the (uri charset) validator).

SLICE ⓪ COMPLETE (2026-09-19). Landed the decision + the oracle + the negative
corpus — NO src validator (that is Slice ②). (1) decision 0024 recorded (seven
points, citations verified). (2) design §6 amended in place with a "Superseded by
0024" banner + the port/host→M4 corrections. (3) (uri test charset-oracle) — the
ABNF byte sets (unreserved/sub-delims/pchar/…) and oracle-scan, an INDEPENDENT
reference validator derived from the ABNF (RFC 5234 B.1 for ALPHA/DIGIT/HEXDIG,
lower-case hex admitted per §6.2.2.1), plus the negative-corpus loader and the
cross-check. It is test-side (grades the src validator in Slice ②), so outside the
src import-audit. (4) test/conformance/charset/{negative.scm,PROVENANCE} — 15
hand-derived negative vectors (scheme 4, pchar 4, pct 4, query 1, fragment 2),
each tagged with the ABNF production and the ABSOLUTE offset (the "%" for a
malformed pct-encoded); a SEPARATE provenance ("ours, derived from the ABNF, not
extracted from the RFC text"), kept out of the corpus-provenance-guarded rfc3986/
dir. (5) the lane uri.unit.charset-oracle (source+aot) cross-checks every row
against the oracle. Evidence: release 65/65 (was 63), no-scheme 11/11, 0 failures.
Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3.

ORACLE DISCIPLINE + REVIEW (Slice ⓪). The corpus was INDEPENDENTLY REFUTED by a
subagent that re-derived every offset/production from the ABNF and RFC 5234, blind
to the oracle code (and with its own verification script): all 15 rows AGREE, zero
corrections. Two MUTATION WITNESSES watched the lane redden then reverted: a
corrupted corpus offset (10→9, where the byte is a valid 'a') → "invalid-pchar at
9 but that byte is valid for path"; and a corrupted oracle byte-set (path admits
space) → both the oracle-scan pin AND the corpus cross-check reddened, proving the
byte sets are load-bearing. A per-slice adversarial review found NO blockers and
closed one should-fix + two nits: the cross-check's pct-encoded branch skipped the
component check the literal branch had (a mislabeled pct row on 'scheme passed) —
hoisted a code↔component guard to the front for all codes and witnessed the new
guard red ("code invalid-pct-encoded does not name component scheme"); oracle-scan
computed ok? eagerly, raising instead of a graceful diagnostic on an out-of-scope
component (fixed by the same hoist); and an unused `code` binding in oracle-scan's
scheme branch (scoped it to path/query/fragment). Re-measured after fixes: release
65/65, no-scheme 11/11.

SLICE ① COMPLETE (2026-09-19). The OFFSET SEAM in (uri collect) — the shell's
half of decision 0024 item 3, so a core validator's component-relative index can
rebase to an absolute input offset. No validator yet (Slice ②); no charset logic.
The collector captures each present span's absolute start at its FIRST fragment
(the runtime commits parser-stream-offset — the fragment's END — before the data
callback, so the start is that minus the fragment width), and `assemble-offsets`
mirrors `assemble` to give each component's start: a mode-3 scheme/segment verdict
rebases onto the leading token, and a rooted path (0018) begins one byte BEFORE
its span, where the dropped "/" was. Exposed as uri-parse-component-offset :
result symbol -> (Option Nat), keeping absent (#f) distinct from present-empty (a
captured offset). uri-parse-result gained an internal offsets alist (present
components only); uri-components is UNCHANGED (offsets live on the shell's result,
not the seam type). THE FORMULA WAS WITNESSED, NOT ASSUMED: a probe printed the
computed offsets for nine inputs and every one matched a hand count (scheme@0,
authority@7, path@8, query@17; the rooted "http:/p" path@5; the empty-authority
"http:///p" path@7 which is NOT rooted; mode-3 "g:h" scheme@0/path@2 and "g/h"
path@0). Then the unit.collect "offsets" group pins all three path shapes + the
absent cases + feed-invariance (dripped byte-at-a-time gives the same absolute
offsets). MUTATION WITNESS: dropping the rooted "-1" reddened three checks
(rooted path@5→6, rel rooted@0→1, drip rooted@5→6), then reverted. Evidence:
release 65/65, no-scheme 11/11, 0 failures.

SLICE ② COMPLETE (2026-09-19). The VALIDATOR. (1) (uri charset) — pure R6RS
importing only (uri percent) (reusing unreserved-byte? and hex-digit-value, so the
validator and the codec cannot disagree about a byte), written INDEPENDENTLY of
the oracle: validate-component : Symbol Bytevector -> (values (Option code)
(Option index)), plus the core error vocabulary (invalid-scheme/-pchar/-query/
-fragment/-pct-encoded, 0024 item 5). (2) uri-parse-validate wired through the
shell (uri collect): parse leniently, then judge scheme/path/query/fragment (in
input order, so the first error is the leftmost), rebasing the validator's
relative index onto the offset seam to an ABSOLUTE offset; a charset fault becomes
an error result (ok? #f, the core code, the absolute offset), like a structural
one. CRUCIALLY, uri-parse ITSELF STAYS LENIENT — validation is a distinct entry,
not always-on — because M5/M6/M7 depend on the non-validating splitter (M7's
round-trip deliberately parses a malformed "%%341" to test normalization; making
uri-parse validating would redden it). (3) the unit.charset lane grades three
ways: validate-component AGREES with oracle-scan on all 256 single bytes × four
components + a pct-encoded battery (two independent readings of the ABNF, agreement
is the check); the negative corpus is rejected with the exact code AND absolute
offset end to end; and the positive corpora (8 §1.1.2 + 42 §5.4 targets) are all
ACCEPTED (the reject-everything guard), with a structural error still passing
through. CMake: URI_COLLECT gained percent + charset (manifest completeness), and
the now-duplicate explicit percent.sls was dropped from the resolution/round-trip
lanes. Evidence: release 67/67 (was 65), no-scheme 11/11, 0 failures.

MUTATION WITNESSES (Slice ②): (A) the offset-seam integration — dropping the
component-offset from the rebase (reporting the relative index) reddened every
non-zero-offset negative (path space expected 10 got 2, high-byte expected 9 got
1, …), proving the seam is load-bearing; (B) an over-permissive path (space
admitted) reddened THREE ways at once — the exhaustive byte-agreement (path byte
32), a multi-byte agreement, and the negative corpus (the space no longer
rejected) — proving both the oracle and the corpus catch a loose validator. Both
reverted; import-audit green (charset is pure R6RS).

M3 MERGE-GATE VERIFICATION (2026-09-19, at the merge gate). A four-lens adversarial
pass (validator correctness + oracle independence, the offset seam + shell wiring,
lane non-vacuity, decision/CMake fidelity) + adjudication. Verdict: READY TO
MERGE, NO blockers — the validator logic is correct, the oracle is genuinely
independent, and the offset seam was corroborated. Six findings closed (three
should-fix, three nits):
  - should-fix (PROVENANCE GAP): the unit.charset lane executed the byte-machine
    runtime (via uri-parse-validate → collect → generated scanner) but did NOT
    fingerprint it — URI_GENERATOR_SOURCES was omitted, the one collect-driving
    lane that missed it, so a runtime.sls change would perturb its siblings'
    fingerprints but not this lane's. Added URI_GENERATOR_SOURCES to its SOURCES.
  - should-fix (LEFTMOST unwitnessed): validate-result visits scheme→path→query→
    fragment and returns the first error, but every negative row had exactly ONE
    bad component, so a permuted visit order survived green. Added a two-fault row
    ("1a:x#y z": bad scheme AND bad fragment) asserting invalid-scheme@0, and
    mutation-witnessed it — reversing the order reports invalid-fragment@6 instead.
  - should-fix (0024 SILENT on the lenient split): the record did not say uri-parse
    stays lenient and validation is the distinct uri-parse-validate entry (the
    rationale lived only here). Amended 0024 item 3 in place with that choice and
    its reason (M7 parses a malformed "%").
  - nit: 0024 item 4 claimed (uri charset) imports (uri components); it imports
    only (uri percent) (dispatches on a component symbol over a bytevector).
    Trimmed the record to match the shipped library.
  - nit (pct hex agreement not exhaustive): single-byte agreement never reaches the
    two-HEXDIG path, so hex-digit-value vs oracle-hexdig? agreeing on all 256 rested
    unasserted. Added an exhaustive %XY sweep (256×256, one accumulator check).
  - nit (offset bases not composed end to end): every path/query/fragment negative
    was authority-present/non-rooted/non-stitched, so the rooted (-1) and mode-3
    rebases were witnessed only in isolation. Added a rooted no-authority path
    ("http:/ p" → invalid-pchar@6) and a mode-3 stitched path ("g/ h" →
    invalid-pchar@2), plus a pct fault routed through a query.
One finding was DISMISSED: a "no in-lane floor on the negative corpus" concern —
the charset-oracle lane already applies per-production floors to the SAME file, so
any shrink reddens a sibling. The negative corpus grew 15 → 19 rows. Evidence after
fixes: release 67/67, no-scheme 11/11, 0 failures. The review found the CODE sound;
the fixes were one provenance gap, one measured claim, one recorded decision, and
coverage/doc reconciliation.

M3 MERGED (2026-09-19). PR #8 squash-merged to main as 3686dc6; local main
fast-forwarded (ecfa4a0..3686dc6); feat/m3-charset-validation deleted local and
remote. Merged over a RED linux-amd64 check, confirmed the documented Actions
billing refusal (decision 0017 — a completed/failure run at ~6s with 0 steps, per
`gh run view`), not a test result; local macOS-arm64 evidence stands (release
67/67, no-scheme 11/11, import-audit green). The maintainer authorised the closing
ritual explicitly. Pushes went over HTTPS via `gh auth git-credential` (the SSH
agent stayed broken this session); the API merge and branch-delete were unaffected.

REFLECTION. M3 was v0.2's first milestone and the first real CODE since M7, and
its shape was decided by the code, not the plan. The forcing question — validate
in the grammar (design §6) or the core (0019) — looked open until the survey found
that `vocabulary-tests.sps` ALREADY pinned the charset codes out of the scanner
set with a green, mutation-witnessed test: the code enforced core-placement, so
design §6's grammar-side note was the stale prose the project keeps warning about
(the byte-machine memory: the prose lags the code on the points that matter).
Placement was not a close call once the code was read. Three things then carried
the milestone. First, the oracle discipline scaled to a whole validating surface:
the product `(uri charset)` and a test-side `oracle-scan` are two INDEPENDENT
readings of the same ABNF, and the lane grades them into agreement on all 256
bytes × four components plus an exhaustive %XY sweep — two implementations of one
property that agree on every byte, which is the check M1 built the project to make.
The negative corpus was independently refuted against the ABNF before it was
trusted. Second, the one genuine engineering risk was the offset seam, and the
survey was right to say "witness, don't assume": the formula (stream-offset minus
the fragment width, at the first fragment) and its path-shape adjustments (a rooted
path begins one byte before its span; a mode-3 verdict rebases onto the leading
token) were PROBED against nine hand-counted inputs before a test asserted them,
then pinned and mutation-witnessed. Third — the milestone's sharpest catch, and the
recurring one — the merge-gate found what the per-slice work structurally could
not: the leftmost-error visit order was UNTESTED because every negative row had
exactly one bad component, so a permuted order survived green (M2's copy-discipline,
M5's empty-authority, M6's three resolve paths, M7's decorative smoke, and now this,
all the same family: a test green whether the code is right or wrong); and the new
lane executed the byte-machine runtime without fingerprinting it, a manifest-drift
gap. Both are now closed and witnessed. The one design call worth its own line —
`uri-parse` STAYS LENIENT, validation is the distinct `uri-parse-validate` entry —
was forced by M7 (its round-trip parses a malformed `%`), and the merge-gate caught
that 0024 hadn't recorded it. The settled pattern holds into v0.2: the per-slice
review catches within-slice bugs, and the merge-gate catches the coverage — and the
decision record — that a single slice cannot see about itself.

NEXT (M4 — the host grammar). The last milestone of the v0.2 validating surface:
sub-split the authority into userinfo/host/port and validate them — `reg-name`,
`IPv4address`, `IP-literal` → `IPv6address` / `IPvFuture`, and `port` (`*DIGIT`),
which M3 explicitly deferred (decision 0024 item 2). It unblocks the deferred half
of decision 0020 (host-case normalization) and finally lets the `port`/host charset
errors M3 named-but-left-to-M4 have a reachable path (0009 item 6). Design §6's M4
note (measure the `IPv6address` node count before committing; do NOT reserve the
`decision`-callback fallback) is the estimate to check against. Whether the split
is scanner-side or core-side is M4's forcing question, the analog of M3's — 0019
put the authority split in the core, so the likely answer is core, but read the
code first. Standing debts carried forward: the FIRST FUNDED CI RUN (0017 item 3,
still undischarged) and, only after M4 completes the validating surface, the
"RFC 3986 compliant" claim v0.1/v0.2 have not yet earned. The tree is clean on main
at 3686dc6.

================================================================================

M4 — THE HOST GRAMMAR (v0.2). Branch feat/m4-host-grammar.

Plan: .plans/2026-09-18-chez-uri-project-brief.md "M4 — the host grammar"
(userinfo/host/port sub-split; reg-name, IPv4address, IP-literal → IPv6address /
IPvFuture; port; host-case normalization) and .plans/2026-09-18-chez-uri-design.md
§6 (whose IPv6 node-count / decision-callback-fallback note this milestone
supersedes). Decisions in force: 0003 (RFC 3986 is normative, adjudicated against
the ABNF), 0005 (the corpus + oracle-from-RFC discipline; two provenances two
counts), 0007 (src is pure R6RS), 0009 (an error NAMES the ABNF production that
failed, and carries an offset; item 6 — a declared code needs a reachable path),
0010 (bytevectors), 0011 (M3/M4 are v0.2), 0012 (abnfgen + the mutator are deferred
v0.2 tooling), 0019 (items 3–5 — userinfo/host/port are NOT scanner spans, the host
grammar and its errors are the core's), 0020 (item 2 — host-case normalization
deferred to M4; CLOSED here), 0024 (M3's mirror; item 2 deferred port + every
authority-interior charset to M4).

Base at start: 3bfa51e (local main == origin/main; M3 merged 3686dc6, its close-out
3bfa51e). Measured environment (2026-09-19, Darwin arm64): Chez 10.4.1 (tarm64osx),
CMake/CTest 4.3.3. Baseline on the branch before any slice, RE-MEASURED: release
67/67, no-scheme 11/11, 0 failures.

THE FORCING QUESTION (the M4 analog of M3's, settled by an opening survey and
recorded as decision 0025): does the authority sub-split (userinfo/host/port + the
whole host grammar) live scanner-side or core-side? SETTLED BY THE CODE, CORE-SIDE,
NOT A CLOSE CALL — the exact M3 pattern. Three green, mutation-witnessed pins decide
it before a line of validator is written: (1) vocabulary.sls:82-83 + decision 0019
item 4 — userinfo/host/port are pure CORE functions over the opaque `authority`
bytevector, not scanner spans; (2) vocabulary-tests.sps:51-59 pins `authority` as
one span and `userinfo`/`host`/`port` as NOT spans, and :152-159 pins M4's exact
core error codes (invalid-userinfo, invalid-reg-name, invalid-ip-literal,
invalid-dec-octet, invalid-port) OUT of the scanner set; (3) uri-scanner.sls:137-147
— the authority span scans one undifferentiated loop recognizing only `#`/`/`/`?`
(the authority END), never `@`/`:`/`[`/`]` inside it. No host-grammar code exists
anywhere in src/. Design §6's M4 note sizes IPv6 as SCANNER work and predates 0019 —
stale prose (the byte-machine memory: the prose lags the code), superseded by 0025
in place. And a bonus over M3: collect.sls:119 ALREADY captures the authority's
absolute start offset (assemble-offsets / uri-parse-component-offset), so there is
NO offset seam to build — the validator returns an authority-relative index and the
shell rebases, exactly as M3's validate-result does.

THE ABNF (rfc3986.abnf:32-55, verbatim in decision 0025 item 2): authority =
[ userinfo "@" ] host [ ":" port ]; userinfo = *( unreserved / pct-encoded /
sub-delims / ":" ); host = IP-literal / IPv4address / reg-name; port = *DIGIT
(empty allowed); reg-name = *( unreserved / pct-encoded / sub-delims ); IP-literal =
"[" ( IPv6address / IPvFuture ) "]"; IPv4address = four dec-octets each 0-255;
IPv6address = the ::-compression counting grammar (≤8 h16, one optional ::, optional
trailing IPv4address as ls32); IPvFuture = "v" 1*HEXDIG "." 1*( unreserved /
sub-delims / ":" ).

THE THREE SUBTLETIES (M4's analog of M3's offset-seam + leftmost-error; decision
0025 items 3-4): (1) invalid-dec-octet is reachable ONLY inside brackets — §3.2.2
first-match-wins makes a bare bad dotted quad (999.1.1.1) a VALID reg-name, not an
error, so dec-octet/h16/group-count faults fire only within an IP-literal's
IPv6address where there is no reg-name fallback; the corpus must reach dec-octet
through `[...]`, never bare (0009 item 6). (2) The host/port split is bracket-aware:
split userinfo at the single `@` first (consuming userinfo's own `:`), then split
host/port at the `:` AFTER the closing `]` for an IP-literal, or the first `:` for
reg-name/IPv4 — `[::1]:80` → host `[::1]`, port `80`. (3) IPv6address is a COUNTER
(groups-seen, saw-`::`, per-h16 hex-digit-count, optional IPv4 tail), not a
transcription of the nine ABNF alternatives, and is M4's genuine engineering risk —
witnessed against a hand-counted valid/invalid IPv6 battery before a test trusts it
(M3's "witness, don't assume").

SCOPE DECISION SETTLED AT THE GATE: host-case normalization (decision 0020's
deferred §6.2.2.1a fold) is FOLDED INTO M4 as a final slice — the maintainer chose
"Fold into M4" over "validation only". Rationale: M4 is the last v0.2 milestone, so
deferring would orphan the fold and leave 0020's honesty obligation open; folding it
closes 0020's last §6.2.2.1 transform ("no rework, just a newly reachable
component"), drops the README host-case caveat, and lets v0.2 ship a COMPLETE
§6.2.2.1 normalizer. Recorded as decision 0025 item 8.

SLICE PLAN (cadence: drive to gates — stop after Slice ⓪ and at the merge gate;
subagents for surveys & reviews; Ultracode ON — Workflow for substantive slices):
  ⓪  This record + the design-§6 reconciliation + a NEW test-side ABNF oracle
     `(uri test host-oracle)` (an INDEPENDENT reading of the authority split + host
     grammar: userinfo/reg-name/port predicates, IPv4/dec-octet, IPv6/IP-literal/
     IPvFuture, plus oracle-scan-authority and the negative-corpus reader +
     cross-check) + a hand-derived negative corpus test/conformance/host/negative.scm
     + PROVENANCE. Every code reached by a REACHABLE path; dec-octet only through
     brackets; a two-fault authority pins userinfo→host→port order. No validator
     code. — GATE.
  ①  `(uri host)`: the bracket-aware authority split + the userinfo / reg-name /
     port / IPv4address / dec-octet validators (the non-IPv6 surface), pure over the
     authority bytevector, returning an authority-relative index; wired into
     component-bytes / validate-result / uri-parse-validate in (uri collect).
     Offsets WITNESSED against hand-counted authorities. Graded vs the oracle for the
     non-IPv6 surface + the non-IPv6 corpus rows. TDD, mutation witnesses.
  ②  The IPv6address / IPvFuture / IP-literal validators (the counter) + exhaustive
     oracle agreement over a hand-counted valid/invalid IPv6 battery + the
     bracket-only invalid-dec-octet / invalid-ip-literal corpus rows. — MERGE GATE.
  ③  Host-case normalization (decision 0020's close): normalize-components isolates
     the host (reusing (uri host)'s split) and applies ascii-downcase to the host
     ONLY; pin host lowercased AND userinfo case preserved; update
     normalize-components' doc + README's "will not claim" list to drop the
     host-case caveat.

SLICE ⓪ OPEN (2026-09-19): ledger seeded; branch feat/m4-host-grammar cut from
3bfa51e; baseline re-measured (release 67/67, no-scheme 11/11, 0 failures); the
opening survey (one Sonnet collector over the ABNF + design §6 + decisions
0019/0020/0024 + the scanner/collect/normalize wiring) came back and the forcing
question was settled core-side against the code (above); decision 0025 written (8
points), the design §6 M4 note superseded in place. AWAITING the maintainer's "Go"
to drive Slice ⓪ (the oracle + negative corpus + cross-check). — AT THE GATE.

SLICE ⓪ GATE (2026-09-19): the maintainer said "Go", and — before it — settled the
one open scope fork ("Fold into M4" over "validation only"), so host-case
normalization is M4 Slice ③ (decision 0025 item 8, recorded above).

SLICE ⓪ COMPLETE (2026-09-19). Landed decision 0025 + the design-§6 supersession +
the test-side oracle + the hand-derived negative corpus + the cross-check lane. No
src validator (that is Slices ①②③).
  - `(uri test host-oracle)` — an INDEPENDENT reading of RFC 3986 §3.2's authority
    grammar from the ABNF: the byte sets; oracle-scan-authority (bracket-aware
    userinfo/host/port split; reg-name/userinfo/port scans; the IPv6address COUNTER
    — ≤8 h16, one optional "::", optional trailing IPv4 as ls32 counting 2; IPvFuture;
    dec-octet 0-255 canonical); authority-of (a naive test-side extractor,
    independent of the src scanner); and the negative reader + negative-cross-check.
    All IP-literal-interior faults (incl. dec-octet range) report at the "[";
    userinfo/reg-name/port literal faults at the bad byte; malformed pct at the "%".
  - test/conformance/host/negative.scm (20 rows) + PROVENANCE — hand-derived from
    the ABNF, tagged (mode input component code offset note), ABSOLUTE offsets, every
    input "http://<auth>..." (authority at 7). Coverage: userinfo 3, reg-name 5, port
    3, ip-literal 5, dec-octet 2, pct 2. dec-octet reached ONLY through brackets; two
    multi-fault rows pin userinfo→host→port order (row 19 three-fault, row 20 two).
  - test/common/host-oracle-tests.sps + the uri.unit.host-oracle lane (source+aot);
    URI_HOST_DIR / URI_HOST_ORACLE_LIB added to test/CMakeLists.txt beside the M3
    charset pair.
  MUTATION WITNESSES (watched to fail, then restored): (1) a corpus offset 9→8 →
  cross-check reddens "oracle offset 9 (start 7 + relative 2) but the row records 8";
  (2) the IPv6 no-"::" total 8→7 → the valid 8-group and 6h16+IPv4-tail literals
  redden "expected (#f . #f), got (invalid-ip-literal . 0)" (needed a rebuild first —
  the source lane fingerprints the .sls, so an in-place edit trips the provenance
  guard, exit 3, not the assertion; the M3-noted source-lane-rebuild discipline); (3)
  a corpus code ip-literal→port → "code invalid-port does not name component
  ip-literal". A probe over 12 edge authorities (compression boundaries, leading/
  trailing lone colons, port-after-"]", IPvFuture, `user:pass@[::1]:443`, bare
  `999.999.999.999`) all matched the ABNF by hand.
  ORACLE DISCIPLINE: the corpus was INDEPENDENTLY REFUTED by a subagent that re-read
  the ABNF and hand-counted every offset — ALL 20 ROWS AGREE (input invalid, code =
  the failing production, component right, offset correct); claims A (bare dotted quad
  is a valid reg-name → dec-octet only in brackets), B (both dec-octet rows are
  well-shaped IPv6 whose sole fault is the range), C (both multi-fault rows exercise
  visit order) all upheld. Its one nit — row 2's note miscalled "<" a gen-delim —
  fixed (it is outside the URI charset). GRADED: release 69/69 (+2 host-oracle lanes
  over the 67 baseline), no-scheme 11/11, host-oracle + vocabulary seam-guard green.
  — AT THE SLICE ⓪ GATE (cadence: stop after Slice ⓪). Next: Slice ①.

SLICE ⓪ GATE (2026-09-19): the maintainer said "go" — committed as 3fde2a3.

SLICES ①② COMPLETE (2026-09-19). Driven together to the merge gate (a half-built
validator with a filtered corpus is the awkward state; the cadence's stop is the
merge gate). Landed `(uri host)` (the whole authority validator, incl. the IPv6
counter) + the shell wiring + the unit.host lane.
  - src/uri/host.sls — pure R6RS, imports only (rnrs) + (uri percent) (decision 0025
    item 5). validate-authority : Bytevector -> (values (Option code) (Option Nat)),
    authority-RELATIVE index. Bracket-aware split (userinfo at the single "@";
    host/port at the ":" after "]" for an IP-literal, else the first ":"); userinfo/
    reg-name/port scans reusing percent's unreserved-byte?/hex-digit-value; the host
    grammar inside "[" ... "]" — h16?, dec-octet (canonical, 0-255), ipv4, the
    count-pieces + dcolon IPv6 COUNTER (≤7 with "::", ==8 without), ipvfuture. All
    IP-literal-interior faults (incl. dec-octet range) reported at the "[". INDEPENDENT
    of the oracle: it uses percent's primitives where the oracle defines its own, so a
    charset mistake cannot be shared. (`find` renamed to find-byte — (rnrs lists)
    already binds `find`.)
  - src/uri/collect.sls — import (uri host); component-bytes gains (authority);
    validate-one dispatches authority→validate-authority, else validate-component;
    validate-result visits '(scheme AUTHORITY path query fragment) in input order and
    rebases the authority-relative index onto the ALREADY-captured authority start.
    uri-parse stays lenient; uri-parse-validate now judges the authority too.
  - test/common/host-tests.sps + the uri.unit.host lane (source+aot); host.sls added
    to URI_COLLECT.
  GRADING (unit.host): the six-code core vocabulary; validate-authority ⇄
  oracle-scan-authority agreement over a 45-shape battery PLUS three EXHAUSTIVE sweeps
  — dec-octet 0..300 (bracketed hits the 255/256 edge, bare stays a valid reg-name),
  h16 length 1..7 (≤4 valid), group-count 1..10 (==8 valid) — plus a "::"-total
  boundary battery; the negative corpus rejected exactly through uri-parse-validate
  (all 20 rows, code + ABSOLUTE offset); the positive corpora ACCEPTED (§1.1.2's eight
  incl. the ldap `[2001:db8::7]` IPv6 host, §5.4's 42 targets, seven explicit valid
  authorities incl. `user:pass@[::1]:8080`); a structural error still passes through.
  MUTATION WITNESSES (rebuilt each, source-lane fingerprint discipline): (1) the IPv6
  counter ≤7→≤8 → the `[...:7:8::]` and `[...:7::8]` boundary cases redden (src
  disagrees with the oracle — the agreement catches src-only bugs); (2) the shell
  offset rebase dropped (+off→+0) → every corpus offset reddens "expected 9, got 2"
  (the authority-relative index, absolute-7). Two boundary battery rows were ADDED
  first so the "::" rule was actually pinned before the mutation. GRADED: release
  71/71 (+2 unit.host lanes), no-scheme 11/11. The existing charset/round-trip/
  resolution positive corpora stay green now that authority validation is live on
  every uri-parse-validate. — AT THE MERGE GATE (cadence: stop). Next: the merge-gate
  adversarial review (a Workflow), then Slice ③ (host-case normalization).

M4 MERGE-GATE VERIFICATION (2026-09-19, at the merge gate — the VALIDATION surface,
Slices ⓪①②; Slice ③ still to come). A five-dimension adversarial review Workflow
(Ultracode): reviewers over ABNF correctness, offset correctness, oracle independence,
shell wiring/regression, and record accuracy, each finding fed to a default-refute
verifier — 10 agents. Result: 5 findings, 1 CONFIRMED, 4 REFUTED; the ABNF-correctness,
offset-correctness and wiring-regression dimensions came back CLEAN (no code defect in
the validator or the shell).
  CONFIRMED (minor, records): row 19 "us er@ho st:8x" is a THREE-fault authority
  (userinfo, host AND port — as its own note says), so the "TWO-FAULT authorities"
  label was wrong. Fixed the prose in negative.scm's header, PROVENANCE, and this
  ledger (row 19 three-fault, row 20 two-fault); the test assertion (leftmost userinfo
  fault @9) was already correct.
  TWO REFUTED-BUT-LEGITIMATE COVERAGE GAPS CLOSED (the recurring merge-gate lesson —
  what a slice cannot see about itself): (1) the "::"-total ≤7 rule had NO independent-
  corpus witness — only src↔oracle agreement, which a SHARED 7→8 mutation survives — so
  added corpus row `[1:2:3:4:5:6:7:8::]` → invalid-ip-literal @7, and WITNESSED it:
  under ≤7→≤8 the row now reddens through uri-parse-validate (code expected
  invalid-ip-literal, got #f), an independent guard the agreement alone did not give.
  (2) IPvFuture had ZERO corpus rows — added `[v1z]` → invalid-ip-literal @7, plus seven
  IPvFuture agreement-battery cases (v./v1./vG./V2.a:b/v1a.x-y~z) and two valid IPvFuture
  positives. Corpus 20 → 22 rows (ip-literal 5 → 7).
  REFUTED, no change (verified as non-defects): the "shared-bug" independence critique
  (a test-methodology observation, not a live defect — the code is correct and the
  third artifact, the corpus, now guards the ::-boundary too); an "@"-inside-brackets
  code choice (`[a@b]` → invalid-userinfo) — the DOCUMENTED "@-first" split (0025 item
  4), correctly rejects, oracle-consistent; and a temporal "does not exist yet" note in
  the oracle header — accurate as of Slice ⓪ authorship. GRADED after the fixes: release
  71/71, no-scheme 11/11. — STILL AT THE MERGE GATE. Next: Slice ③ (host-case
  normalization, decision 0025 item 8), then the closing ritual (ask first).

SLICE ③ COMPLETE (2026-09-19). Host-case normalization — decision 0025 item 8,
CLOSING decision 0020's last deferred §6.2.2.1 transform. The last M4 slice.
  - src/uri/host.sls — new export `authority-host-span : Bytevector -> (values Nat
    Nat)`, the host [start,end) by the SAME bracket-aware split as validate-authority
    (host after "@"; ends at "]" for an IP-literal, else the port ":", else the end).
  - src/uri/normalize.sls — imports (uri host); `downcase-host` folds ONLY the host
    span's LITERAL bytes to lowercase, SKIPPING each "%XX" triplet so its hex stays
    uppercase (§6.2.2.1b) — userinfo stays case-sensitive, port is digits.
    `normalize-authority` = pct-normalize THEN downcase-host (percent first, so a
    reserved-decoding %XX never synthesizes a delimiter that moves the host span);
    normalize-components' authority field uses it. Docs updated (the "host case
    deferred" caveat dropped; ascii-downcase now feeds the host fold too).
  - test/common/normalize-tests.sps — the decision-0020 host-case-PRESERVED pin
    FLIPPED to host-case-NORMALIZED: `HTTP User:S3cret@Example.COM` → `http
    User:S3cret@example.com` (host folded, userinfo preserved); added an IPv6 host
    fold (`[2001:DB8::Ab]:80` → `[2001:db8::ab]:80`) and the pct-interaction pin
    (`Us%7Er@H%2Fx` → `Us~r@h%2Fx`: host literal folds, %2F hex stays upper, userinfo
    Us~r preserved). Header + the unit.normalize CMake comment updated.
  - test/CMakeLists.txt — host.sls added to the unit.normalize lane's source list
    (the resolution + round-trip lanes already carry it via URI_COLLECT).
  MUTATION WITNESSES: (1) fold from authority index 0 instead of the host start →
  userinfo reddens (byte 85 "U"→117 "u", 83 "S"→115 "s"): starting at the host span
  is what protects case-sensitive userinfo (decision 0020's whole point); (2) the
  "%XX" skip removed (advance 1 not 3) → `%2F`→`%2f` (70 "F"→102 "f"): the triplet
  skip preserves §6.2.2.1b's uppercase hex.
  HONESTY OBLIGATION: discharged IN THE CODE (normalize.sls doc + the flipped test);
  the USER-FACING README/CHANGELOG claim-drop rides with the v0.2 RELEASE, not M4
  merge — README.org is stamped "v0.1.0 — released" and describes the frozen tag
  (which does not normalize host case), and M3 set the precedent (charset validation
  merged without touching the release-scoped README). Decision 0025 item 8 amended to
  record this timing.
  GRADED: release 71/71, no-scheme 11/11. Round-trip + resolution stay green (their
  corpora have lowercase hosts, so host-case is a no-op there; the property is
  idempotent under the added fold). — M4 IS FEATURE-COMPLETE (⓪①②③): the validating
  surface AND decision 0020's last normalization gap are closed. AT THE CLOSING-RITUAL
  GATE (AGENTS.md: ALWAYS ask before running the closing ritual).

M4 MERGED (2026-09-19). PR #12 squash-merged to main as 04bf52a; local main
fast-forwarded (3bfa51e..04bf52a); feat/m4-host-grammar deleted local and remote.
Merged over a RED linux-amd64 check, confirmed the documented Actions billing refusal
(decision 0017 — `gh run view`: the job "was not started because recent account
payments have failed", 2s, so no test ever ran), not a test result; local macOS-arm64
evidence stands (release 71/71, no-scheme 11/11). The maintainer authorised the
closing ritual explicitly. The branch was local until the ritual, so the ritual also
pushed it and opened PR #12; every push went over HTTPS via `gh auth git-credential`
(the SSH agent stayed broken this session); the API merge and branch-delete were
unaffected.

REFLECTION. M4 was v0.2's second and last milestone, and its lesson is that the
project's disciplines are now REPEATABLE, not lucky. The forcing-question pattern held
a THIRD time: "scanner-side or core-side?" was settled by the code (vocabulary.sls +
the green vocabulary-tests.sps pin naming the core host codes) before a line of
validator, and design §6's IPv6-node-count note was again the stale prose the project
keeps warning about (superseded in place by decision 0025, as 0024 did for charset).
Placement was not a close call — read the code, not the plan. Three things then
carried the milestone. First, the oracle discipline reached its full THREE-provenance
form: the src `(uri host)` (reusing percent's primitives), the test `(uri test
host-oracle)` (its own byte sets), and the hand-derived corpus (independently refuted
against the ABNF, all rows agreeing). The merge-gate review found the ONE place this
mattered — the IPv6 "::"-total ≤7 rule was witnessed only by src↔oracle agreement, a
TWO-provenance guard a shared 7→8 mutation survives; adding an independent corpus row
(watched to redden through uri-parse-validate under that mutation) made it three. The
sharpened rule: "agreement is the check" only holds when a THIRD, independently
authored artifact guards the shared-bug blind spot. Second, the genuine engineering
risks — the IPv6 counter (≤8 pieces, one "::", IPv4 tail as 2), the bracket-aware port
split ([::1]:80), the authority offset rebase, and Slice ③'s host fold that must touch
ONLY the host (userinfo is case-sensitive) while SKIPPING %XX triplets (§6.2.2.1b keeps
their hex uppercase) — were each witnessed to fail under mutation before being trusted,
the byte-level diffs (85 "U"→117 "u"; 70 "F"→102 "f") making the property concrete.
Third — the recurring catch — the merge-gate found what the per-slice work structurally
could not (the ::-total independent-witness gap and IPvFuture's zero corpus rows), the
same family as M2's copy-discipline, M3's leftmost-error, M5's empty-authority: coverage
a slice cannot see about itself, and now closed. One honesty call worth its own line:
the README/CHANGELOG "complete §6.2.2.1 normalizer" claim was DEFERRED to the v0.2
release rather than dropped at M4 merge — the README describes the frozen v0.1.0, and
M3 set the precedent by merging charset validation without touching it; the code's own
doc and the flipped test discharge 0020's obligation now, the user-facing claim when
v0.2 ships. The settled pattern holds to the end of v0.2: per-slice review catches
within-slice bugs; the merge-gate catches the coverage — and the decision record — a
single slice cannot see about itself.

NEXT (the v0.2 RELEASE — the M8 analog for v0.2). v0.2's implementation is COMPLETE:
M3 (charset validation) and M4 (the host grammar + host-case normalization) are both
merged, so `uri-parse-validate` now judges every component's charset and the whole host
grammar, and `normalize-components` performs all of §6.2.2.1 (scheme + host case +
percent). What remains is to RELEASE it, the way M8 released v0.1: reconcile the
release-scoped docs (drop README.org's "charset and host-grammar validation are v0.2"
and "not host case" caveats; write the CHANGELOG [Unreleased] → [0.2.0] section
covering M3 + M4; bump the version), re-measure on the release commit, and cut an
annotated v0.2.0 tag on disclosed local evidence (decision 0023's amendment governs —
CI has still never run). Two standing debts carry in: the FIRST FUNDED CI RUN (0017
item 3, still undischarged — v0.2, like v0.1, would release on macOS-arm64-local
evidence with the Linux cell billing-refused) and the "RFC 3986 compliant" claim, which
is now EARNABLE-pending-audit — the validating + normalizing + resolving surface is
complete, but the full compliance claim needs its own audit, not an automatic grant
from M4. The tree is clean on main at 04bf52a.

---

M9 — THE AUTHORITY-FORM PARSE (issue #9, RFC 9112 §3.2.3). Branch
feat/m9-authority-form.

Plan: decision 0026 (this milestone's record); the brief §"The one hard design
question" (RFC 9112's four request-target forms) and §"Out of scope" (the WHATWG-URL
"separate machine" line 0026 distinguishes authority-form from); the design §5 (the
`(uri collect)` shell). Decisions in force: 0004 (the mode field selects an RFC 3986
production — authority-form has none, so no mode reaches it), 0009 (an error names the
rule it enforces + an offset), 0011 (the lenient-parse / separate-validate split this
mirrors), 0019 (the core/shell owns what the forward-only scanner has no clean
production for), 0024 (the offset seam — `uri-parse-component-offset`), 0025
(`(uri host)`'s `validate-authority` / `authority-host-span`, reused here), and NEW
0026 (authority-form is a shell splice, parsed lenient + validated strict).

Base at start: 616415e (local main == origin/main; M4 merged as 04bf52a, its
close-out 616415e). Measured environment (2026-09-19, Darwin arm64): Chez 10.4.1
(tarm64osx), CMake/CTest 4.3.3. Baseline on the branch before any slice: release
71/71, no-scheme 11/11, 0 failures.

THE MAINTAINER'S TWO SCOPE CALLS (AskUserQuestion, before decision 0026 was written):
(1) API surface — the LENIENT + VALIDATING PAIR (mirror uri-parse / uri-parse-validate),
over lenient-only or strict-only; (2) sequencing — FOLD INTO v0.2 (build M9 to main,
then the v0.2 release tags it with M3 + M4), over tag-v0.2-first. Both recorded in 0026
(items 2, 7).

WHAT M9 SHIPS (decision 0026): NO new `src/` library — two exports on `(uri collect)`
plus three authority-form error codes, reusing `(uri host)` and the offset seam.
  - `uri-parse-authority-form : Bytevector -> uri-parse-result` — the LENIENT structural
    parse: splice `//`, parse `relative-ref`, re-map offsets by −2, reject a non-empty
    path / present query / present fragment as `not-authority-form`. Lenient within the
    authority (userinfo, missing port, charsets NOT judged), like uri-parse.
  - `uri-parse-authority-form-validate : Bytevector -> uri-parse-result` — the STRICT
    RFC 9112 form: the lenient parse, then `userinfo-forbidden` (via authority-host-span),
    then `validate-authority` over the host:port, then `port-required`; leftmost-ordered.
  - `uri-authority-form-error-codes` / `uri-authority-form-error-code?` — the three new
    codes (`not-authority-form`, `userinfo-forbidden`, `port-required`), RFC 9112 codes
    living with the parser, distinct from the scanner and host vocabularies.

THE FORCING QUESTION IS ALREADY ANSWERED — a fourth machine, or the shell splice? The
splice, and it is not close. Authority-form has NO RFC 3986 production (0004's three
modes are RFC 3986 productions), but it is NOT a WHATWG-style divergence (the brief
reserves "a separate machine" for a different normative reference): it reuses RFC 3986's
own `host`/`port`, so it is "an RFC 3986 authority in isolation." A survey (one Sonnet
collector over RFC 9112 §3.2.3 + collect.sls/vocabulary.sls + an 11-input splice probe)
confirmed the mechanics decide it: `//<input>` in relative-ref mode puts the authority
at offset 2 in EVERY case, no structural error falls in the `//` prefix (so −2 is
uniform and never negative), and only a trailing `/p` / `?q` / `#f` yields a non-empty
path/query/fragment. Decision 0019's line extends: the scanner does the coarse split,
the shell owns the authority-form reach.

EXIT CRITERION: a CONNECT server can parse an authority-form request-target — the
lenient form returns the components (rejecting non-authority-form input), the `-validate`
form holds it to RFC 9112 §3.2.3 (no userinfo, real port, valid host). Graded against a
hand-derived authority-form corpus (valid CONNECT targets + one rejection row per code,
exact code + ABSOLUTE offset in ORIGINAL coordinates). The −2 re-map invariant and the
lenient/strict divergence are each mutation-witnessed. This does NOT touch the
release-scoped README OR CHANGELOG (0026 item 7 — like M3/M4, the CHANGELOG
`[Unreleased]` is left empty and the v0.2 release consolidates M3 + M4 + M9).

SLICE PLAN (cadence: drive to gates — stop after Slice ⓪ and at the merge gate;
subagents for the survey (done) and the merge-gate adversarial review):

  ⓪  `uri-parse-authority-form` — the LENIENT parse: the `//` splice, the −2 offset
     re-map (both the offsets alist and error-offset), and the `not-authority-form`
     structural floor (reject a present path/query/fragment). The three error codes +
     their predicate. The hand-derived authority-form corpus + PROVENANCE (labelled,
     counted apart — 0026 item 6). Witnesses: the −2 re-map (drop it → offsets redden
     by 2) and the lenient/strict divergence stub (a userinfo input parses lenient).
     Pure `(rnrs)` shell; source+aot lane; TDD. — GATE.
  ①  `uri-parse-authority-form-validate` — the STRICT RFC 9112 form: `userinfo-forbidden`
     (via authority-host-span) → `validate-authority` (host:port) → `port-required`,
     leftmost-ordered, offsets in ORIGINAL coordinates. Graded over the corpus (every
     row rejected with its exact code + offset; the valid CONNECT targets accepted by
     BOTH). Mutation witnesses (the leftmost order; the port-required boundary `host:`
     vs `host`). CHANGELOG deferred to the v0.2 release (0026 item 7, amended). — MERGE GATE.
  CLOSE — merge-gate adversarial review (a Workflow) + closing ritual (ask first) +
  reflection.

SLICE ⓪ OPEN (2026-09-19): ledger seeded; branch feat/m9-authority-form cut from
616415e; baseline re-measured (release 71/71, no-scheme 11/11, 0 failures); the opening
survey (Sonnet) came back and the forcing question was settled shell-side against the
probe (above); decision 0026 written (7 points); issue #10 closed as resolved by M4
(uri-parse-validate rejects SP/CTL in the authority). AWAITING the maintainer's "Go" to
drive Slice ⓪ (the lenient parse + corpus + witnesses). — AT THE GATE.

SLICE ⓪ GATE (2026-09-19): the maintainer said "Go through slice one" — drive Slice ⓪
AND Slice ① to the merge gate (the whole authority-form pair is one interconnected
shell artifact; a half-built pair is the awkward state, as M4's ①② were).

SLICES ⓪① COMPLETE (2026-09-19). The RFC 9112 §3.2.3 authority-form pair on
`(uri collect)` — NO new src library, decision 0026.
  - src/uri/collect.sls — two exports + three error codes. `uri-parse-authority-form`
    (LENIENT): splice "//" (splice-slashes), parse relative-ref, unsplice every offset
    by −2 (unsplice-result — the offsets alist AND error-offset), reject a trailing
    path/query/fragment as `not-authority-form` at the authority's length (auth starts
    at 0 after unsplicing). `uri-parse-authority-form-validate` (STRICT): the lenient
    parse, then LEFTMOST — `userinfo-forbidden` (via authority-host-span: host start > 0
    ⇒ a "@" precedes it, reported there) → `validate-authority` (the RFC 3986 host
    grammar, reused from M4) → `port-required` (no ":" or an empty port, at the end).
    `uri-authority-form-error-codes` / `-error-code?` — the three RFC 9112 codes, living
    with the parser, distinct from the scanner and host vocabularies. All reuse
    (uri host) (imported since M4); no scanner/grammar/artifact change.
  - test/conformance/authority-form/corpus.scm (17 rows) + PROVENANCE — hand-derived
    from §3.2.3 (RFC 9112 is NOT vendored), grading BOTH entry points per row (input
    lenient strict note), offsets in the caller's coordinates (no "//" prefix, authority
    at 0). Classes by STRICT outcome: 4 valid CONNECT targets (DNS/IPv6/IPv6+IPv4-tail/
    IPv4), 3 not-authority-form (trailing path/query/fragment), 4 userinfo-forbidden
    (`user@host:443`; the two leftmost rows `user@ho st:443`/`user@host` where userinfo
    beats a host/port fault; and `user@[::1]:443`, a real userinfo before an IP-literal),
    3 port-required (`host`, `host:` — the empty-port RFC 3986/9112 boundary — and the
    empty target `""`), 2 invalid-reg-name (`ho st:443`, and `ho st` which pins host <
    port), 1 invalid-userinfo (`[a@b]:443`, an "@" inside a literal — bracket-aware, NOT
    userinfo-forbidden). The `:443` empty-host
    ABNF edge is documented in PROVENANCE, deliberately not a row (0003 — the ABNF
    permits an empty reg-name). NO fourth oracle: the host grammar rides M4's
    three-provenance guard; authority-form's own policy is guarded by this table + the
    mutation witnesses.
  - test/common/authority-form-tests.sps + the uri.unit.authority-form lane
    (source+aot); URI_AUTHORITY_FORM_DIR added to test/CMakeLists.txt beside the M4
    host pair. The test reads the corpus directly (open-file-input-port + get-datum), so
    the lane needs URI_COLLECT + the generated parser but no oracle/corpus harness libs.
  FOUR MUTATION WITNESSES (each rebuilt — the source lane fingerprints the .sls, so an
  in-place edit needs `make build` to reach the assertion, not the provenance guard):
  (1) the −2 re-map dropped (−2 → −0) → "authority offset is 0" reddens "expected 0, got
  2"; (2) the userinfo guard disabled (`(fx>? hs 0)` → `#f`) → `user@ho st:443` reports
  the host fault (invalid-reg-name @7) instead of the LEFTMOST userinfo-forbidden @4, and
  the other userinfo rows flip — the leftmost order is load-bearing; (3) the port
  boundary loosened (`fx<?` → `fx<=?`) → `host:` (empty port) wrongly passes strict
  (RFC 3986 accepts an empty *DIGIT port; RFC 9112 does not) — the corpus + divergence
  rows redden; (4) the `not-authority-form` floor disabled (`(and #f ...)`) → the
  trailing path/query/fragment rows redden under BOTH functions. Each reverted; a
  15-input probe over both functions confirmed every verdict before the corpus was
  written. GRADED: release 73/73 (+2 authority-form lanes over the 71 baseline),
  no-scheme 11/11, 0 failures. CHANGELOG deferred to the v0.2 release (0026 item 7). — AT
  THE MERGE GATE (cadence: stop). Next: the merge-gate adversarial review (a Workflow),
  then the closing ritual (ask first).

M9 MERGE-GATE VERIFICATION (2026-09-19). A five-dimension adversarial review Workflow
(Ultracode): reviewers over RFC 9112/3986 correctness, offset correctness, splice edge
inputs, shell wiring/regression, and test/decision fidelity, each finding fed to a
default-refute verifier — 10 agents, ~974k subagent tokens. Result: 5 confirmed findings,
0 refuted; the offsets, splice-edges, and wiring dimensions found no CODE defect in the
validator itself beyond the one below.
  A PROCESS NOTE FIRST: one adversarial-verify agent errored on its OWN output schema
  (StructuredOutput retry cap — it kept omitting the required `evidence` field), which
  dropped its finding from the aggregated result. That finding was the SOLE code defect,
  from the rfc-correctness dimension; it was recovered by reading the workflow
  journal.jsonl (the per-agent record) rather than trusting the summary — the discipline
  the workflow tool itself names. Lesson banked: a verify-agent schema failure can
  silently swallow a real finding; check the journal when agents_error > 0.
  ONE CODE DEFECT (should-fix, rfc-correctness), FIXED: the strict userinfo pre-check
  used a bare first-"@" scan (via authority-host-span's host start), so a "@" INSIDE an
  IP-literal — `[a@b]:443`, `[v1.x@y]:443` — mis-fired `userinfo-forbidden` at the
  bracketed "@" instead of deferring to the host grammar. Fixed with a BRACKET-AWARE rule
  (a genuine userinfo "@" is one before the first "[", per RFC 3986 §3.2.2 — an "@" in a
  literal is not a delimiter); `[a@b]:443` now falls through to validate-authority →
  invalid-userinfo@0 (as M4 reports for http://[a@b]), while `user@[::1]:443` (a real
  userinfo before the "[") stays userinfo-forbidden@4. Two corpus rows added (both
  directions), WITNESSED: dropping the bracket guard reddens `[a@b]:443` (got
  userinfo-forbidden@2, expected invalid-userinfo@0). Decision 0026 item 4 amended.
  ONE COVERAGE GAP (should-fix, test-fidelity), CLOSED: the leftmost host < port link was
  UNPINNED — a validator that checked port-required BEFORE validate-authority passed all
  14 rows yet returned port-required@5 for `ho st` (bad host, no port) instead of the
  leftmost invalid-reg-name@2. The two existing leftmost rows only pinned userinfo > host
  and userinfo > port (both short-circuit on userinfo-forbidden). Added the `ho st` row
  (bad host, NO port), WITNESSED: the port-before-host reorder now reddens it. PROVENANCE's
  "pin userinfo -> host -> port" overclaim softened to name which row pins which link.
  THREE RECORD NITS, FIXED: (1) the ledger EXIT CRITERION said the CHANGELOG `[Unreleased]`
  "gains M9's entry", contradicting the amended 0026 item 7 (and the slice plan 17 lines
  down) — reconciled to "left empty, consolidated at the v0.2 release"; (2) the ledger
  class enumeration summed to 13 for a 14-row corpus (the empty-target row dropped, port
  counted as 2 not 3) — rewritten, now accurate for the 17-row corpus; (3) decision 0026
  item 4(b) described `validate-authority` running "over the host:port tail only" after a
  userinfo fault, a step the code does not perform (it short-circuits) — rewritten to
  match, folding in the bracket-aware correction. GRADED after the fixes: release 73/73,
  no-scheme 11/11, 0 failures; authority-form corpus 17 rows / 87 checks. SIX mutation
  witnesses total (the four from Slices ⓪①, plus bracket-awareness and the host < port
  reorder). — STILL AT THE MERGE GATE. Next: the closing ritual (ask first).

THE RECURRING MERGE-GATE LESSON HELD, TWICE OVER. The per-slice work could not see either
gap about itself: a real CODE defect (the bracketed-"@" misfire — an edge no corpus row
reached) AND a coverage hole (host < port unpinned — every green row survived the reorder).
Same family as M2's copy discipline, M3's leftmost error, M4's ::-total and IPvFuture, M5's
empty authority. And a new wrinkle: the adversarial VERIFIER can drop a finding on its own
schema error, so the journal — not the summary — is the source of truth when an agent errors.

M9 MERGED (2026-09-19). PR #13 squash-merged to main as a58e606; local main fast-forwarded
(616415e..a58e606); feat/m9-authority-form deleted local and remote; issue #9 auto-closed by
the merge ("Closes #9"). Merged over a RED linux-amd64 check, confirmed the documented
Actions billing refusal (decision 0017 — `gh run view` + the jobs API: "The job was not
started because recent account payments have failed", 0 steps, 3s, 20:23:24→20:23:27), not a
test result; local macOS-arm64 evidence stands (release 73/73, no-scheme 11/11). The
maintainer authorised the closing ritual explicitly. Every push went over HTTPS via
`gh auth git-credential` (the SSH agent stayed broken this whole session); the API merge and
branch-delete were unaffected.

REFLECTION. M9 was a small, additive milestone born from a sibling repo's issue (#9), and
its lessons are about REACH and DISCIPLINE, not size. Three things stand out. First, the
forcing-question pattern held a FOURTH time — "a fourth machine, or a shell splice?" was
settled by the code and an 11-input probe, not the plan: authority-form has no RFC 3986
production (decision 0004's three modes are RFC 3986 productions), but it REUSES RFC 3986's
own host/port, so it is "an authority in isolation", not a WHATWG-style separate machine
(the brief's out-of-scope line). The `//` splice through the existing relative-ref machine
was the honest reach, and decision 0019's core/shell-owns-the-authority seam paid off:
authority-form validation is a thin policy on top of M4's `(uri host)` (validate-authority,
authority-host-span), with NO host.sls or scanner change. Second, the lenient/validate PAIR
extended decision 0011's split (uri-parse / uri-parse-validate) to a new entry point cleanly
— the same "lenient splitter + separate validator" shape, now for a request-target form.
Third — and the milestone's real teacher — the merge gate again caught what the slice could
not see about itself, TWICE: a genuine CODE defect (the bracketed-"@" misfire, an edge no
corpus row reached, that mis-fired userinfo-forbidden inside an IP-literal) AND a coverage
hole (host < port unpinned, which every green row survived). Both fixed and witnessed. The
NEW, transferable lesson is one layer up: the adversarial VERIFIER itself dropped that code
defect from the aggregated result on its OWN output-schema error — so when a review workflow
reports agents_error > 0, the per-agent journal.jsonl, not the summary, is the source of
truth. The workflow-authoring reference says as much for empty results; M9 is the case where
it mattered for a NON-empty, wrong-because-incomplete result. The disciplines held to the
end of v0.2's feature work: oracle/corpus from the spec, every property witnessed failing,
and the merge gate as the backstop for what a single slice is blind to.

NEXT (the v0.2 RELEASE — unchanged, now three milestones deep). v0.2's implementation is
COMPLETE: M3 (charset validation), M4 (the host grammar + host-case normalization), and M9
(authority-form) are all merged. `uri-parse-validate` judges every component and the whole
host grammar; `normalize-components` performs all of §6.2.2.1; and `(uri collect)` now also
parses RFC 9112 authority-form targets (lenient + strict). What remains is to RELEASE it, the
way M8 released v0.1: reconcile the release-scoped docs (drop README.org's "validation is
v0.2" / "not host case" caveats AND note the new authority-form entry points; write the
CHANGELOG [Unreleased] → [0.2.0] section covering M3 + M4 + M9; bump the version), re-measure
on the release commit, and cut an annotated v0.2.0 tag on disclosed local evidence (decision
0023's amendment governs — CI has still never run). The two standing debts carry in unchanged:
the FIRST FUNDED CI RUN (0017 item 3, still undischarged) and the "RFC 3986 compliant" claim,
EARNABLE-pending-audit — now with an even larger validating/normalizing/resolving/authority-
form surface, but still needing its own audit, not an automatic grant. The tree is clean on
main at a58e606.

---

THE v0.2 RELEASE — the M8 analog for v0.2. Branch chore/v0.2.0-release.

Plan: the release ACT, its checklist DERIVED (as 0023 derived M8's) against the reconciled
tree. Decisions in force: 0017 (CI has never run — each release on it needs its own
amendment), 0023 (the v0.1 release template — tag semantics, structural doc reconciliation,
the honest claim, the never-run-CI amendment, the re-measure gate, publish steps gated per
action), 0024/0025/0026 (M3/M4/M9 — what the release now claims), and NEW 0027 (the v0.2
release amendment: annotated tag v0.2.0, still on never-run CI, does NOT yet claim RFC 3986
compliance).

Base at start: 1147724 (local main == origin/main; M9 merged as a58e606, its close-out
1147724). Measured environment (2026-09-19, Darwin arm64): Chez 10.4.1 (tarm64osx),
CMake/CTest 4.3.3. Baseline on the branch before reconciliation: release 73/73, no-scheme
11/11, 0 failures.

WHAT THE RELEASE SHIPS (decision 0027): NO algorithm, NO new src/, NO new lane — the
documentation reconciliation, decision 0027, this close-out, and the annotated tag v0.2.0.
The shipped src/ is byte-identical to M9's.
  - CMakeLists.txt VERSION 0.1.0 → 0.2.0 (the libraries stay unversioned — an R6RS version
    field is a breaking import change, 0023 item 2).
  - README.org — status → v0.2.0; the summary gains M3 (validation), M4 (host grammar +
    host-case normalization), M9 (authority-form); the two EARNED caveats are rewritten to
    state what v0.2 DOES (uri-parse-validate now validates charsets + host grammar;
    normalize completes §6.2.2.1 host case), while the STILL-TRUE boundaries stay — the
    CI-not-run quote, strict resolution, the round-trip §4.2/§3.3 boundary, not-portable,
    and the not-blanket-"RFC 3986 compliant" clause (rewritten: earnable via a whole-ABNF
    audit, not granted). The parsing section and the src layout gain the new entry points.
  - CHANGELOG.md — [Unreleased] → [0.2.0] - 2026-09-19 (fresh empty [Unreleased] above),
    with M3/M4/M9 sections in the measured, mutation-witness voice of the [0.1.0] entry, a
    preamble disclosing CI-never-ran + the re-measured counts + the deferred compliance
    claim, and the version link refs updated. The frozen [0.1.0] entry is untouched.

THE HONEST CLAIM (0027 item 4): v0.2 now VALIDATES (uri-parse-validate judges every
component's charset AND the whole host grammar), COMPLETES §6.2.2.1 normalization (host
case), and parses RFC 9112 authority-form — over v0.1's lenient splitter + strict resolver +
complete core. uri-parse itself stays lenient by design. It does NOT claim blanket "RFC 3986
compliant": that is a whole-ABNF conformance audit not yet run — earnable and nearer, not
granted. CI has STILL never run (0017 item 3 OPEN, disclosed in the release body, not
waived); 0027 is the amendment that ratifies releasing v0.2 on macOS-arm64-local evidence,
the successor to 0023 as 0023 was to 0017.

RE-MEASURE (2026-09-19, on the reconciled tree): release 73/73, no-scheme 11/11, 0 failures
(Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3). The doc changes touch no lane. The
official 0023-item-6 gate re-measures again AT the tag commit after the merge. — AWAITING the
publish ritual under the maintainer's "Do it" ratification (0027 item 7): push, PR, confirm
the billing refusal, squash-merge, re-measure at the tag commit, cut + push the annotated
v0.2.0 tag.

v0.2.0 RELEASED (2026-09-19). The maintainer ratified the release ("Do it"). PR #14
squash-merged to main as f359743; local main fast-forwarded (1147724..f359743);
chore/v0.2.0-release deleted local and remote. Merged over a RED linux-amd64 check, confirmed
the documented Actions billing refusal (decision 0017 — 0 steps, 3s, "the job was not started
because recent account payments have failed"), not a test result. The release GATE was
RE-MEASURED at f359743 (the tag commit): release 73/73, no-scheme 11/11, 0 failures (Darwin
arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3), exercising both the source and AOT lanes and
every audit and mutation suite. The annotated tag v0.2.0 (unsigned — signing is the
maintainer's key operation, 0027 item 2; tag object b24408b → f359743) was cut on f359743
carrying the disclosed evidence (the CI-never-ran fact + the counts + the deferred compliance
claim) in its message, and pushed to origin over HTTPS (the SSH agent stayed broken this whole
session; the API merge, branch-delete and tag push were unaffected). v0.1.0 stays frozen at
264c997. No GitHub Release was cut — optional and separately gated (0027 item 7); the gitlink
pin needs only the pushed tag, and its body, if wanted, is the CHANGELOG [0.2.0] section
verbatim.

REFLECTION. The v0.2 release was the M8 analog, and it landed as a REPEATABLE ritual rather
than a one-off: decision 0027 is the v0.2 successor to 0023 (as 0023 was to 0017), the doc
reconciliation was structural (drop the EARNED caveats, keep the STILL-TRUE boundaries
verbatim), and the tag carried disclosed local evidence — the same shape as v0.1, now second
time through. Two things are worth their own line. First, the deferred claim-drops from M4
(0025 item 8) and M9 (0026 item 7) landed here EXACTLY as designed: each feature milestone
merged without touching the release-scoped README/CHANGELOG (keeping the frozen v0.1.0 docs
honest), and the release consolidated them into one [0.2.0] section and one README rewrite.
The discipline of deferring the user-facing claim to the release paid off — no released tag
ever over-claimed. Second, the one real judgment call — "RFC 3986 compliant" — was settled by
the house rule "a property is measured or it is not claimed", now applied to a claim that is
EARNABLE, not absent: v0.2 genuinely VALIDATES (uri-parse-validate judges every component's
charset AND the whole host grammar) and fully NORMALIZES §6.2.2.1, so the surface is complete
and measured — but "compliant" is a whole-ABNF conformance audit that has NOT run, so the
release says "earnable and nearer, not granted" rather than either hiding the progress or
over-claiming it. CI has STILL never run, disclosed in the release body (0027, the successor
to 0023→0017), not waived.

NEXT (v0.2 is DONE; what reopens is a SEPARATE choice, not a v0.2 gap). v0.2's entire arc —
M3 (charset validation), M4 (host grammar + host-case normalization), M9 (authority-form) —
is merged, released, and tagged v0.2.0 on f359743. Three distinct directions are now open,
each its own decision: (1) the RFC 3986 CONFORMANCE AUDIT — a systematic accept/reject sweep
against the collected ABNF that could EARN the "RFC 3986 compliant" claim 0027 deferred; (2)
the FIRST FUNDED CI RUN — discharging 0017 item 3, replacing the macOS-arm64-local disclosure
with cross-platform evidence; (3) v0.3 FEATURES — e.g. the deferred abnfgen positive generator
and host-aware mutator (0012), a relative-reference serializer above recompose (0022), or the
sibling's next request. The two sibling-repo issues filed this session are both resolved:
#10 (SP/CTL in the authority) subsumed by M4, #9 (authority-form) shipped by M9 — chez-http-
server can drop both workarounds and consume v0.2.0 by gitlink. The tree is clean on main at
f359743, tagged v0.2.0.

(The RFC 3986 CONFORMANCE AUDIT was set up next — decision 0028 + a ledger seed — then PAUSED
at the maintainer's request to do issue #11 first; that setup is a WIP commit 115764d on
feat/conformance-audit, to resume after #11 merges.)

---

ISSUE #11 — COLLECTOR REUSE (uri-collector-reset!). Branch feat/collector-reset.

Plan: GitHub issue #11 (a server parses one request-target per request; uri-parse allocates a
fresh parser + two eq-hashtables per call). Decisions in force: 0002 (byte-machine by gitlink —
its runtime exports parser-reset!), 0008 (the collector's mutable state a reset must clear),
0016 (NO standing allocation lane — allocation is byte-machine's measured property; #11's
"measure" is a one-shot recorded benchmark), and NEW 0029 (a collector resets in place for
per-connection reuse).

Base at start: dee40d8 (local main == origin/main; v0.2.0 released as f359743, tagged v0.2.0).
Measured environment (2026-09-19, Darwin arm64): Chez 10.4.1 (tarm64osx), CMake/CTest 4.3.3.
Baseline: release 73/73, no-scheme 11/11, 0 failures.

THE CORRECTNESS HINGE, RESOLVED FROM BYTE-MACHINE SOURCE. The collector's parser carries the
MODE as an embedder field-override; a reset that dropped it would leave the parser in `unset`
mode, refusing at offset 0. But byte-machine's parser-reset! restores the field-VALUES (slot 8)
from the canonical MERGED initials (slot 17 — declared initials with the embedder overrides
applied), not the bare declared ones (slot 9): runtime.sls states "an embedder-chosen mode
survives a reset." So per-connection reuse is sound (decision 0029 context).

DONE (single slice — small, additive). uri-collector-reset! : Collector -> unspecified, on
(uri collect):
  - src/uri/collect.sls — a `reset!` message on the collector closure: parser-reset! (mode
    preserved), hashtable-clear! the span table AND the offset table, set! present '() /
    rooted? #f / verdict #f. Nothing reallocated. New export uri-collector-reset! (dispatches
    reset!). uri-parse and the one-shot path UNCHANGED; no scanner/grammar/artifact change.
  - test/common/collect-tests.sps — a "collector reuse (reset!)" group in unit.collect:
    reset-and-reparse equals a fresh collector in BOTH components AND offsets, across all three
    modes and across a ROOTED transition (http:/p → http://a/x) and a VERDICT transition
    (g:h → a/b); no stale span leaks (query/fragment cleared); the mode survives; reset after
    an ERROR result then reuse. (No CMake change — same imports, uri-collector-reset! is in
    URI_COLLECT.)
  BENCHMARK (decision 0029 item 3, one-shot, NOT a lane per 0016): 200k parses of the short
  target "example.com:443" (relative-ref) — fresh-collector-per-parse 160 ms vs reset-reuse
  25 ms, ~6.4x, confirming the issue's "fixed per-call overhead dominates a short parse" (fresh
  allocates a parser + two hashtables per call; reuse allocates none — the bytes-allocated
  probe was a post-GC artifact, so the time delta is the reported evidence).
  MUTATION WITNESSES (watched to fail, reverted): ALL SIX mutable-state resets are observable
  and witnessed — parser-reset! (reuse diverges), the span-table clear (stale spans corrupt
  scheme/path), the OFFSET-table clear (stale offsets), present '() (stale query/fragment leak
  as present-empty), rooted? #f (a stale rooted? prepends a spurious "/" → path //x), and
  verdict #f. (I FIRST mis-analysed verdict as unobservable — reasoning only about `assemble`,
  where a stale verdict is masked by the cleared leading-token bytes `lead`=#f — and de-scoped
  it from witnessing; the merge-gate review refuted that: `assemble-offsets`/`path-offset` also
  reads verdict, against the OFFSET table, so a stale verdict='segment steers the path offset
  to the cleared leading-token slot = #f. Witnessed by a new reuse row `uri-reference "g/h" →
  "/p"` — g/h fires the SEGMENT verdict, /p is a rooted path with NO leading token so it fires
  none — whose path offset is 0 fresh but #f if the verdict reset is dropped.) GRADED: release
  73/73, no-scheme 11/11; unit.collect 54 cases / 152 checks. — AT THE MERGE GATE.

ISSUE #11 MERGE-GATE VERIFICATION (2026-09-19). A focused three-dimension adversarial review
Workflow (Ultracode: parser-lifecycle edge states, reset completeness + an adversarial attack
on the "verdict unobservable" claim, and record fidelity; each finding default-refuted) — 8
agents. Result: 5 confirmed findings, 0 refuted, all the SAME issue from three angles, and NO
code defect (the shipped reset IS correct — it resets verdict). The defect was in MY ANALYSIS
and the record: the "verdict is unobservable / hygiene, not witnessed" claim was FALSE, because
`path-offset` reads verdict against the offset seam (the same seam this milestone's offset
comparison already checks). Fixed: (1) the false ledger claim corrected (above — verdict is
load-bearing, all six witnessed); (2) a witnessing reuse row added (`g/h → /p`), watched to
redden when verdict's reset is dropped; (3) the test group's comment corrected (it had
overclaimed the verdict rows witnessed verdict — they did not, because their second parse
re-fires a fresh verdict). The lifecycle-edge probing (reset never-fed / mid-parse / double /
after-error / a long loop, across modes) found no crash, no divergence, no mode loss. GRADED
after the fixes: release 73/73, no-scheme 11/11; unit.collect 54 cases / 152 checks. — STILL
AT THE MERGE GATE. Next: the closing ritual (ask first).

THE MERGE-GATE LESSON, AGAIN — and pointed at ME this time. Every milestone the gate catches
what the slice cannot see about itself; here it was not a code bug but a wrong INVARIANT I
asserted and then used to de-scope a line from the witness discipline. The review's refutation
(path-offset reads verdict) turned an unwitnessed, wrongly-rationalised reset into a witnessed
one. The rule sharpens: "unobservable, so not witnessed" is itself a claim to be adversarially
refuted, never a rationale to skip the witness — the byte/offset seam is wider than the first
reading of it.

ISSUE #11 MERGED (2026-09-19). PR #15 squash-merged to main as a1b9176; local main
fast-forwarded (dee40d8..a1b9176); feat/collector-reset deleted local and remote; issue #11
auto-closed ("Closes #11"). Merged over a RED linux-amd64 check, confirmed the documented
Actions billing refusal (decision 0017 — 0 steps, billing annotation), not a test result;
local macOS-arm64 evidence stands (release 73/73, no-scheme 11/11). The maintainer authorised
the closing ritual explicitly. Every push over HTTPS via `gh auth git-credential` (SSH still
broken this session).

REFLECTION. Issue #11 was a small, additive ergonomics win — one export, a reset! message —
but it earned the same merge-gate lesson the big milestones did, aimed this time at my own
REASONING rather than the code. The shipped reset was correct, yet I asserted a false
invariant ("verdict is unobservable, so kept as un-witnessed hygiene") by reasoning only about
`assemble` (the component bytes) and missing that `path-offset` reads verdict against the
offset seam. The adversarial review refuted it with a concrete counterexample (`uri-reference
"g/h" → "/p"`: a stale segment-verdict drops the path offset), which turned an unwitnessed,
wrongly-rationalised reset into a witnessed one and corrected the record. Two things carried
the milestone: the correctness hinge (does parser-reset! preserve the embedder mode?) was
settled from byte-machine SOURCE, not assumption — it restores the merged initials (slot 17),
so the mode survives; and the win was MEASURED once (~6.4x for a short target), disclosed as a
benchmark not baked into a lane (decision 0016 forbids a standing allocation lane). The
sharpened rule is banked: "unobservable, so not witnessed" is a claim to adversarially refute,
never a reason to skip the witness.

NEXT (RESUME THE RFC 3986 CONFORMANCE AUDIT). The audit was set up (decision 0028 + a ledger
seed) then paused for #11; its WIP is commit 115764d on feat/conformance-audit, based on the
pre-#11 main (dee40d8). To resume: cut a fresh audit branch from the new main (a1b9176) — or
rebase feat/conformance-audit onto it — re-applying decision 0028 and re-seeding the audit
ledger section AFTER this #11 close-out (fixing its "Base at start" to a1b9176), then drive
Slice ⓪ (the independent whole-URI abnf-oracle + its self-tests). The three sibling issues
filed this session — #9, #10, #11 — are all now resolved and merged; chez-http-server can drop
all three workarounds and consume main. The tree is clean on main at a1b9176 (v0.2.0 stays the
latest tag; #11 is post-v0.2, unreleased).

---

THE RFC 3986 CONFORMANCE AUDIT — earning (or refusing) the claim v0.2 deferred. Branch
feat/rfc3986-conformance-audit (a FRESH branch from the post-#11 main; it SUPERSEDES the stale
WIP feat/conformance-audit / commit 115764d, which was based on the pre-#11 main dee40d8 and
can be pruned at the maintainer's convenience — its two files, decision 0028 and the ledger
seed, are re-authored here on the correct base).

Plan: the audit decision 0027 item 4 deferred. Decisions in force: 0003 (adjudicate against
the ABNF, not a popular library), 0005/0012 (oracle-from-the-RFC, independent of the code;
agreement is the check; abnfgen/mutator are the deferred generators), 0011 (uri-parse is
lenient; validation is uri-parse-validate), 0024/0025 (the M3 charset + M4 host oracles this
audit composes), 0026 (M9 authority-form is RFC 9112 — OUT of scope), 0027 (the release that
deferred the claim), and 0028 (the audit charter: recognizer-equivalence, an independent
whole-URI oracle, earned only if clean).

Base at start: beb8952 (a1b9176 = the #11 merge; beb8952 = the #11 close-out; local main ==
origin/main; v0.2.0 released as f359743, tagged v0.2.0 and still the latest tag; #11 is
post-v0.2, unreleased). Measured environment (2026-09-19, Darwin arm64): Chez 10.4.1
(tarm64osx). Pre-audit baseline INHERITED from main (no product source changed on this
branch): release lists 73 tests; the existing pure-oracle lanes run green (host-oracle: 10
cases / 67 checks / 0 failures, re-run this session).

THE FORCING QUESTION, AND WHY THE AUDIT HAS SUBTLE TEETH. "RFC 3986 compliant" for a
validating parser means RECOGNIZER-EQUIVALENCE: uri-parse-validate accepts a bytevector in
mode `uri` iff it is a `URI` (Appendix A), etc. (0028 item 1). An armchair probe found the
OBVIOUS gaps already closed — the scheme first-char ALPHA rule holds (`1abc:x`, `+x:y`,
`ht!tp:x` all rejected invalid-scheme), and even `uri-reference "1abc:x"` (neither a valid
URI nor a valid relative-ref) is rejected. So M3/M4 are more conformant than a naive read
suggests; the audit is NOT a bug-hunt for the obvious but a rigorous recognizer-equivalence
check for SUBTLE deviations in the lenient-split × component-validation interaction. The
existing charset/host oracles are COMPONENT-level; the untested questions are STRUCTURAL
(path-type-per-context, the mode→production mapping, empty/edge shapes), so the audit's new
oracle must recognize a WHOLE URI.

WHAT THE AUDIT SHIPS (decision 0028): NO README/CHANGELOG claim-flip at merge (that rides a
release, 0028 item 6). Test artifacts + any confirmed src fixes + the recorded verdict:
  - `(uri test abnf-oracle)` — an INDEPENDENT whole-URI recognizer of URI / URI-reference /
    relative-ref, the STRUCTURAL grammar composed with the existing charset/host oracles
    (0028 item 2). A fourth, structural reading of the ABNF, product-independent.
  - a DIFFERENTIAL lane — uri-parse-validate ⇄ the oracle over positives, negatives,
    exhaustive small sweeps, adversarial boundary corpora, and generated valids (0028 item 3).
  - each disagreement adjudicated against the ABNF → product fix (witnessed) / oracle fix /
    documented deviation (0028 item 4); the recorded VERDICT (0028 item 5).

SLICE PLAN (cadence: drive to gates — stop after Slice ⓪ and at the merge gate; a Workflow
for the differential's per-production probing + adversarial adjudication):

  ⓪  `(uri test abnf-oracle)` — the independent whole-URI recognizer (structural grammar +
     the composed component oracles) + its SELF-tests: it must ACCEPT every positive corpus
     (§1.1.2, §5.4 base/refs/targets) and REJECT a hand-built structural negative set (bad
     scheme-first-char, a path-type-per-context violation, a mode-production mismatch, the
     uri-reference disambiguation), mutation-witnessed. NO differential against the product
     yet (the oracle is graded on its own first, as the corpus loader was — 0005). — GATE.
  ①  the DIFFERENTIAL AUDIT — run uri-parse-validate ⇄ the oracle over the broad space
     (0028 item 3); catalog every disagreement; adjudicate each against the ABNF; fix
     confirmed product bugs (witnessed); the VERDICT emerges (clean, or the residual
     deviations). A Workflow drives the per-production probing and the adversarial
     adjudication (default-refute a claimed deviation). — MERGE GATE.
  CLOSE — merge-gate adversarial review + the recorded verdict + closing ritual (ask first)
  + reflection.

SLICE ⓪ DONE (2026-09-19). The whole-URI oracle and its self-tests, graded on the oracle's OWN.
  - test/support/harness/uri/test/abnf-oracle.sls — `(uri test abnf-oracle)`, exports
    oracle-recognize? (mode symbol + bytevector → boolean) and oracle-recognize-string?. A
    recursive-descent recognizer of RFC 3986 Appendix A's STRUCTURE: it peels [ "#" fragment ]
    then [ "?" query ] by the ABNF's own unambiguous greedy split (query/fragment carry no "#",
    hier-part/relative-part carry neither), then matches the front as `scheme ":" hier-part`
    (URI) or `relative-part` (relative-ref). The five path-types are predicates over the path
    range (empty / abempty / absolute / rootless / noscheme), and the ONE structural fork is
    path-rootless (colon-bearing, a URI's) vs path-noscheme (first-segment-no-colon, a
    relative-ref's) — the whole URI/relative-ref disambiguation. It DEFERS every charset
    question to the two audited component oracles: `only (uri test charset-oracle) oracle-scan`
    for scheme/path/query/fragment (also the leading-ALPHA and non-empty scheme rules), and
    `only (uri test host-oracle) oracle-scan-authority` for the "//" authority (split at the
    first "/", exact because userinfo/host/port admit no "/"). `only` imports because the two
    component oracles share the ABNF byte-set names and would otherwise collide. PURE.
  - test/common/abnf-oracle-tests.sps — unit.abnf-oracle, graded two ways (0005): ACCEPT every
    positive (the §1.1.2 examples as both uri and uri-reference; the §5.4 base + 43 targets as
    uri; the §5.4 43 references as uri-reference — all read through (uri test corpus)), plus
    explicit per-path-type / per-mode positives and the divergence trio (g:h and a:/b are URIs,
    are NOT relative-refs, are URI-references through the URI arm); REJECT a hand-built
    structural negative set, one class per case (bad/empty/space scheme; mode↔production
    mismatch; invalid authority; per-component charset fault in path/query/fragment; a raw
    non-ASCII byte). 12 cases / 142 checks / 0 failures.
  - test/CMakeLists.txt — the uri.unit.abnf-oracle.chez.{source,aot} lane, modeled on the
    charset/host-oracle lanes: pure test-side (harness + all three oracle libs + the corpus
    harness lib), reads URI_CORPUS_DIR, LABELS unit. Registering it takes the release
    selection from 73 to 75 (a source + an aot twin).

  VERIFICATION UNDER A BUILD-BLOCKED SESSION (disclosed, not waived — the honesty the ledger
  owes). This session's permission mode auto-DENIES `make` / `cmake --build` / `cmake` configure
  as potentially-destructive, so the CMake reconfigure that would register the new lane under
  CTest, and the AOT compile, could not run here. `ctest` (run/list) and direct `chez` execution
  ARE permitted, so the SOURCE lane was verified by invoking the exact command the CMake lane
  wraps — the chez-source launcher with `--library-root test/support/harness`, an empty
  object-guard, `--program …/abnf-oracle-tests.sps`, `URI_CORPUS_DIR` on the environment — which
  is source-mode-identical to `uri.unit.abnf-oracle.chez.source`. Result: status=0, 12 cases /
  142 checks / 0 failures. CONFIRMED UNDER A FULL BUILD (2026-09-19): the maintainer ran
  `make test-all` after Slice ⓪ landed — the registered release suite passed with the new lane
  and its AOT twin included (73 → 75 tests green), so the CTest registration and the compiled
  twin are verified, not pending.

  MUTATION WITNESSES (watched to fail via the direct source lane, then reverted; the two
  load-bearing structural decisions). (1) The URI/relative-ref FORK: dropping path-noscheme's
  first-segment-no-colon check (→ #t) made the oracle accept "g:h" and "a:/b" as relative-refs
  and "http://a" too — 5 failures across the disambiguation and mode-mismatch cases, status=1.
  (2) The SCHEME GATE: dropping `charset-ok? 'scheme` from scheme-hier? made it accept "1abc:x",
  ":x", "a b:c" as URIs (and "1abc:x" as a URI-reference) — 4 failures, status=1. Both reverted;
  re-run green (12/142/0), no mutation markers left in source. — AT THE GATE.

SLICE ① DONE (2026-09-19) -- THE DIFFERENTIAL, AND ITS VERDICT: CLEAN. uri-parse-validate ⇄
(uri test abnf-oracle) over a broad space; every input×mode where they disagree would redden.
  - test/common/abnf-differential-tests.sps -- the differential lane. Four input sources
    (0028 item 3): (a) the §1.1.2 / §5.4 positives (both accept); (b) the M3 charset + M4 host
    negative corpora (both reject); (c) an EXHAUSTIVE sweep of every length-0..5 word over the
    12-byte reduced alphabet {a 1 ; . : / ? # [ ] @ %} in all three modes -- 271,453 words ×
    3 = ~814k input×mode pairs, the short-string boundary space covered COMPLETELY; (d) the
    adversarial corpus of deep structures the length bound cannot reach, each carrying its
    ABNF verdict as a THIRD independent reading (guards a shared oracle/product blind spot,
    0005/0012). MAXLEN=5 committed (len-6 measured clean at 12s but heavy for a lane; len-5 is
    1.2s); the bound is both DISCLOSED (an unconditional `uri-harness: coverage ...` line
    naming alphabet/maxlen/compared, emitted every run) and ASSERTED (the loop's tally is
    checked EQUAL to an independently-computed expected total, so a silent cap reddens rather
    than passing byte-identically) -- 0028 consequences, hardened at the merge gate below.
  - test/conformance/differential/adversarial.scm (+ PROVENANCE) -- 213 rows (118 accept /
    95 reject; 171 uri, 27 relative-ref, 15 uri-reference; 21 are #vu8 control/high-byte
    vectors). 60 hand-authored at the seed; 153 from the Slice ① probe Workflow. Its own dir,
    apart from the provenance-guarded rfc3986/ (authored, like charset/ and host/).
  - test/CMakeLists.txt -- the uri.conformance.abnf-differential.chez.{source,aot} lane
    (drives the whole read stack + all three oracle libs + the corpus lib; reads the four
    corpus dirs). Registering it takes the release selection 75 → 77.

THE ADVERSARIAL PROBE (decision 0028 item 3d, Ultracode Workflow). Eight per-production probe
agents (scheme, authority-split, ip-literal, ipv4/reg-name/pct, path-fork, pct-encoding,
query/fragment, edge+bytes) each generated deep vectors targeting the lenient-split ×
component-validation seam; a SEPARATE verify pass per family independently re-derived every
verdict from Appendix A and default-refuted anything it could not confirm. 16 agents, 0 errors:
157 proposed, 157 confirmed, 0 refuted, 4 intra-dups dropped on merge → 153 added. Each was
then run through the differential.

THE RESULT: CLEAN. Over the exhaustive sweep, both positive corpora, both negative corpora,
and all 213 adversarial rows, uri-parse-validate AGREES with the independent oracle on EVERY
verdict, and both match the corpus's hand ABNF reading. ZERO deviations. The audit had teeth
(any of the 153 hostile vectors, or any of the ~814k swept words, could have exposed a product
bug) and found none. So over the audited space uri-parse-validate is RECOGNIZER-EQUIVALENT to
RFC 3986 Appendix A per mode -- the property "RFC 3986 conformant (validation)" names (0028
item 1). Adjudication (0028 item 4) had nothing to adjudicate: no disagreement arose.

MUTATION WITNESSES (a clean differential that cannot fail is not evidence; watched to fail via
the direct source lane, then reverted). (1) The SWEEP detector: dropping the oracle's scheme
charset gate made it accept invalid-scheme inputs the product rejects -- the sweep reddened
naming the exact words (":", "1:", ";:", ".:", ...), status=1. (2) The CORPUS third-reading
detector: flipping one row's ABNF verdict (a://999.1.1.1 accept→reject) reddened BOTH the
oracle-vs-ABNF and product-vs-ABNF checks for that row (the shared-blind-spot guard bites even
when oracle and product agree with each other), status=1. Both reverted; re-run green (8 cases
/ 714 checks / 0 failures), no mutation markers left.

VERIFICATION UNDER THE BUILD-BLOCKED SESSION (disclosed). Same constraint as Slice ⓪: the
cmake reconfigure that registers the new differential lane and the AOT compile are auto-denied
this session, so the differential was verified by the chez-source launcher directly (source-
mode-identical: harness + src + byte-machine roots, the four corpus dirs on the environment) --
status=0, 8 cases / 714 checks / 0 failures. The maintainer's `make test-all` after Slice ⓪
already confirmed the abnf-oracle lanes register and compile (73 → 75); the differential lane
(+2) needs a fresh `make build` + `ctest --preset release` to bring the registered suite to 77
and compile its AOT twin. Nothing about the evidence is provisional -- only the new lane's
CTest registration and compiled twin await that build.

AT THE MERGE GATE. Next: the merge-gate adversarial review -- pointed at the AUDIT ARTIFACTS
themselves (could a hole make the "clean" verdict FALSE? -- an oracle bug that mirrors a
product bug, a sweep alphabet that misses a decisive byte, a differential that does not compare
what it claims, a wrong corpus verdict, a mis-wired lane, an over-claiming record) -- then a
decision recording the verdict and the ledger close-out. The README/CHANGELOG "conformant"
claim-flip is NOT in this milestone (0028 item 6): it rides a subsequent release, gated as
0027/0023 gate release claims. Publish steps (push, PR, merge) remain per-action maintainer-
gated (0023 point 7).

SLICE ① MERGE-GATE REVIEW (2026-09-19). An adversarial review Workflow (Ultracode) pointed NOT
at the product but at the AUDIT ARTIFACTS: could a hole make the "clean" verdict FALSE or
overclaimed? Six dimensions -- oracle-correctness, shared-blindspot (an input both oracle AND
product get wrong the same way), coverage-gap, harness-vacuity, corpus-fidelity, record-and-lane
-- each finding adversarially VERIFIED with a real Chez probe (default-refute). 10 agents, 0
errors: 4 findings, 0 refuted, 4 confirmed (1 major, 2 minor, 1 nit).

THE VERDICT SURVIVED. The high-value dimensions found NOTHING that falsifies "clean": no oracle
misreading of the ABNF, no shared oracle/product blind spot, no wrong corpus verdict, no missing
decisive byte, no mis-wired lane. So the product result -- uri-parse-validate is
recognizer-equivalent to Appendix A over the audited space -- STANDS. Every confirmed finding was
about the HARNESS's integrity/disclosure or a record, not the audit outcome.

THE MERGE-GATE LESSON, POINTED AT ME AGAIN. The major finding: I asserted an INTEGRITY property
that was FALSE. The ledger, decision 0028, and the .sps header all claimed the sweep's coverage
bound was "DISCLOSED in the summary line, not silent" -- but a passing `check` prints only its
LABEL, and only on FAILURE, so the compared count and MAXLEN were NEVER emitted; worse, nothing
ASSERTED the count, so a silently-capped sweep (MAXLEN set to 0) produced a byte-identical
passing summary, indistinguishable from full coverage. The review proved it by running a
MAXLEN=0 copy to the same SHA-256 as the real run. The "~814k / disclosed" framing was
overclaimed exactly the way the review was told to hunt. (This rhymes with the #11 gate lesson:
there I mis-asserted "unobservable"; here I mis-asserted "disclosed" -- both times an unverified
claim ABOUT the evidence, refuted by a run.)

THE FIXES (all mutation-witnessed or re-run green).
  1. (major + its minor record twin) test/common/abnf-differential-tests.sps: the vacuous
     `(check "compared N" #t)` is replaced by `(check-equal ... compared EXPECTED-COMPARISONS)`,
     where EXPECTED-COMPARISONS = 3 × Σ 12^k (k=0..MAXLEN) = 814359 is derived INDEPENDENTLY of
     the loop -- so a silent cap reddens (WITNESSED: capping the loop to len 2 while EXPECTED
     stays at MAXLEN=5 fails "expected 814359, got 471", status=1). And an unconditional
     `uri-harness: coverage sweep=exhaustive alphabet=12 maxlen=5 modes=3 compared=814359` line
     is emitted every run (via the exported adapter-flush-output), so the disclosure the records
     promise now exists. The header, the ledger, and (below) decision 0028's wording are
     corrected to describe BOTH mechanisms.
  2. (minor) the positives and negatives groups gained non-emptiness guards (like the adversarial
     group already had): a corpus reduced to a well-formed-but-empty form now reddens instead of
     passing with zero checks.
  3. (nit) PROVENANCE corrected: of the 21 #vu8 rows, 19 carry a control/>0x7F byte and 2 pin a
     raw SP (0x20) -- not "all 21 control-or-high".
  RE-GRADED green after the fixes: unit.abnf-oracle 12 cases / 142 checks; conformance.abnf-
  differential 9 cases / 718 checks (the +1 case / +4 checks are the new count assertion and the
  four non-emptiness guards); 0 failures; the coverage line emits compared=814359.

THE RECORDED VERDICT: decision 0030. Over the exhaustive length-0..5 sweep (814,359 input×mode
pairs, ASSERTED complete), the §1.1.2/§5.4 positives, the M3/M4 negatives, and 213 ABNF-verified
adversarial rows, uri-parse-validate is RECOGNIZER-EQUIVALENT to RFC 3986 Appendix A per mode,
with ZERO deviations, and the differential's failure detectors and its coverage assertion are
mutation-witnessed. Per 0028 item 5a the claim "RFC 3986 conformant (validation)" is EARNED and
becomes claimable -- but the README/CHANGELOG flip RIDES THE NEXT RELEASE (0028 item 6), it is
NOT in this milestone's merge. Boundaries kept honest (decision 0030): this is RECOGNITION
equivalence (accept/reject), not error-code/offset equivalence (separately gated by M3/M4); the
exhaustive part is bounded at length 5 / a 12-byte alphabet, with deeper structures covered by
the targeted 213-row adversarial corpus, not exhaustively.

AT THE MERGE GATE (post-review, clean). Remaining to reach a merged state: the maintainer's
`make build` + `ctest --preset release` to register/compile the two new lanes (unit.abnf-oracle
already confirmed at 75; +conformance.abnf-differential source+aot → 77) and the closing ritual
+ publish (push, PR, merge), all per-action maintainer-gated (0023 point 7). No product code
changed in the whole audit; it is purely additive test artifacts + records.

THE RFC 3986 CONFORMANCE AUDIT — MERGED (2026-09-20). PR #16 squash-merged to main as
66929c2; local main fast-forwarded (beb8952..66929c2); feat/rfc3986-conformance-audit deleted
local and remote; the superseded WIP feat/conformance-audit (115764d) left for pruning. The
maintainer RAN THE FULL REGISTERED SUITE (make test-all) and confirmed 77/77 green — the
release selection grew 75 → 77 with uri.unit.abnf-oracle and uri.conformance.abnf-differential
(source+aot) — BEFORE authorising the squash-merge, so the merge rests on real full-suite
evidence, not a source-lane-only claim. Merged over the RED linux-amd64 check, re-confirmed the
decision-0017 billing refusal (0 steps, 3s, "recent account payments have failed" annotation),
not a test result. Every push over HTTPS via `gh auth git-credential` (SSH still broken); the
origin/main tracking ref went stale after the push and was re-synced with fetch + update-ref
(the recurring HTTPS-push quirk).

REFLECTION. The audit did what an audit must: it could have failed and did not. Zero product
deviations across ~814k exhaustive comparisons, both corpora, and 213 ABNF-verified adversarial
vectors — uri-parse-validate is recognizer-equivalent to RFC 3986 Appendix A per mode, earned
honestly (decision 0030), not granted. Four things carried it. (1) The oracle is INDEPENDENT
(a structural reading of Appendix A composing the audited M3/M4 component oracles), so
agreement is evidence, not tautology; (2) the adversarial corpus is a THIRD reading with its
own ABNF verdicts, guarding the one way a two-reading differential can lie (a shared blind
spot); (3) the 8-production adversarial-probe Workflow tried hard to break equivalence with
deep structures the length bound cannot reach, and every one of its 153 verdicts was
independently re-derived before use; (4) earn-only-if-clean kept the milestone from being a
rubber stamp. The merge-gate lesson landed on me a THIRD time this session, same shape as #11:
I asserted an integrity property ABOUT the evidence ("coverage is disclosed") that a run
refuted — a passing check prints nothing, and nothing asserted the count, so a silent cap was
invisible. The fix made the property real (assert the count against an independent total;
emit it unconditionally) and mutation-witnessed. Banked: an unverified claim about the
evidence is as much a defect as a wrong line of product code, and the only cure is a run —
[[verify-and-emit-integrity-claims]].

NEXT: CUT A RELEASE (maintainer's request). The audit earned "RFC 3986 conformant (validation)"
(decision 0030), and unlike M3/M4/M9 whose claims waited for v0.2, this claim is now claimable
and wants a release to carry it (0028 item 6 / 0027 / 0023 gate the flip to a release). The
release template is decision 0023 as amended by 0027 (annotated tag, structural doc
reconciliation, honest claim from the decision records, CI-never-ran amendment disclosed,
re-measure at the tag commit, publish steps per-action maintainer-gated). What is unreleased on
main since v0.2.0: #11 (uri-collector-reset!, a1b9176) and this audit (66929c2). The version
bump, README/CHANGELOG reconciliation (now ADDING the earned validation-conformance claim with
its recognition/normalization boundary), and the tag are the next milestone.

---

THE v0.3.0 RELEASE — the first to STATE an RFC 3986 conformance claim. Branch
chore/release-v0.3.0.

Plan: the release act for the arc since v0.2.0, checklist derived from decision 0023 as
amended by 0027, now 0031 (the v0.3 successor). Decisions in force: 0017 (CI never run — each
release needs its own amendment), 0023/0027 (the v0.1/v0.2 templates), 0029 (#11 —
uri-collector-reset!), 0030 (the audit VERDICT — recognition-equivalence earned), 0031 (the
v0.3 release: minor bump, STATE the earned validation-conformance claim scoped to recognition,
still-never-run CI disclosed).

Base: 2cf9de5 (local main == origin/main; v0.2.0 = f359743, tagged). Unreleased since v0.2.0:
#11 (uri-collector-reset!, a1b9176 — the one src change, an additive export) and the RFC 3986
conformance audit (66929c2 — test artifacts + records only). The maintainer ran make test-all
and confirmed 77/77 before the audit merge.

VERSION: 0.2.0 → 0.3.0 (MINOR — uri-collector-reset! is a new backward-compatible export; no
existing behaviour changed). The (uri …) libraries stay unversioned.

THE HEADLINE (decision 0031 item 4): v0.3 is where the "RFC 3986 compliant" claim decision
0027 DEFERRED gets stated — precisely. The audit (0030) proved uri-parse-validate
recognizer-equivalent to Appendix A per mode, so v0.3 STATES "RFC 3986 conformant
(validation)", scoped: recognition (accept/reject) not error-code/offset; exhaustive bounded +
adversarial; uri-parse stays lenient by design. NOT a blanket whole-library "RFC 3986
compliant".

DOC RECONCILIATION DONE (release act — no algorithm, no lane, no src change in the release
commit; 0031 item 1):
  - CMakeLists.txt VERSION 0.2.0 → 0.3.0.
  - README.org: status → v0.3.0 (2026-09-20); summary gains the audit result (audited
    recognizer-equivalent, zero deviations) and uri-collector-reset!; the v0.2 "not yet RFC
    3986 compliant" caveat REWRITTEN from a deferral into a scoped boundary (the validation
    recognizer is conformant; the blanket claim is not granted — recognition not
    error-code/offset, bounded+adversarial, uri-parse lenient). CI-not-run quote, strict
    resolution, round-trip §4.2/§3.3 boundary, not-portable, normalize-no-dot-segments kept
    verbatim.
  - CHANGELOG.md: [Unreleased] → [0.3.0] - 2026-09-20 (preamble discloses CI-never-run + the
    77/77 & 11/11 counts + the scoped claim; an audit section and an uri-collector-reset!
    section in the measured mutation-witness voice), fresh [Unreleased], version links updated.
  - decision 0031 written (7 items).

AWAITING (0031 items 6-7, maintainer-gated). The release-verification gate is a fresh
re-measure AT the reconciliation commit (ctest --preset release + --preset no-scheme, each
--no-tests=error) — expected 77/77 and 11/11 since the commit is doc-only, but RE-RUN not
asserted; this session's mode blocks the build, so the maintainer runs it. Then the publish
steps under the "lets cut a release" ratification: PR → squash-merge → annotated tag v0.3.0 on
the merge commit (message carries the re-measured counts + CI disclosure) → push tag, all over
HTTPS. A GitHub Release is optional (body = the CHANGELOG [0.3.0] section verbatim). — AT THE
RELEASE GATE.

v0.3.0 RELEASED (2026-09-20). PR #17 squash-merged to main as aae178e; local main
fast-forwarded (2cf9de5..aae178e); chore/release-v0.3.0 deleted local and remote; annotated
tag v0.3.0 (7fe6688) placed on aae178e and pushed over HTTPS. The release-verification gate
(0031 item 6) is met by a FRESH re-measure at the reconciliation commit: the maintainer ran
release 77/77, and no-scheme 11/11 was re-run this session (the no-scheme layer's specs execute
against the source tree and nothing in it changed) — 0 failures, macOS arm64, Chez 10.4.1
tarm64osx, CMake/CTest 4.3.3. Merged and tagged over the RED linux-amd64 check, re-confirmed the
decision-0017 billing refusal (0 steps), not a test result. Every push over HTTPS via `gh auth
git-credential` (SSH still broken). A GitHub Release was NOT auto-cut (0031 item 7 — the gitlink
pin needs only the pushed tag); its body, if the maintainer wants one, is the CHANGELOG [0.3.0]
section verbatim.

REFLECTION. v0.3 is the release the whole conformance thread was pointed at. The template held a
THIRD time (0023 → 0027 → 0031): structural doc reconciliation, an honest claim drawn straight
from the decision records, the never-run-CI amendment disclosed, a re-measure at the tagged
commit, publish steps per-action gated. The one act with real judgment was STATING a conformance
claim for the first time — and stating it PRECISELY: "RFC 3986 conformant (validation)", scoped
to recognition (not error-code/offset), bounded exhaustive + adversarial, uri-parse still lenient
by design, explicitly NOT a blanket whole-library "compliant". The house rule "a property is
measured or it is not claimed" ran its full course here: v0.2 said the compliance claim was
"earnable, not granted" and deferred it to an audit; the audit ran, came back clean (0030), and
v0.3 states exactly what it earned and no more. The deferral discipline paid off yet again —
M3/M4/M9 claims rode v0.2, the audit's claim rode v0.3, and no released tag ever over-claimed.

NEXT (v0.3 is DONE; what reopens is a SEPARATE choice, not a v0.3 gap — 0031 consequences). Three
directions, each its own decision: (1) the FIRST FUNDED CI RUN — discharging 0017 item 3 and its
two never-executed predictions, replacing the macOS-arm64-local disclosure that every release so
far has carried with cross-platform evidence; (2) v0.3+ TOOLING — the deferred abnfgen positive
generator and host-aware mutator (0012), now optional standing tooling the clean audit did not
require, or a relative-reference serializer above recompose (0022); (3) the next SIBLING request
from chez-http-server (which can now consume main by gitlink: #9/#10/#11 all resolved, and
uri-parse-validate is audited conformant). Housekeeping: the superseded WIP branch
feat/conformance-audit (115764d, pre-#11 base) is still present and can be pruned. The tree is
clean on main at aae178e, tagged v0.3.0.

═══════════════════════════════════════════════════════════════════════════════════════════════

ISSUE #18 SEED (2026-09-19). The next SIBLING request from chez-http-server, NEXT direction (3).
A server validates every request-target through `uri-parse-validate`, which builds a FRESH
collector every call; #11's `uri-collector-reset!` saved that allocation only on the un-validated
streaming path, because the audited recognizer was reachable ONLY through `uri-parse-validate`
(the internal `validate-result` — a pure function OF a parse result — was not exported). The
issue measured the cost (Darwin arm64, v0.3.0): a 46-byte origin-form target is 3680 B / ~1.2 µs
fresh vs 1584 B / ~0.5 µs reset — a cost the validating server could not avoid. The additive ask:
export `uri-parse-result-validate : uri-parse-result -> uri-parse-result` (the post-parse
judgement, named), and redefine `uri-parse-validate` over it, so a reused collector's
`uri-collect-finish!` result reaches the SAME audited verdict (0028/0030) with no re-parse and no
second implementation. Decision 0032 written (5 items). Item 4 DEFERS a result/collector-level
authority-form validator (the issue's optional part, "Not needed for v1"). No new library, no
scanner/grammar change, no README/CHANGELOG at merge (rides the next release, per the 0029
precedent).

ISSUE #18 WORK DONE (branch feat/parse-result-validate). TDD: the new `unit.collect` group was
written first and witnessed RED (unbound identifier), then the src landed and it went GREEN.
src/uri/collect.sls: +1 export, the new 4-line `uri-parse-result-validate` (`(if (uri-parse-ok? r)
(or (validate-result r) r) r)` — a structural error's #f components pass straight through), and
`uri-parse-validate` reduced to `(uri-parse-result-validate (uri-parse mode-sym bv))` —
behaviour-preserving. The new function was MUTATION-WITNESSED three ways (skip-judgement →
the charset pin reddens; fresh-record-on-success → the eq? identity reddens; drop-delegation →
both equivalence checks redden on the invalid rows). Behaviour-preservation confirmed across the
whole dependent surface (all measured on the source lane, Chez 10.4.1 tarm64osx): collect 60/187,
charset 8/1243, host 10/191, authority-form 7/87, grammar 84/553, resolution 47/94, round-trip
27/96, abnf-differential 9/718 (814,359 sweep) — every one 0 failures.

ISSUE #18 MERGE-GATE REVIEW (Ultracode workflow, 4 dims × review→adversarial-verify, 10 agents).
3 findings CONFIRMED, 3 REFUTED. The two MAJOR findings were the SAME merge-gate trap as the audit
(see [[verify-and-emit-integrity-claims]]): (a) the "reused collector, validated" case built a
FRESH collector and never called `uri-collector-reset!` — and since `uri-parse` IS make+feed+finish,
it was byte-for-byte the one-shot path, so the central #11 property was asserted in prose but
exercised by NO check; (b) both equivalence checks route both sides through the same
`validate-result`, so a bug INSIDE it cancels — the verifier witnessed an authority-arm offset bug
passing the ENTIRE suite. Fixes: `reuse-validate` now genuinely resets and reuses a collector; the
equivalence prose is re-scoped to what it actually guards (the delegation + divergence, not the
judgement); and TWO independent hardcoded pins were added, one per arm of `validate-result`
(charset invalid-pchar@10 on BOTH the fresh and reset-reused paths; authority invalid-port@9,
rebased through the authority seam). The authority pin was witnessed to catch the exact bug that
passed before (offset 9→14 reddens it; the equivalence checks stay green, proving where the teeth
are). The MINOR finding (decision 0032 mis-attributed `(uri charset)`/`(uri host)` imports to the
`unit.collect` LANE rather than the `(uri collect)` LIBRARY — R6RS import is not transitive) was
reworded. The 3 REFUTED were cosmetic (a comment's IP-literal mislabel, a pre-edit line citation
in the ADR Context, the authority-form "under-validation" which is the CORRECT RFC 3986 verdict and
is deferred by 0032 item 4). Post-fix `unit.collect` is 60/187, 0 failures.

ISSUE #18 MERGED (2026-09-20). PR #19 squash-merged to main as ea02cf7; issue #18 auto-closed by
"Closes #18". SSH was FIXED mid-flight (the maintainer's machine), so the push and the main sync
went over SSH — the `gh auth git-credential` HTTPS workaround is retired for now (revisit only if
SSH breaks again). The merge gate: the maintainer ran the registered suite green — 77/77, 0
failures (the release selection is unchanged at 77; no new lane, unit.collect already covered the
new checks). Merged over the RED linux-amd64 check, re-confirmed the decision-0017 billing refusal
(0 steps, ~3s, "recent account payments have failed" annotation) — not a test result. Local main
fast-forwarded 69d2a84 → ea02cf7; feat/parse-result-validate deleted local and remote. Commit
lineage on main: … → aae178e (v0.3 release) → 69d2a84 (v0.3 close-out) → ea02cf7 (#18). Tags
unchanged (v0.1.0, v0.2.0, v0.3.0); #18 is post-v0.3.0 and UNRELEASED.

REFLECTION. A small, honest additive: one export, a 4-line function, a behaviour-preserving
one-line refactor of uri-parse-validate. The real value was the review, which for the THIRD time
(merge-gate audit → v0.3 → here) caught the same class of defect — a property asserted in prose
that no check verified ([[verify-and-emit-integrity-claims]]). Twice-over here: a "reused
collector" case that never called uri-collector-reset! (byte-identical to the one-shot path,
because uri-parse IS make+feed+finish), and two equivalence checks that routed both sides through
the same validate-result and so could not catch a bug inside it — the verifier witnessed an
authority-arm offset bug passing the ENTIRE suite. The fix was the lesson applied: make the reuse
path actually reset, and add INDEPENDENT hardcoded pins — one per arm of validate-result (charset
invalid-pchar@10 on both the fresh and reset-reused paths; authority invalid-port@9 through the
authority seam) — then witness that the authority pin catches the exact bug that had passed. The
equivalence checks stay, honestly re-scoped to what they guard (delegation + divergence between the
entry points), not the judgement's absolute correctness. Product-to-product equivalence is a
divergence guard, never a correctness proof when both sides share the code under test — the pattern
to keep reaching for is an INDEPENDENT reference (a hardcoded constant, an oracle), the same
discipline M3/M4 and the audit already use.

NEXT (#18 is DONE and merged; nothing outstanding). #18 closes the last-known chez-http-server
sibling ask on the parse/validate surface (#9/#10/#11 + the audit + now result-level validation);
a per-connection server reuses a collector AND validates its finish! result with no re-parse, on
the audited recognizer. The open directions are unchanged and each its own decision, NOT a #18 gap:
(1) the FIRST FUNDED CI RUN — discharges 0017 item 3 and its two never-executed predictions,
replacing the macOS-arm64-local disclosure every release has carried; (2) v0.3+ TOOLING — the
deferred abnfgen positive generator / host-aware mutator (0012), or a relative-reference serializer
above recompose (0022); (3) the OPTIONAL result/collector-level authority-form validator deferred
by 0032 item 4, if a CONNECT-target-reuse request ever measures the need; (4) a v0.3.1/v0.4 release
whenever the maintainer wants the uri-parse-result-validate export stated in a tag + CHANGELOG (it
is currently merged-but-unreleased, exactly as M3/M4/#11 were between their merges and v0.2/v0.3).
Housekeeping: the superseded WIP branch feat/conformance-audit (115764d, pre-#11 base) is still
present locally and can be pruned. The tree is clean on main at ea02cf7.

═══════════════════════════════════════════════════════════════════════════════════════════════

v0.4 RELEASE SEED (2026-09-20; "lets make a release"). NEXT direction (4). The arc since v0.3.0
(tag on aae178e) is ONE merged change — issue #18 (uri-parse-result-validate, ea02cf7). As with
v0.2/v0.3 the only work is the release ACT; its two non-mechanical questions are the evidence basis
and the claim. Evidence: CI STILL never run (the #18 PR's linux-amd64 was the 0017 billing refusal,
0 steps ~3s), so macOS-arm64-local, 77/77 + 11/11, re-measured at the release commit. Claim: NO NEW
claim — uri-parse-result-validate IS the same audited recognizer (0030) reached from a parse
result, so v0.4 carries v0.3's scoped conformance claim UNCHANGED and states the export as a new
CAPABILITY, not a broadening. Bump is MINOR (0.3.0 → 0.4.0): a new backward-compatible export, no
behaviour change — the same reasoning that made uri-collector-reset! minor for v0.3 (0031 item 2).

v0.4 RECONCILIATION DONE (branch chore/release-v0.4.0, off main babbac4). CMakeLists VERSION
0.3.0 → 0.4.0. README.org: status → v0.4.0 (2026-09-20); the summary gains uri-parse-result-validate
alongside uri-collector-reset! (the per-connection-reuse story) and the API-reference sentence names
it; the conformance sentence, the "not a blanket compliant" caveat, the CI quote, strict-resolution,
round-trip §4.2/§3.3, not-portable, normalize-no-dot-segments all kept VERBATIM (none touched by #18).
CHANGELOG.md: [Unreleased] → [0.4.0] - 2026-09-20 (preamble discloses CI-never-run + billing refusal
+ 77/77 & 11/11 + "no new conformance claim"; one feature section in the measured mutation-witness
voice), fresh [Unreleased], version links updated. Frozen [0.3.0]/[0.2.0]/[0.1.0] untouched. Decision
0033 written (7 items; successor to 0023→0027→0031). The release act adds no src, no lane, no algorithm.

v0.4.0 RELEASED (2026-09-20). PR #20 squash-merged to main as 611b04b; local main fast-forwarded
(babbac4..611b04b); chore/release-v0.4.0 deleted local and remote; annotated tag v0.4.0 (799f6e2)
placed on 611b04b and pushed over SSH (dereferences to 611b04b, confirmed). The release-verification
gate (0033 item 6) is met by a FRESH re-measure at the reconciliation commit: the maintainer ran
release 77/77 and no-scheme 11/11 — 0 failures, macOS arm64, Chez 10.4.1 tarm64osx, CMake/CTest
4.3.3. Merged and tagged over the RED linux-amd64 check, re-confirmed the decision-0017 billing
refusal (0 steps, ~3s), not a test result. Every push over SSH (fixed this session; the HTTPS
`gh auth git-credential` workaround is retired unless SSH breaks again). A GitHub Release was NOT
auto-cut (0033 item 7); its body, if the maintainer wants one, is the CHANGELOG [0.4.0] section
verbatim. Commit lineage on main: aae178e (v0.3) → 69d2a84 (v0.3 close-out) → ea02cf7 (#18) →
babbac4 (#18 close-out) → 611b04b (v0.4 release). Tags: v0.1.0, v0.2.0, v0.3.0, v0.4.0 (611b04b).

REFLECTION. The release template held a FOURTH time (0023 → 0027 → 0031 → 0033): structural doc
reconciliation, an honest claim, the never-run-CI amendment disclosed, a re-measure at the tagged
commit, publish steps per-action gated. What made v0.4 easy was what v0.3 earned: v0.3 STATED the
conformance claim, so v0.4 had NO new claim to make — uri-parse-result-validate is the same audited
recognizer (0030) reached from a parse result, a new CAPABILITY not a broadening, and the release
said exactly that. The house rule "a property is measured or it is not claimed" now cuts both ways:
it stopped v0.1/v0.2 from over-claiming, and here it kept v0.4 from re-claiming — the discipline is
symmetric. The one judgement was semver: a new backward-compatible export is MINOR (0.3.0 → 0.4.0),
the same call as uri-collector-reset! for v0.3, applied mechanically. The diff was surgical and
verified so (README: status + two added sentences, every frozen claim/caveat verbatim; CHANGELOG:
one new dated block + link updates, frozen entries untouched).

NEXT (v0.4 is DONE; what reopens is a SEPARATE choice, not a v0.4 gap — 0033 consequences). The
chez-http-server sibling asks on the parse/validate surface are now ALL resolved and RELEASED
(#9/#10/#11 + the audit + result-level validation); a per-connection server reuses a collector AND
validates its finish! result with no re-parse, on the audited recognizer, from a tagged release.
The open directions, each its own decision: (1) the FIRST FUNDED CI RUN — discharges 0017 item 3
and its two never-executed predictions, replacing the macOS-arm64-local disclosure every release
so far (v0.1–v0.4) has carried with cross-platform evidence; (2) v0.4+ TOOLING — the deferred
abnfgen positive generator / host-aware mutator (0012), or a relative-reference serializer above
recompose (0022); (3) the OPTIONAL result/collector-level authority-form validator deferred by 0032
item 4, if a CONNECT-target-reuse request ever measures the need; (4) the next SIBLING request.
Housekeeping: the superseded WIP branch feat/conformance-audit (115764d, pre-#11 base) is still
present locally and can be pruned. The tree is clean on main at 611b04b, tagged v0.4.0.

═══════════════════════════════════════════════════════════════════════════════════════════════

ISSUE #21 SEED (2026-09-24). The next SIBLING request from chez-http-server (NEXT direction (4)).
Its M2.3 core keeps the request-target as a SPAN `[start, end)` of the socket's buffer. Per-request
allocation must not grow with the target's length (its decision 0002, second amendment). It judges
origin-form's path and query with `(uri charset)`'s `validate-component`, not the collector:
RFC 9112's absolute-path is `1*( "/" segment )`, but a collector reads a leading `//` as an
authority (`//a@b:c/d` → uri-parse-validate 'uri-reference answers invalid-port@6).
`validate-component` took only a whole bytevector, so the server COPIED each part first. Issue
measured on v0.4.0: validate-component allocates 0 B, while the copy costs 16/80/512 B at 2/46/500
bytes, the only length-dependent cost. The additive ask: an optional `start`/`end`, with the index
relative to start. A ranged validate-authority is optional ("not needed for v1").
Decision 0034 written (7 items). Item 6 DEFERS the ranged validate-authority, per the 0032 item 4
precedent. No new library, no lane registration change, and no README/CHANGELOG at merge (rides the
next release, 0032 item 5).

ISSUE #21 WORK DONE (branch feat/validate-component-range, off main 102c8c9). TDD: a new
`validate-component over a range` group in the already-registered unit.charset lane was written
FIRST and witnessed RED (all 5 new cases: "incorrect number of arguments 4"). Then src landed and it
went GREEN. src/uri/charset.sls: `validate-component` became a case-lambda (2/3/4 args) over one
`validate-span`, with a range guard (fixnums, 0 ≤ start ≤ end ≤ length, else assertion-violation).
validate-scheme and validate-content now take `s e`, report `(fx- i s)`, and bound the pct guard by
`e`. The two-argument call is the ranged call with the default range: one implementation, no second
one to drift. The group has four parts. (1) Oracle agreement under HOSTILE surroundings: 4
components × 15 shapes × 7 surroundings, where `" "` trips a scan from 0 or to the buffer end,
`"41"` completes a `%`/`%4` cut at end, and a valid prefix shifts absolute off relative; the tally is
checked. (2) Hardcoded pins, independent of the oracle
([[equivalence-tests-need-an-independent-reference]]). (3) Refusal of `(1 0)` and `(0 9)` on "a b".
(4) Allocation length-independence: 2 B vs 4000 B spans over 1000 calls. MUTATION-WITNESSED: 14
mutants, each asserted to land, ALL redden. Raw measure: 0 B/call at 2/46/500/4000 bytes (the 160 B
read is the statistics call itself, identical at 0 calls). Source lane: unit.charset 13 cases, 1270
checks, 0 failures. Registered suite re-measured on this tree (2026-09-24, Darwin arm64, Chez 10.4.1
tarm64osx, CMake/CTest 4.3.3): release 77/77, no-scheme 11/11, 0 failures. The count is unchanged
at 77, since there is no new lane; unit.charset.chez.aot carries the allocation check compiled.

THE TEST-AUTHORING TRAP, CAUGHT BY ITS OWN MUTANTS. The first refusal case passed with the range
guard DELETED (M8/M9/M10 survived). Its thunk returned validate-component's TWO values into
check-raises' single-value `(list 'returned (thunk))`, and Chez raises an &assertion for that on its
own, so `assertion-violation?` matched whatever the range was. It had also "passed" in the RED run,
where the arity error is an &assertion too. Fix: the thunk returns ONE value (the verdict list).
Now M8 reddens both rows, M9 reddens (1 0), and M10 reddens (0 9). A negative start or a non-fixnum
is ALSO refused by R6RS's own bounds/fixnum checks: a structural guarantee, not a witness for the
guard, and recorded as such in 0034.

ISSUE #21 MERGE-GATE REVIEW (/code-review xhigh, inline; 7 findings, all applied). (1) The refusal
predicate was bare `assertion-violation?`, so 4 of the 6 rows passed with the guard deleted: R6RS's
own bounds/fixnum checks are &assertion too. The rows now require who = validate-component, and
the guard-deletion mutant reddens ALL SIX. (2)+(3) The allocation check was one window, path only.
It is now all four components, each the least of three windows (a collection firing inside one
window cannot redden it). A copy in the scheme, query or fragment arm alone is now witnessed.
(4) Decision 0034 said "(uri charset) keeps its one export"; it exports three, and the wording is now
"gains no export". (5)+(7) The range guard and `bytevector-length` ran before the component dispatch,
so `(validate-component 'bogus 42)` blamed bytevector-length, and the 2-arg hot path (uri collect)
re-checked a range valid by construction. src now resolves the component FIRST (`judge-of` → a
top-level per-component judge, no allocation) and guards only the 3/4-arg clauses (`judge-range`).
A new ordering case was witnessed RED first. (6) The `tried` count check could not fail (a counter
vs the product of the same lists' lengths), so it was removed. Re-measured 2026-09-24 (Darwin arm64,
Chez 10.4.1): unit.charset source 14 cases, 1274 checks, 0 failures. 20 mutants, all redden. 0
B/call for every component at 2/46/500/4000 bytes.

ISSUE #21 MERGED (2026-09-25). PR #22 squash-merged to main as bb8392a; issue #21 auto-closed by
"Closes #21". Merged over the RED linux-amd64 check, re-confirmed as the decision-0017 billing
refusal: 0 steps, no runner, ~3s, the "recent account payments have failed" annotation. Not a test
result. Merge gate: release 77/77 and no-scheme 11/11, 0 failures, measured locally on exactly the
merged tree (9c4719e, Darwin arm64, Chez 10.4.1 tarm64osx), with the squash pinned to that head by
--match-head-commit. Local main fast-forwarded 102c8c9 → bb8392a. feat/validate-component-range was
deleted local and remote. Lineage on main: … → 611b04b (v0.4 release) → 102c8c9 (v0.4 close-out) →
bb8392a (#21). Tags are unchanged (v0.1.0–v0.4.0), so #21 is post-v0.4.0 and UNRELEASED.

REFLECTION. A small, honest additive: one export gains an optional range, the whole-bytevector
call is unchanged for every input, and the property the sibling needed (no allocation that grows
with the target) is pinned by a check rather than asserted. What went well: the independent-reference
discipline ([[equivalence-tests-need-an-independent-reference]]) was applied FROM THE START this time.
The range sweep grades against the test-side oracle on the copied-out span, and the pins are
hardcoded. The surroundings were chosen adversarially, one per way of reading outside the span, so
every mutant that reads out of range reddened on the first try. What did not: the SAME family of
defect the gate has now caught FOUR times running (audit → v0.3 → #18 → here) — a check that passes
whether the code is right or wrong. It came in two forms this time. First, a multi-value thunk in
check-raises raised on its own. It was caught by my own mutants before the review; see
[[check-raises-needs-a-single-value-thunk]]. Second, the review found an `assertion-violation?`
predicate that R6RS's own bounds/fixnum checks also satisfy, which left 4 of 6 refusal rows
toothless. I had written that down as "a structural guarantee, not a witness" instead of making the
rows witnesses. The fix, `condition-who`, cost one line. The lesson sharpens the house rule: when
the predicate is broad, the check is only as strong as what ELSE satisfies it. So pin WHO raised,
not just that something did. The review also paid for itself on the API: naming the component
before the range restored the old misuse diagnostic, and it removed a redundant guard on (uri
collect)'s hot path in the same move.

NEXT (#21 is DONE and merged; nothing outstanding). chez-http-server can drop its copy workaround
(and the explicit copy term in its length-independence check) once it consumes a uriparse that
carries bb8392a, by gitlink now or by the next tag. The open directions are each their own
decision, NOT a #21 gap. (1) The FIRST FUNDED CI RUN (0017 item 3). The billing refusal has now
been re-confirmed on #19, #20 and #22. (2) v0.4+ TOOLING (0012 abnfgen / host-aware mutator; 0022
relative-reference serializer). (3) The DEFERRED ranged validate-authority (0034 item 6) and the
result-level authority-form validator (0032 item 4), if a request measures the need. (4) A v0.5
release whenever the maintainer wants the ranged validate-component stated in a tag + CHANGELOG.
(5) The next SIBLING request. The tree is clean on main at bb8392a.

═══════════════════════════════════════════════════════════════════════════════════════════════

v0.5 RELEASE SEED (2026-09-25; "Do the v0.5 release"). NEXT direction (4). The arc since v0.4.0
(tag on 611b04b) is ONE merged change: issue #21, the ranged validate-component (bb8392a). As with
v0.2 to v0.4, the only work is the release ACT. Evidence: CI STILL never run (the #21 PR's
linux-amd64 was the 0017 billing refusal: 0 steps, no runner, ~3s), so the basis is
macOS-arm64-local. Claim: NO NEW claim. The ranged form is the same M3 component charset judge that
uri-parse-validate applies (audited at 0030), reached over a span. It judges CHARSET, not structure,
and the CHANGELOG says so, because an origin-form server makes the split itself. Bump is MINOR
(0.4.0 → 0.5.0): optional args on an existing export are backward compatible, the same call as
v0.3/v0.4.

v0.5 RECONCILIATION DONE (branch chore/release-v0.5.0, off main d06b556). CMakeLists VERSION 0.4.0 →
0.5.0. README.org: status → v0.5.0 (2026-09-25, the UTC-date convention of v0.3/v0.4). The summary
gains one sentence (judge a buffer-held span in place, #21), and the API paragraph names
validate-component and its optional range. Every frozen claim and caveat is kept VERBATIM.
CHANGELOG.md: [Unreleased] → [0.5.0] - 2026-09-25. Its preamble discloses CI-never-run, the billing
refusal, 77/77 and 11/11, and "no new conformance claim". One feature section, including the
charset-not-structure boundary. A fresh [Unreleased] and updated version links; frozen
[0.4.0]..[0.1.0] untouched. Decision 0035 written (7 items; successor to 0023 → 0027 → 0031 →
0033). The release-verification gate (0035 item 6) is RE-MEASURED HERE on the reconciled tree,
since this session can build: release 77/77, no-scheme 11/11, 0 failures (2026-09-25, Darwin arm64,
Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3). `git diff -- src test` against main is empty. Publish
steps (squash merge pinned by --match-head-commit, annotated tag v0.5.0, tag push) wait for the
closing ritual, which is asked for first.

v0.5.0 RELEASED (2026-09-25). PR #23 squash-merged to main as 4d95118, pinned to the tested head
2c64659 by --match-head-commit. The merged tree de761a8 is byte-identical to the re-measured tree,
checked before tagging. Merged over the RED linux-amd64 check, re-confirmed as the decision-0017
billing refusal: 0 steps, no runner, ~3s, "recent account payments have failed". Annotated tag
v0.5.0 (d245f43) was placed on 4d95118, GPG-signed (tag.gpgSign; good signature, key
D4D955D55C8853D7) and pushed over SSH; it dereferences to 4d95118 on origin, confirmed.
chore/release-v0.5.0 was deleted local and remote. A GitHub Release was NOT cut (0035 item 7); if
wanted, its body is the CHANGELOG [0.5.0] section verbatim. Lineage on main: 611b04b (v0.4) →
102c8c9 → bb8392a (#21) → d06b556 (#21 close-out) → 4d95118 (v0.5 release). Tags: v0.1.0 to v0.5.0.

REFLECTION. The release template held a FIFTH time (0023 → 0027 → 0031 → 0033 → 0035), and two
things were tighter than before. (1) The re-measure gate ran IN SESSION on the reconciled tree
rather than being delegated to the maintainer. Then the squash was pinned with --match-head-commit
and the merged tree hash compared to the tested one, so "re-measured at the tagged commit" is a
checked identity (de761a8 = de761a8), not an inference from "docs-only"
([[verify-and-emit-integrity-claims]] applied to the release itself). (2) The claim needed one
explicit boundary v0.4 did not: the ranged form judges CHARSET, not structure. An origin-form
server is exactly the embedder who might read "validates the path" as "validates it's an
absolute-path", so the CHANGELOG says the split is the caller's. Otherwise, the house rule held
symmetrically again: no new conformance claim, because none was earned. The capability (judge a
span in place, 0 B/call) is stated with its measurement. Semver was mechanical: optional args on an
existing export are MINOR.

NEXT (v0.5 is DONE; what reopens is a SEPARATE choice, not a v0.5 gap; see the 0035
consequences). chez-http-server can consume v0.5.0 by tag and retire its copy workaround and the
copy term in its length-independence check. The open directions are each their own decision:
(1) the FIRST FUNDED CI RUN (0017 item 3). Every release v0.1 to v0.5 has shipped on macOS-arm64-local
evidence, and the billing refusal is now re-confirmed on #19, #20, #22 and #23. (2) The deferred
ranged validate-authority (0034 item 6) and the result-level authority-form validator (0032 item 4),
if a request measures the need. (3) v0.5+ TOOLING (0012 abnfgen / host-aware mutator; 0022
relative-reference serializer). (4) The next SIBLING request. The tree is clean on main at the
close-out commit, and v0.5.0 is tagged on 4d95118.

═══════════════════════════════════════════════════════════════════════════════════════════════

ISSUE #24 SEED (2026-09-25). The next SIBLING request from chez-http-server: RFC 9112 §3.2's Host
rules (400 on missing, duplicate, or invalid Host). The core keeps header values as SPANS of the
socket's buffer, so a Host value must be judged in place. validate-authority and
authority-host-span took only a whole bytevector. The issue measured the copy (16/32/32/32/64 B
over its five hosts, growing with the value), and the program was RE-RUN here with identical
output. This is exactly what 0034 item 6 deferred "once a request measures the need". Maintainer
decision (2026-09-25): host bounds RELATIVE to start, one rule for every ranged judge (the issue
allowed absolute). Decision 0036 written (7 items).

ISSUE #24 WORK DONE (branch feat/authority-range, off main e0aa810). TDD: a new group in the
already-registered unit.host lane was written FIRST and witnessed RED (all 5 new cases). The
refusal rows also reddened on the arity error, because the who-check from the #21 review rejected
it ([[check-raises-needs-a-single-value-thunk]]). src/uri/host.sls changes:
- the two bodies became `authority-fault` / `host-span` over [s, e), returning indices into bv;
- the exports became case-lambdas: 1-arg straight through, relative = absolute at 0; 3-arg
  guarded and rebased by `(fx- … start)`;
- one local `check-range` names the procedure called.
Only the entry points ever assumed a whole bytevector; every helper already took [s, e). GREEN
first run: the 15 hand-derived host-bounds pins matched the existing code. authority-host-span had
NO direct check before; now it is pinned whole and as a span. MUTATION: 32 mutants.
A5/A9 SURVIVED at first: the empty-host test against the length needs a "[" right after end, and
the ":" search to the buffer end needs an invalid byte before a later ":". The fix was two more
surroundings ("[" and " :1"). After that, 31 redden. B3 (host-span empty-host test against the
length) is EQUIVALENT: it reads bv[end], but every branch then yields (end, end). It is recorded
in 0036 with that reason. Measured: 0 B/call for both procedures on the issue's hosts and on
4000-byte values. unit.host source: 15 cases, 247 checks, 0 failures. Registered suite: release
77/77, no-scheme 11/11, 0 failures (2026-09-25, Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest
4.3.3). No new lane.

ISSUE #24 MERGE-GATE REVIEW (/code-review xhigh, inline). 4 findings, no correctness bug, and all
applied on the maintainer's "apply the 4 cleanups" (PR #25 open).
(1) The range guard was two copies: charset's judge-range and host's check-range. It is now ONE
new pure library, `(uri range)` (check-range), imported by both.
(2) authority-fault and host-span each re-derived the bracket-aware split. That is now ONE
`authority-split` → (values at hp kind delim), read by both, so 0025 item 4's "the SAME split" is
structural. A side effect: the first round's equivalent mutant (B3) is GONE. The empty-host test
is now the split's one line and validate-authority observes it (S4 reddens).
(3) The range-test techniques copied from unit.charset now live ONCE in the harness library
`(uri test ranged)`: results-of, raised-by?, least-allocation, for-each-placement. Both lanes use
it. It is named ranged.sls, not range.sls, because lane manifests key measured copies by basename,
and src's range.sls shares those manifests.
(4) Decision 0036 overstated its own coverage ("12 hostile surroundings", one of which is the
whole-buffer placement); it now says 11 plus the whole buffer.
New libraries were registered in the provenance manifests: range.sls in URI_COLLECT and the
normalize lane; URI_RANGED_LIB in unit.charset and unit.host. The design-doc library table gains
`(uri range)`. Decision 0036 was amended (items 1, 4, 7, Evidence). Behaviour is preserved:
charset, host, collect, normalize and authority-form all passed unchanged on the refactored src
before the tests moved. The mutation set was rebuilt: 29 mutants over the split, the fault path,
the bounds and `(uri range)`, with the guard's mutants run against BOTH lanes; ALL redden. The 16
non-guard charset mutants of #21 were re-run, and all redden. unit.charset source: 14 cases, 1274
checks. unit.host source: 15 cases, 247 checks. Release 77/77, no-scheme 11/11, 0 failures (2026-09-25, Darwin
arm64, Chez 10.4.1).

ISSUE #24 MERGED (2026-09-25). PR #25 squash-merged to main as 7d19f9b, pinned to the tested head
cfe5c96 by --match-head-commit. The merged tree 8085011 is byte-identical to the tested tree. Issue
#24 was auto-closed by "Closes #24". Merged over the RED linux-amd64 check, re-confirmed as the
decision-0017 billing refusal: 0 steps, no runner, ~3s. Merge gate: release 77/77 and no-scheme
11/11, measured locally on that tree. feat/authority-range was deleted local and remote. Lineage
on main: … → 4d95118 (v0.5 release) → e0aa810 (v0.5 close-out) → 7d19f9b (#24). Tags are
unchanged (v0.1.0 to v0.5.0), so #24 is post-v0.5.0 and UNRELEASED.

REFLECTION. The #21 template transferred almost mechanically, because the discipline it earned was
applied from the first commit rather than rediscovered at the gate: who-checked refusal, an
independent oracle for the verdict, hand-derived pins where there was no oracle (host bounds), and
hostile surroundings. The mutation run did its job twice, in two different ways. First, it found
two MISSING surroundings (A5, A9): a hostile byte only matters where the code would look for it,
and my first list covered the obvious delimiters but not "a delimiter right after an empty host" or
"invalid bytes before a later delimiter". Second, it found one EQUIVALENT mutant, and the review's
cleanup (one split instead of two) made it disappear. That is the useful lesson: an equivalent
mutant in duplicated code is often a sign that the duplicate carries a check the other copy
already makes observable. Merge the copies and the mutant becomes witnessable. The review this
time found no bug, only structure. The three structural cleanups (one guard, one split, one test
toolkit) each remove a way for two copies to drift, and each drift would have been a silent
contract break between the ranged judges.

NEXT (#24 is DONE and merged). chez-http-server can land its RFC 9112 §3.2 invalid-Host-value rule
once it consumes a uriparse carrying 7d19f9b. The open directions are each their own decision:
(1) a release stating the ranged (uri host) procedures (the maintainer asked for one, next);
(2) the FIRST FUNDED CI RUN (0017 item 3);
(3) the result-level authority-form validator (0032 item 4), if a request measures the need;
(4) tooling (0012, 0022);
(5) the next sibling request.

═══════════════════════════════════════════════════════════════════════════════════════════════

v0.6 RELEASE SEED (2026-09-25; "lets cut a 0.7 release"). The maintainer wrote 0.7. Asked once, with
v0.5.0 the last tag, they chose v0.6.0, so the version history has no gap. The arc since v0.5.0 (tag
on 4d95118) is ONE merged change: issue #24, the ranged validate-authority / authority-host-span
(7d19f9b), with its review cleanups. Evidence: CI STILL never run (the #24 PR's linux-amd64 was the
0017 billing refusal: 0 steps, no runner), so the basis is macOS-arm64-local. Claim: NO NEW claim.
It is the same M4 host judge, reached over a span. It judges an RFC 3986 AUTHORITY, not RFC 9110's
Host, and the CHANGELOG names the server's part (refusing userinfo; accepting an empty Host or
not). Bump is MINOR (0.5.0 → 0.6.0).

v0.6 RECONCILIATION DONE (branch chore/release-v0.6.0, off main 2623d6f). CMakeLists VERSION 0.5.0 →
0.6.0. README.org: status → v0.6.0 (2026-09-25, UTC-date convention). The summary gains one clause
(judge a Host value in place, #24), and the API paragraph names validate-authority,
authority-host-span and their optional range, with results relative to start. Every frozen claim
and caveat is kept VERBATIM. CHANGELOG.md: [Unreleased] → [0.6.0] - 2026-09-25. Its preamble
discloses CI-never-run, the billing refusal, 77/77 and 11/11, and "no new conformance claim". One
feature section, including the authority-not-Host boundary. A fresh [Unreleased] and updated
version links; frozen [0.5.0]..[0.1.0] untouched. Decision 0037 written (7 items). The release
gate was re-measured HERE on the final reconciled tree, the exact tree committed (2026-09-25,
Darwin arm64, Chez 10.4.1 tarm64osx, CMake/CTest 4.3.3): release 77/77, no-scheme 11/11, 0 failures.
`git diff -- src test` against main is empty.
Publish steps (squash merge pinned by --match-head-commit, tree-hash compare, annotated tag v0.6.0,
tag push) wait for the closing ritual, which is asked for first.

v0.6.0 RELEASED (2026-09-25). PR #26 squash-merged to main as 40d645f, pinned to the tested head
5c3d93f by --match-head-commit. The merged tree 04baae8 is byte-identical to the re-measured tree,
checked before tagging. Merged over the RED linux-amd64 check, re-confirmed as the decision-0017
billing refusal: 0 steps, no runner, ~3s. Annotated tag v0.6.0 (cf7492c) was placed on 40d645f,
GPG-signed (tag.gpgSign; good signature, key D4D955D55C8853D7) and pushed over SSH; it
dereferences to 40d645f on origin, confirmed. chore/release-v0.6.0 was deleted local and remote. A
GitHub Release was NOT cut (0037 item 7); if wanted, its body is the CHANGELOG [0.6.0] section
verbatim. Lineage on main: 4d95118 (v0.5) → e0aa810 → 7d19f9b (#24) → 2623d6f (#24 close-out) →
40d645f (v0.6 release). Tags: v0.1.0 to v0.6.0.

REFLECTION. The template held a SIXTH time (0023 → … → 0035 → 0037). One new thing and one
tightening. New: the release request said "0.7" against a last tag of v0.5.0. A tag is
outward-facing and effectively permanent, so the version was ASKED once rather than silently
"corrected" or silently skipped. The maintainer chose 0.6.0, and 0037 records the question and the
answer. Tightening: v0.5 re-measured the tree "before its commit", but docs landed after that run.
This time the ledger and decision were edited, then the suite was re-run on the EXACT tree
committed. So the tested tree = the committed tree = the merged tree = the tagged tree, with each
link checked (a hash compare, not an inference that only docs changed). The claim needed the same
kind of boundary v0.5's did, for the same reason: the embedder most likely to over-read it is an
HTTP server. The CHANGELOG says the functions judge a URI authority, not a Host, and names the two
parts of RFC 9110's Host rule that stay the server's.

NEXT (v0.6 is DONE; what reopens is a SEPARATE choice, not a v0.6 gap; see the 0037
consequences). chez-http-server can consume v0.6.0 by tag and land its invalid-Host-value rule,
copying nothing. The open directions are each their own decision:
(1) the FIRST FUNDED CI RUN (0017 item 3). Every release v0.1 to v0.6 has shipped on
macOS-arm64-local evidence, and the billing refusal is re-confirmed on #19, #20, #22, #23, #25 and
#26.
(2) The result-level authority-form validator (0032 item 4), if a request measures the need.
(3) v0.6+ TOOLING (0012, 0022).
(4) The next SIBLING request.
The tree is clean on main at the close-out commit, and v0.6.0 is tagged on 40d645f.

v0.6.0 GITHUB RELEASE CUT (2026-09-25, on the maintainer's request). "v0.6.0 — ranged authority
validation" was published from the existing signed tag (--verify-tag, so no new tag was created) and
marked Latest. Its body is the CHANGELOG [0.6.0] section VERBATIM, CI disclosure included (0037 item
7), checked twice: the extracted file against CHANGELOG.md, and the published body against the
file. It is the repo's FIRST GitHub Release; v0.1.0 to v0.5.0 remain tags only.

v0.6.1 RELEASED (2026-09-26, on the maintainer's request). A PIN BUMP ONLY, for chez-http-server's
`make check-pins`: it needs uriparse released on the same byte-machine as chez-httparse, and
chez-httparse v0.4.3 moved to byte-machine v0.6.1. vendor/byte-machine moved 0245db3 → 5c1cb7e
(upstream #140, #141, #142; byte-machine#139). Upstream src changed ONLY runtime.sls, and there only
the keyword walk (kw-prefix? → kw-common under byte-machine-keyword-step/v1). src/generated/
uri-scanner.sls has zero `keyword` references, and `make parser-refresh` at the new pin (exit 0,
"wrote 28766 bytes") left it byte-identical. The release also bumped CMakeLists VERSION and the
README status to 0.6.1: the brief said "change nothing else", but a v0.6.1 tag whose build prints
"chez-uri 0.6.0" is a defect, so it was ASKED, and the maintainer chose the bump. Measured on the
exact committed tree (macOS arm64, Chez 10.4.1 tarm64osx): test-all 77/77, no-scheme 11/11, 0
failures; the build prints "chez-uri 0.6.1". PR #27 squash-merged as 88d538f. Merged tree
02e87f8 = tested tree 02e87f8 (hash compare). Merged over the RED linux-amd64 check, re-confirmed as
the decision-0017 billing refusal: 0 steps, ~2s, "recent account payments have failed". Annotated
tag v0.6.1 (849fdf0) on 88d538f, GPG-signed (tag.gpgSign; good signature, key D4D955D55C8853D7),
pushed; it dereferences to 88d538f on origin, confirmed. chore/release-v0.6.1 deleted local and
remote. GitHub Release "v0.6.1 — pin byte-machine v0.6.1" published from the signed tag
(--verify-tag) and marked Latest; its body is the CHANGELOG [0.6.1] section VERBATIM, published body
diffed against the extracted file. Tags: v0.1.0 to v0.6.1; Releases: v0.6.0, v0.6.1.

REFLECTION. Three things. (1) A PIN-BUMP RELEASE STILL MOVES FOUR THINGS, not two: the gitlink, the
CHANGELOG, CMakeLists VERSION and the README status. "Change nothing else" named only the first two;
the other two are part of cutting any version, so the conflict was surfaced before tagging, not
resolved silently either way. Nothing checks that VERSION matches the newest CHANGELOG heading; that
is a candidate check, not a v0.6.1 gap. (2) chez-httparse's v0.4.3 reflection says a byte-identical
regeneration does not mean the runtime is unchanged. So the upstream runtime.sls diff was READ, not
inferred from the byte-identical scanner: the one moved definition is the keyword walk, and the
scanner never reaches it. (3) A REGENERATE-AND-DIFF CHECK IS VACUOUS IF THE REGENERATOR DID NOT RUN.
The first `make parser-refresh` redirected to a bad log path, so the shell failed before make ran,
and `git status` came back clean anyway: "byte-identical" would have been claimed off a no-op. The
nonzero exit caught it. The rerun was trusted only on exit 0 plus uri-emit's "wrote N bytes" line.

NEXT. Unchanged from v0.6.0: (1) the first funded CI run (0017; the billing refusal is re-confirmed
on #27); (2) the result-level authority-form validator (0032 item 4), if a request measures the
need; (3) v0.6+ tooling (0012, 0022); (4) the next sibling request. chez-http-server can now pin
uriparse v0.6.1 alongside chez-httparse v0.4.3.

---

CI FUNDED, FIXED AND GREEN (2026-10-01, PR #28, on the maintainer's request). The Actions minutes
came back on 2026-10-01. All 65 earlier runs (2026-09-18 to #27) were refused before a single step;
the jobs API shows none ran. chez-httparse's #58 found two defects on its first funded run, and
uriparse had both. (1) THE WORKFLOW NEVER FETCHED THE PRIVATE SUBMODULE, and the job's token cannot
read it. A fresh clone without it fails configure under `dev` (UriSchemeLane.cmake:267) and
`no-scheme` (:386). (2) FOUR `cmake -P` SCRIPTS LACKED THE 3.26 FLOOR: CorpusProvenanceSpec,
RenameAuditSpec, UriImportAuditSpec, UriExpectExit.cmake. Fix: the workflow steps are byte-identical
to chez-httparse's (require SUBMODULES_READ_TOKEN by name; checkout this repo alone; "Init
submodules" through a GIT_CONFIG_* rewrite scoped to the org's URLs). The four scripts get the
floor, and `harness.script-policy-floor` (a renamed port of chez-httparse's spec) checks every
`-P` script as text. CI prints `cmake --version`. Watched red: on the unfloored tree it failed
exactly the four (16 scripts audited), and five staged mutations each failed for the declared
reason. REHEARSAL on Kitware's CMake 3.31.6 (SHA-256 verified, the runner's version): main passed
every preset (11/11, 77/77, 77/77), but instrumenting UriExpectExit in a scratch clone showed 39
verdicts entered and only 19 returned. All 20 wrong-status verdicts died on IN_LIST (CMP0057
unset), and the Scheme mutation suite counted each crash as a catch. On the branch, 39/39 returned
(19 ok, 11 mismatch, 9 out-of-vocabulary), and pr 78/78, release 78/78, no-scheme 12/12 held under
3.31.6 and 4.3.3 alike. A CMP0053 `@URI-SEMI@` hypothesis was probed and is false: 3.31.6 leaves
it alone. The submodule step was rehearsed against a stand-in rewrite target: it clones the pinned
5c1cb7e, and no config keeps the rewrite. FIRST FUNDED RUN: attempt 1 of 36870151249 stopped at the
token step, as designed. The maintainer added the secret, and attempt 2 passed: ubuntu-24.04
(20260920.314), runner 2.337.0, Chez 10.4.1 built from source (cache miss, saved as
chez-Linux-X64-10.4.1-threads), ta6le, CMake 3.31.6, pr 78/78, release 78/78, no-scheme 12/12, in
5m41s. DECISION 0039 records it and settles 0017 item 3. ta6le derives linux/amd64 by exact match,
and that comparison is live: on macOS the four lanes pass with darwin and fail with linux. All 25
aot lanes pass on a cold runner. The README banner, the 0017 header and CHANGELOG [Unreleased]
follow. The rerun on 4246ae4 (36875607047) restored the cache: green in 1m28s. PR #28 squash-merged
as 5cf4222. Merged tree 4dd4cbb = tested tree 4dd4cbb (hash compare). fix/ci-submodule-token deleted
local and remote. IN PARALLEL a separate session cut fix/ci-pin-runner-image (decision 0038:
ubuntu-24.04 pinned, the Chez cache keyed on the OS release). It conflicts with #28 in ci.yml (both
insert a step after checkout) and in CHANGELOG. The plan is to rebase it onto main once that
session ends, keeping both steps.

REFLECTION. Four things. (1) A GREEN SUITE ON A NEW TOOLCHAIN CAN STILL BE HOLLOW. On CMake 3.31.6,
main passed everything while 20 mutation catches were a crashing verifier. The runner calls any
nonzero exit "caught" and keeps the verifier's output to itself. Even EXPECT_OUTPUT_MATCHES passed,
because UriExpectExit echoes the child's output before its verdict. Only counting verdicts entered
against verdicts returned showed it. When the toolchain under a verifier changes, count the path,
not the colour. (2) REHEARSE THE GATE'S TOOLCHAIN BEFORE SPENDING ITS MINUTES. CMake 4 cannot show
a CMake 3 policy default at all, so no laptop run could have found this. A checksum-verified
tarball in the scratchpad reproduced the runner in minutes, and the first funded run became a
confirmation instead of a discovery. (3) A HYPOTHESIS ABOUT A TOOL IS ONE PROBE FROM A FACT. The
`@URI-SEMI@` theory never reached the CHANGELOG, because a five-line probe refuted it. "65 runs
refused" entered 0039 only after the jobs API confirmed it. (4) chez-httparse's "a gate that has
not run has not passed" held exactly. The workflow could not have passed its first funded run, and
nothing could say so while every run was refused.

NEXT. (1) Node 24: every run warns that checkout@v4 and cache/restore|save@v4 target Node 20 and
are forced onto Node 24. Bump to checkout@v7 and cache@v6, all declaring node24 (runner 2.337.0 is
past their 2.327.1 floor). (2) fix/ci-pin-runner-image rebased onto main and merged (0038). (3) The
result-level authority-form validator (0032 item 4), if a request measures the need. (4) v0.6+
tooling (0012, 0022). (5) The next sibling request. A release cut from here can cite a green run on
its own commit (0039 item 5).

---

NODE 24 ACTIONS (2026-10-01, PR #29, on the maintainer's request). Every run warned that
actions/checkout@v4 and actions/cache/restore|save@v4 target Node 20, which GitHub has deprecated,
and were being forced onto Node 24. They moved to the newest majors: checkout v7 (v7.0.1) and cache
v6 (v6.1.0). runs.using was read from each action.yml at its major tag: v4 is node20, and checkout
v5-v7 and cache v5-v6 are node24. v5+ need runner 2.327.1; the hosted runner is 2.337.0. The one
live risk was checkout v6's relocated credentials. Checkout v7's git-auth-helper.ts writes
`includeIf.gitdir:<workspace>/.git` (and `/worktrees/*`) into the superproject's local config,
which the submodule's clone neither reads nor matches. Run 36876977770 on 8719643 confirmed it:
Init submodules checked out 5c1cb7e under checkout@v7. No Node 20 annotation remained, only the
ubuntu-latest notice that 0038 answers. pr 78/78, release 78/78, no-scheme 12/12. THE CHEZ CACHE
MISSED, AND NOT BECAUSE OF THE BUMP. All three chez-Linux-X64-10.4.1-threads entries carry the
same version (5e7b3cfe...), so v6 matches what v4 saved. Caches are scoped by ref: a PR restores its
own entries and its base branch's, never another PR's. #28's entry lived under refs/pull/28/merge.
main's first entry was saved at 14:31:41 by the run #28's merge triggered, and #29's restore step
ran at 14:31:25. PR #29 squash-merged as a68da72. Merged tree 1b31dba = tested tree 1b31dba (hash
compare). fix/ci-node24-actions deleted local and remote. FOUND IN PASSING: ci.yml says the cache
action's own post-step "would also run after a failed build", but it declares
`post-if: success()` in v4 and v6 alike. The early save is still right, for a different reason: a
Chez proven to work is kept even if a later test fails. The comment gets corrected in the
image-pin PR, which edits that step. chez-httparse and chez-http-server still run the v4 actions.

REFLECTION. Two things. (1) A CACHE MISS IS NOT A COMPATIBILITY VERDICT. The first reading of the
miss was "v6 cannot restore what v4 saved", and it nearly entered this ledger. The caches API
showed one version across all three entries, and the timestamps showed the real cause: ref
scoping plus a 16-second race with main's first save. Read the entries before naming a cause.
(2) READ WHAT AN ACTION WRITES, NOT WHAT ITS RELEASE NOTE SAYS. "Persist creds to a separate
file" said nothing about where the file reaches. The includeIf in the source answered that, and
the run confirmed it before merge.

NEXT. (1) fix/ci-pin-runner-image (0038) rebased onto main, which now has #28 and #29. Keep both
post-checkout steps (Init submodules, then Identify the OS release), combine [Unreleased], correct
the post-step comment, then merge. (2) The result-level authority-form validator (0032 item 4), if
a request measures the need. (3) v0.6+ tooling (0012, 0022). (4) The next sibling request.

---

CI PINNED TO ubuntu-24.04 (2026-10-01, PR #30, on the maintainer's request). Every run carried
GitHub's notice that ubuntu-latest moves to Ubuntu 26.04 from 2026-10-19 (actions/runner-images
#14748; the rollout ends by 2026-11-19). Two risks rode on the label. (1) THE CHEZ CACHE KEY
IGNORED THE OS RELEASE: it named runner.os and runner.arch, and both releases report Linux/X64,
so a 26.04 runner would restore a Chez built on 24.04. (2) THE IMAGE CHOOSES CMAKE, and every
`cmake -P` script takes its policy defaults from it. The runner-images toolsets say 3.31.6 on
24.04, held "to avoid CMake 4.0 compatibility issues" (#11926, review-at 2026-12-01), and
`latest` on 26.04 (4.4.3 in image 20260920.143.1). Fix, the shape chez-http-server's #8 took:
runs-on: ubuntu-24.04 with its reason; a step `os` after Init submodules writes
release=${ID:?}-${VERSION_ID:?} from /etc/os-release; the key becomes
chez-${runner.os}-${steps.os.outputs.release}-${runner.arch}-${CHEZ_VERSION}-threads. DECISION
0038 amends 0006 item 1, and 0006 gains an Amended-by line. It records that the pin fixes the
release, not CMake, and what an image bump must state: the CMake it brings, whether any run still
exercises CMake 3, and an actionlint that knows the label (1.7.12 rejects ubuntu-26.04). The
post-step comment #29's close-out flagged is corrected: actions/cache declares
post-if: success() at v4 and v6 (read from action.yml), so the early save is what keeps a
working Chez when a later test fails. WATCHED RED, THEN GREEN, LOCALLY: a scratchpad rehearsal
(PyYAML and Docker, not committed: no new dependency) parsed ci.yml and ran the os step's script
as the runner runs a run: block (bash --noprofile --norc -eo pipefail, $GITHUB_OUTPUT
pre-created) in the local linux/amd64 ubuntu:24.04 and ubuntu:26.04 images, --pull=never. On
main it failed 11 of 12 checks, and both images rendered one key, chez-Linux-X64-10.4.1-threads.
After the fix, 12 of 12; a removed or empty ID or VERSION_ID exits 1 and writes nothing. Nine
workflow mutations were each caught by the check named for them, 9 of 9 verdicts reached.
actionlint caught 3 (the unknown 26.04 label, two broken steps.os references); its shellcheck
pass was witnessed live with an injected unquoted $VAR (SC2086). REBASED: the branch was cut
from e1997e0 while #28 was open; by the push, #28 and #29 had landed and 0039 had settled 0017.
ci.yml merged clean in the planned order (token check, checkout v7, Init submodules, os,
restore). The CHANGELOG entry went under the existing ### Fixed, 0038 was re-read and now cites
0039, and the counts moved: no-scheme 12/12, test-all 78/78 (macOS arm64, Chez 10.4.1 tarm64osx,
CMake 4.3.3). The rehearsal and all nine mutants were re-run on the rebased file. CI: run
36879385574 on f972f3d, image ubuntu-24.04 20260927.320.1. That is a newer weekly image than
0039's 20260920.314 under the same key, because the key follows the release. The restore printed
"Cache not found for input keys: chez-Linux-ubuntu-24.04-X64-10.4.1-threads", the key the
rehearsal predicted, verbatim. Chez was built from source (10.4.1, ta6le), CMake 3.31.6, then
"Cache saved with key: chez-Linux-ubuntu-24.04-X64-10.4.1-threads" (refs/pull/30/merge). pr
78/78, release 78/78, no-scheme 12/12, about 7 minutes, and NO annotations: the ubuntu-latest
notice is gone. PR #30 squash-merged as 8238d1c, pinned to f972f3d by --match-head-commit.
Merged tree 26dee92 = tested tree 26dee92 (hash compare). fix/ci-pin-runner-image deleted local
and remote. MAIN'S FIRST RUN UNDER THE NEW KEY (36880820386 on 8238d1c) missed, as 0038 item 2
says it must. main held only the old-key entry, and #30's entry lives under refs/pull/30/merge,
which main cannot read. At this close-out it was building Chez from source. Its save under
refs/heads/main, and the first restore under the new key, are for the next runs to show.

REFLECTION. Three things. (1) A REHEARSAL THAT PREDICTS THE RUNNER'S OUTPUT SAYS MORE THAN A
GREEN TICK. Green alone would not show that the key carries the release; the restore line
printing the predicted key verbatim does. (2) A LINT IS NOT A SPECIFICATION. actionlint passed
6 of 9 broken workflows: back to ubuntu-latest, the release dropped from the key, either guard
removed, the output sent to stdout, the separator dropped. Only checks of behaviour caught them.
(3) A BRANCH CUT BEFORE A PARALLEL MERGE MUST BE RE-READ, NOT JUST REBASED. The rebase merged
ci.yml cleanly, but five sentences on the branch had become false ("CI has not yet run the
suite", "0017 still holds"), and its counts were 77/11 on a tree that now holds 78/12. Text
needs a reading, not a merge. This ledger's NEXT had already given the branch its plan.

NEXT. (1) Before 2026-12-01, when runner-images reviews the 24.04 CMake hold (#11926): if it
lifts, CI's CMake moves under the pin. The runtime identity step prints it (0038 item 3). (2) The
24.04 → 26.04 move is its own commit, stating what 0038 item 4 lists. (3) chez-httparse still
runs on ubuntu-latest with a key that ignores the release, so the same port applies there before
2026-10-19. (4) The result-level authority-form validator (0032 item 4), if a request measures
the need. (5) v0.6+ tooling (0012, 0022). (6) The next sibling request.

PR #30 RE-KEY CONFIRMED ON MAIN (2026-10-01). Both post-merge runs passed on image ubuntu-24.04
20260927.320.1.
- 36880820386 on 8238d1c missed ("Cache not found for input keys:
  chez-Linux-ubuntu-24.04-X64-10.4.1-threads"). It built Chez, saved it under refs/heads/main at
  15:04:19, and passed pr 78/78, release 78/78, no-scheme 12/12.
- 36881442309 on e44ef1e is the close-out's run. That commit was pushed only after the save had
  landed, checked once in the caches API. Its restore printed "Cache restored from key:
  chez-Linux-ubuntu-24.04-X64-10.4.1-threads", the first restore under the new key. It passed the
  same counts in 1m42s.

The whole re-key cycle has now run on main: miss, build, save, restore.

---

v0.6.2 MERGED (2026-10-01, PR #31, on the maintainer's request). A PIN BUMP, for chez-http-server:
it vendors uriparse and chez-httparse, and both must share a byte-machine before it can use
`parser-error-span` and `parser-error-span-offset` for its span size limits (byte-machine#145).
vendor/byte-machine moved 5c1cb7e → c338a57 (v0.7.0; upstream #143, #144, #146–#150). The first
tag check found no v0.7.0 (its release PR #150 was still open), and the work stopped there until
the tag landed. Upstream src changed runtime.sls and compile.sls only. compile.sls adds the two
names to `reserved-member-2`, the runtime names an output binding may not take, and a census
comment. The runtime adds the two exports, and the error
record grows to ten slots, which `abandon-span!` fills in place after `parser-feed!` and
`parser-finish!`. `span-fragment-deliver!` now also sets the mark to the fragment's end
(runtime.sls:839). CHECKED: `make parser-refresh` exit 0, "wrote 28766 bytes", `git diff
--exit-code src/generated/` clean, SHA-256 eae7725f… equal to main's. ABI 9 at uri-scanner.sls:437
and runtime.sls:110. src reads only `parser-error-code` and `parser-error-offset`
(collect.sls:183), and neither new name occurs outside vendor/.

AMBIGUITY 1 AND DECISION 0018 STAY AS WRITTEN. Both say, from v0.6.0 source, that the mark is
written only to pos, 0 or the feed start (runtime.sls:748,754,1022,1177,1370). At v0.7.0 those
writes are at 767 (span-open, which the interpreter's span-start calls at 1280), 773 (close),
1124 (feed start) and 1473 (finish), plus a fourth at 839: every delivery moves the mark to the
fragment's end. Three of the five lines had already moved at v0.6.1 (1022 → 1054, 1177 → 1209,
1370 → 1402). The conclusion holds. Both delivery callers take `from` from the mark and deliver only when
from ≤ to, so the new write moves the mark forward only, and no byte the span took can be taken
back. Both records are dated 2026-09-18 and scoped to v0.6.0 source, and 0039 item 5 keeps such
records as written, so neither gets an in-place note; this entry carries the v0.7.0 lines.

Two commits: 24705c3 the gitlink alone (0002 item 6), then 65fc4cf the CHANGELOG [0.6.2] entry
(it absorbs [Unreleased]'s CI work from #28–#30), CMakeLists VERSION and the README status.
Measured on 65fc4cf's tree (macOS arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3): test-all 78/78,
no-scheme 12/12, 0 failures; the build prints "chez-uri 0.6.2". CI run 36895939900 on 65fc4cf:
ubuntu-24.04 20260927.320.1, Init submodules checked out c338a57, cache restored from
chez-Linux-ubuntu-24.04-X64-10.4.1-threads, ta6le, CMake 3.31.6, pr 78/78, release 78/78,
no-scheme 12/12, in 1m28s. The [0.6.2] summary cites the local counts only; the maintainer merged
on green without the CI line, so the run is recorded here. PR #31 squash-merged as 5ecd88f,
pinned to 65fc4cf by --match-head-commit. Merged tree 0f314cb = tested tree 0f314cb (hash
compare). chore/release-v0.6.2 deleted local and remote. FOUND IN PASSING:
test/common/generator-abi-tests.sps still says "the pin at v0.6.0" and cites runtime.sls:109 and
:175,179 (110 and 176,180 at v0.7.0). It is a separate change (0002 item 6) and is running in its
own session.

REFLECTION. Three things. (1) A CLAIM CAN LIVE IN MORE RECORDS THAN THE BRIEF NAMES. The brief
pointed at the ledger's AMBIGUITY 1; searching for `runtime.sls:` across .plans, the ledger and
test/ found the same proof in decision 0018 and pin citations in a test's comments. Search for
the claim, not for the record. (2) AN EMPTY SEARCH IS A RESULT TO CHECK. A loop over three tags
found no mark writes at all, because zsh read `$t:src` as the `:s` modifier. Nothing that
silent should enter a record; `${t}` fixed it. (3) THE FIRST MEASUREMENT RAN ON A TREE THAT WAS
NEVER COMMITTED. CMakeLists was edited while `make test-all` ran. The suites were re-run on the
exact committed tree, and only that run's counts were recorded.

NEXT. (1) Tag v0.6.2 on 5ecd88f and publish its GitHub Release, on the maintainer's word.
(2) chez-httparse moves to byte-machine v0.7.0 too, before chez-http-server can use the
accessors. (3) The generator-abi-tests citation fix (its own session). (4) Carried from #30:
the 2026-12-01 CMake hold review; the 24.04 → 26.04 move as its own commit (0038 item 4);
chez-httparse's runner pin before 2026-10-19; the result-level authority-form validator
(0032 item 4), if a request measures the need; v0.6+ tooling (0012, 0022); the next sibling
request.

---

GENERATOR-ABI CITATIONS BY NAME (2026-10-01, PR #32, on the maintainer's request). The #31
close-out's FOUND IN PASSING, as its own change (0002 item 6). Two comments in
test/common/generator-abi-tests.sps located byte-machine definitions by pin and line: "the pin at
v0.6.0 ... runtime.sls:109" above `expected-abi`, and "(runtime.sls:175,179)" in the
retired-constructor case. The version went stale at v0.6.1 (#27), the lines at v0.7.0 (#31): 110
and 176,180, read from the checked-out submodule. Both now cite by name: `current-abi-version` in
`(byte-machine runtime)`, and the /v1 and /v2 constructors the checks below spell in full. No
version, no line. COMMENTS ONLY; the lane checks what it did. NO CHECK REPLACES THE CITATION, and
that was asked before it was settled (AGENTS.md: prefer a check to a comment).
current-abi-version is not exported (absent from the export list, lines 11-49). The runtime
accepting ABI 9 is already exercised by every lane that loads src/generated/uri-scanner.sls, which
constructs with `(byte-machine-make-compiled-machine 9 ...)` at :437. One check is impossible, the
other redundant. THE GATE HELD. The brief said to start only after #31 merged. The first fetch
found it open, so the edit was drafted uncommitted while a background loop watched origin/main for
"v0.6.2". The branch was cut from 5ecd88f and the submodule initialized at c338a57. Between commit
and push main moved again (8f10f2f, the #31 close-out, whose NEXT (3) named this work). The fetch
before the push caught it, the branch was rebased, and both suites re-ran on the rebased tree.
Measured on 2227f3e (macOS arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3): test-all 78/78, no-scheme
12/12, 0 failures; the build prints "chez-uri 0.6.2". CI run 36899654226 on 2227f3e: ubuntu-24.04
20260920.314.1, runner 2.337.0, Init submodules checked out c338a57, cache restored from
chez-Linux-ubuntu-24.04-X64-10.4.1-threads, ta6le, CMake 3.31.6, pr 78/78, release 78/78,
no-scheme 12/12, in 1m21s. That image is older than #30's 20260927.320.1 under the same label: the
hosted fleet serves more than one weekly image, and the key, which names the release and not the
image, restored either way. Merged on green: PR #32 squash-merged as 34937e8, pinned to 2227f3e by
--match-head-commit. Merged tree bac8c85 = tested tree bac8c85 (hash compare).
fix/abi-test-pin-citations deleted local and remote. FOUND IN PASSING: src/uri/grammar.sls:103
cites "verify.sls:1798" the same way. It still holds at v0.7.0 (verify.sls is unchanged from
v0.6.0), so it is fragile, not stale.

REFLECTION. Three things. (1) A LINE NUMBER IS A CLAIM THE PIN OWNS. Nothing reads a comment, and
AGENTS.md forbids a test that does, so the pin-move commit that falsified these citations could
not redden. The durable fix is a comment that does not depend on the pin: a definition's name
moves only when the API does, and then the import or check beside it breaks loudly. (2) "PREFER A
CHECK TO A COMMENT" WAS ASKED, AND THE ANSWER WAS NO. Both candidate checks were impossible
(unexported) or redundant (the committed scanner already proves acceptance). Recording why keeps
the next reader from re-asking, and keeps a redundant check from being added just to satisfy the
rule. (3) THE ZSH `:s` TRAP STRUCK AGAIN WITHIN THE HOUR. #31's reflection (2) named it, and this
session hit it independently in its first survey: `$rev:src` matched nothing for two of three
tags. The empty result was treated as a fault, not a finding, and the loop re-ran with `${rev}`
before any line number was trusted. A lesson written in one session does not reach a session
already running.

NEXT. (1) Tag v0.6.2 on 5ecd88f and publish its GitHub Release, on the maintainer's word (untagged
at this close-out; Latest is v0.6.1). (2) chez-httparse moves to byte-machine v0.7.0 too, before
chez-http-server can use the accessors. (3) Optional: cite grammar.sls:103's verify.sls:1798 by
name, as its own change. (4) Carried from #30: the 2026-12-01 CMake hold review; the 24.04 → 26.04
move as its own commit (0038 item 4); chez-httparse's runner pin before 2026-10-19; the
result-level authority-form validator (0032 item 4), if a request measures the need; v0.6+ tooling
(0012, 0022); the next sibling request.

v0.6.2 TAGGED AND RELEASED (2026-10-01, on the maintainer's request). Annotated tag v0.6.2
(3cfec81) on 5ecd88f, GPG-signed (tag.gpgSign; good signature, key D4D955D55C8853D7), pushed; it
dereferences to 5ecd88f on origin, confirmed. It is the FIRST TAG CUT ON A GREEN RUN ON ITS OWN
COMMIT (0039 item 5). Run 36896649640, the push run on 5ecd88f: ubuntu-24.04 20260927.320.1, Init
submodules checked out c338a57, cache restored from chez-Linux-ubuntu-24.04-X64-10.4.1-threads,
ta6le, CMake 3.31.6, pr 78/78, release 78/78, no-scheme 12/12. The tag message cites that run.
The CHANGELOG [0.6.2] section cites only the local counts: it was merged before a CI line was
added. GitHub Release "v0.6.2 — pin byte-machine v0.7.0" published from the signed tag
(--verify-tag) and marked Latest. Its body is the CHANGELOG [0.6.2] section VERBATIM, extracted
from 5ecd88f (identical on main at 54c4e87, checked); the published body was diffed against the
extracted file. Tags: v0.1.0 to v0.6.2; Releases: v0.6.0, v0.6.1, v0.6.2.

NEXT. (1) chez-httparse moves to byte-machine v0.7.0 too, before chez-http-server can use the
accessors; it can then pin uriparse v0.6.2 alongside it. (2) Optional: cite grammar.sls:103's
verify.sls:1798 by name, as its own change. (3) Carried from #30: the 2026-12-01 CMake hold
review; the 24.04 → 26.04 move as its own commit (0038 item 4); chez-httparse's runner pin before
2026-10-19; the result-level authority-form validator (0032 item 4), if a request measures the
need; v0.6+ tooling (0012, 0022); the next sibling request.

---

PUBLIC-RELEASE COMMENT SWEEP (2026-10-11, PR #33, on the maintainer's request). Comments
across src/, tools/, cmake/, the build files, test/ and the conformance notes now read as
developer documentation: types, invariants and rationale, with no plan citations or timeline.
README.org is rewritten the same way. REMOVED: decision-record, design-doc, milestone (M1–M9),
slice, task and issue citations, release dates, and history narration ("not part of this
project yet", "a v0.2 function"). Where a citation carried the only rationale, the rationale now
stands in its place. KEPT: RFC section and erratum references, toolchain and pin facts,
invariants. .plans/ and .superpowers/ STAY as design records (maintainer's word); only the
README's links into them went. CHANGELOG.md and AGENTS.md untouched. README.org: the dated
status block and CI banner became "What it does" and "Scope and limits"; the layout table drops
.plans/ and adds tools/. src/: type-signature comments added on exports that lacked them (the
uri-parse-result and uri-components accessors, the *-error-code? predicates,
make-uri-collector, make-uri-scanner-machine). #32's FOUND IN PASSING is DONE here:
grammar.sls's "verify.sls:1798" now cites the verifier rule by name, `span-active-at-pause`.
Two message strings changed wording (charset.sls's unknown-component assertion,
charset-oracle.sls's "no charset component named"); nothing asserts on either. THE DERIVED
CORPUS HAD CITATIONS TOO: cmake/UriCorpus.cmake emits the rfc3986/ headers, and
CorpusProvenanceSpec compares emitter to file, so the fix went into the emitter followed by
`make corpus-refresh` (headers only; vectors unchanged). Six test names that cited plans were
renamed, since names are code and could not just be reworded: "m1-exit" → "corpus-completeness",
"M3/M4 … negative corpus" → "charset/host negative corpus", and the "(decision 0010)",
"decision 0019's order" and "(issue #11 path)" cases. Nothing else referenced them. Left on
purpose: uri_slice3_launcher_pass / uri_slice5b_launcher_pass (CMake names), two Ghostscript
"(2026-05-19)" version strings (test data), "decision" as an English word, the ratchet's
`not-yet` status. HOW: six Sonnet subagents in parallel against a written style guide, one per
file group, then a lead review. The subagents stripped text but did not rewrap: ~50 paragraphs
came back with 90–140-column lines and one dropped period. A dry-run reflow of changed
paragraphs only fixed them; its first pass also merged `name : A -> B` signatures and `---`
banners into prose, so those became paragraph breaks. Measured on the committed tree (macOS
arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3, byte-machine c338a57; build prints "chez-uri
0.6.2"): baseline on main 78/78; after, test-all 78/78 and no-scheme 12/12, 0 failures;
`make parser-refresh` byte-identical scanner. CI DID NOT RUN. Run 38149021887 "failed" in 3s
with "log not found": GitHub refused to start the job (annotation: account payments failed or
the spending limit needs raising). MERGED ON LOCAL EVIDENCE, on the maintainer's word, with a PR
comment stating that CI did not run and quoting the local counts. PR #33 squash-merged as
1af57aa on 9c67ecd. Merged tree e979852 = tested tree e979852 (9012ad5; hash compare).
docs/public-release-comment-sweep deleted local and remote. FOUND IN PASSING:
cmake/UriSchemeLane.cmake (~line 405) says "nine registrations" bypass the registrar and set
URI_EXECUTION_MODE by hand; test/CMakeLists.txt has eight `URI_EXECUTION_MODE=source` lines.
Unverified which is wrong.

REFLECTION. Three things. (1) A RED CHECK IS NOT ALWAYS A RED BUILD. A 3-second fail with no
log is a job that never started. The annotations said so, and reading them before merging is
what kept a billing refusal from passing as a verdict, either way. (2) DELETION HAS A LAYOUT
COST. Removing a citation is a one-clause edit, and the subagents did it cleanly, but none
rewrapped. The style guide should have required it. The reflow had to be scoped to changed
paragraphs, with signatures and banners as hard breaks, or it damages what it touches. (3) NOT
EVERY CITATION WAS A COMMENT. Some were in derived files, and their source is the emitter. Some
were in test names, which are code. A comment-only rule would have left both, or reddened the
corpus-provenance lane by editing one side of a compared pair.

NEXT. (1) CI billing, before the next PR can carry a CI verdict; then a run on main to confirm
1af57aa green. (2) Resolve UriSchemeLane.cmake's "nine registrations" against
test/CMakeLists.txt's eight. (3) chez-httparse moves to byte-machine v0.7.0, before
chez-http-server can use the accessors; it can then pin uriparse v0.6.2 alongside it. (4)
Carried from #30: the 2026-12-01 CMake hold review; the 24.04 → 26.04 move as its own commit
(0038 item 4); chez-httparse's runner pin before 2026-10-19; the result-level authority-form
validator (0032 item 4), if a request measures the need; v0.6+ tooling (0012, 0022); the next
sibling request.

---

HAND-SET EXECUTION MODES ARE CHECKED (2026-10-11, PR #34, on the maintainer's request). #33's
FOUND IN PASSING, settled by a check rather than a corrected count. cmake/UriSchemeLane.cmake
said NINE registrations in test/CMakeLists.txt bypass uri_add_scheme_lane and hand-set
URI_EXECUTION_MODE: eight .chez.source lanes plus uri.harness.scheme-mutation.cmake.direct.
There are EIGHT: seven launcher .chez.source lanes (absent-guard, dirty-guard, unknown-flag,
repeated-flag, repeated-object-guard, no-library-root, no-object-guard) and the mutation lane.
`URI_EXECUTION_MODE=source` occurs 8 times in every revision of test/CMakeLists.txt since
b598f34, so no lane was ever dropped: the comment was wrong from M1, most likely carried over by
the port. Every hand-set lane did agree with its name; only the count was false. ASKED, the
maintainer chose the spec over a comment-only fix. test/support/cmake/HandSetModeSpec.cmake
(lane uri.harness.hand-set-mode.cmake.direct, unit, no runtime) reads test/CMakeLists.txt as
text. A chez-backend registration must hand-set the mode its name ends in. Any other backend
needs a listed exemption with its reason; the only one is
`uri.harness.scheme-mutation.cmake.direct=source`. An exemption matching no registration is a
finding, and so is a mode set outside a registration call. Calls are tracked line by line, with
parenthesis depth counted after quoted strings and trailing comments are stripped. It refuses a
tree with zero hand-set Scheme modes. It EMITS what it checked: "7 Scheme registrations agree
with their names, 1 exempted". Five witness cases, including one that runs the audit over the
real file with one mode swapped, so the extraction is proven on real text. NO MutationSuite
entry: uri_mutation_stage copies cmake/, test/support/cmake/, test/conformance/ and
test/vendor/, not test/CMakeLists.txt. That follows ScriptPolicyFloorSpec, the other
text-over-test/CMakeLists.txt spec, which also relies on its own witnesses. The UriSchemeLane
comment now points at the spec and states no number. CHANGELOG [Unreleased] gains an Added
entry. WATCHED FAIL (CMake 4.3.3): launcher-unknown-flag swapped to aot reddens the real-tree
pass and names it. The mutation lane swapped to aot reports an unexempted lane and a stale
exemption. A stubbed audit fails all 5 witnesses. A depth counter that ignores ")" fails 11
assertions. The first watched failure printed one finding as THREE: a ";" inside a finding
splits the CMake list. Both messages were reworded before commit. Measured on 1694d50 (macOS
arm64, Chez 10.4.1 tarm64osx, byte-machine c338a57): CMake 4.3.3 test-all 79/79, no-scheme
13/13. CI DID NOT RUN, refused over billing again (run 38154667420, 2s; same annotation as #33).
The maintainer's #33 OK did not carry over and was asked again. The answer was REHEARSE FIRST.
Kitware cmake-3.31.6-macos-universal.tar.gz (78,374,480 bytes) was SHA-256-checked against
cmake-3.31.6-SHA-256.txt. In a scratch clone of 1694d50, with the submodule populated from the
local byte-machine and following CI's steps, CMake 3.31.6 gave: dev configure + build OK, pr
79/79, release 79/79, no-scheme 13/13. The witnesses were re-run with the 3.31.6 binary: the
swapped lane exits 1 naming it, and the stubbed audit fails all 5 ("accepted but must be
rejected"). Not rehearsed: Linux and ta6le; the spec is CMake text processing only. A PR
comment records both toolchains. PR #34 squash-merged as b97343b on 89234ec, pinned by
--match-head-commit 1694d50. Merged tree a6f12b4 = tested tree a6f12b4 (hash compare).
test/hand-set-mode-spec deleted local and remote.

REFLECTION. Three things. (1) A COUNT IN A COMMENT IS A CLAIM NOTHING CHECKS. "Nine" was off by
one from the first commit, and no change could redden it. The repair is not "eight": it is a
lane that reports its own count and refuses a stale exemption, so the next added lane is judged
rather than miscounted. (2) A GREEN REHEARSAL IS HALF THE EVIDENCE. 79/79 under 3.31.6 shows
the spec passes there, not that it can fail there. Re-running the witnesses with that binary is
what shows the check still catches something on the runner's CMake. A crash can count as a
catch; in reverse, a pass can count as a check. (3) THE FIRST FAILURE IS ALSO A TEST OF THE
FAILURE PATH. The list-splitting ";" only appears when a finding is printed, so a spec watched
only passing would have shipped it.

NEXT. (1) CI billing: two PRs have now merged without a CI verdict. When Actions runs again,
run it on main (b97343b or later) and record the first green run since 5ecd88f. (2) chez-httparse
moves to byte-machine v0.7.0, before chez-http-server can use the accessors; it can then pin
uriparse v0.6.2 alongside it. (3) Carried from #30: the 2026-12-01 CMake hold review; the 24.04
→ 26.04 move as its own commit (0038 item 4); chez-httparse's runner pin before 2026-10-19; the
result-level authority-form validator (0032 item 4), if a request measures the need; v0.6+
tooling (0012, 0022); the next sibling request.

---

README REWRITE AND NOTICE (2026-10-11, PR #35, on the maintainer's request). README.org is
rebuilt for a public reader around what, why and development. It opens with a CI badge (the
ci.yml workflow, branch main). WHY: bytes in and out, streaming chunks, a reusable collector,
in-place validation over a caller's range, lenient parsing kept apart from strict validation,
absent vs empty. WHAT IT DOES, in plain terms. USING IT: clone with submodules, the parse
example, and a to-X-use-Y table of the API. SCOPE AND LIMITS: each limit with a concrete case.
DEVELOPING: requirements, make targets, the two generated artifacts and their refresh targets,
layout. RFC SECTION NUMBERS LEFT THE README at the maintainer's word; they were RFC citations,
not plan references (said so at the time), and the source comments keep them. NOTICE is new. It
lists test/vendor/rfc3986.txt (verbatim, Copyright The Internet Society 2005, BCP 78, tests only)
and the data cmake/UriCorpus.cmake extracts from it into test/conformance/rfc3986/. It also lists
the byte-machine submodule (same owner, BSD-3-Clause, not copied in; the generated scanner is
its compiler's output). Chez Scheme and CMake are build tools and are not listed. Whether BCP 78
covers redistributing the extracted ABNF is a legal question, not settled here. CHANGELOG
[Unreleased] gains the NOTICE (Added) and README (Changed) entries. THE README WAS RUN, NOT
ONLY READ. The Scheme example, extracted from the file, prints the documented output. The why
claims were run against src/: absent query #f vs empty #vu8(); a four-chunk feed equals the
one-shot parse; `http://a/b c` is uri-parse-ok but uri-parse-validate rejects it with
invalid-pchar. The first claims script called uri-collect-feed! with two arguments (it takes
bv start end), so prose written from memory would have been wrong. Measured on cb92a8d (macOS
arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3, byte-machine c338a57): test-all 79/79, no-scheme
13/13. CI DID NOT RUN, refused over billing a third time (run 38155493873, 3s). Asked again, the
maintainer chose to merge on local evidence. No 3.31.6 rehearsal: the change touches no build or
source file. A PR comment records it. PR #35 squash-merged as 7291c18 on d640f6d, pinned by
--match-head-commit cb92a8d. Merged tree 65271be = tested tree 65271be (hash compare).
docs/readme-public deleted local and remote. FOUND IN PASSING, AND IT BLOCKS THE RELEASE:
Kiyomi-Computation-Systems/byte-machine is PRIVATE (gh api visibility). A public uriparse with
that submodule cannot be cloned or built from outside the org, so the README's
`git clone --recurse-submodules` and NOTICE's link assume a change not yet made.

REFLECTION. Three things. (1) A README IS A PROGRAM ITS READERS RUN. Its example and every
behavioural claim were executed against src/ before they were written down, the same rule as a
check over a comment. (2) NAME THE THING BEFORE REMOVING IT. The request called §5.2.3 a planning
reference. It is an RFC citation, and saying so kept the source comments' RFC references, which
serve developers, out of the removal. (3) RELEASE PREP FINDS WHAT NO PR CAN FIX. The submodule's
visibility is a setting on another repository. The ledger and the PR body record it so the
release step checks it.

NEXT. (1) Make byte-machine public before or with uriparse. Check with `gh api
repos/Kiyomi-Computation-Systems/byte-machine --jq .visibility`. (2) CI billing: three PRs (#33,
#34, #35) have now merged without a CI verdict, and the README badge shows failing until a run
passes. When Actions runs again, run it on main (7291c18 or later) and record the first green
run since 5ecd88f. (3) chez-httparse moves to byte-machine v0.7.0, before chez-http-server can
use the accessors; it can then pin uriparse v0.6.2 alongside it. (4) Carried from #30: the
2026-12-01 CMake hold review; the 24.04 → 26.04 move as its own commit (0038 item 4);
chez-httparse's runner pin before 2026-10-19; the result-level authority-form validator (0032
item 4), if a request measures the need; v0.6+ tooling (0012, 0022); the next sibling request.

---

EASY LAYER — `(uri easy)` AND `(uri query)`. Plan: .plans/2026-10-11-easy-layer.md (PR #36,
branch docs/easy-layer-plan, open). Decisions in force: 0040 (strings at the edge, one record, a
validated domain; supersedes 0010 item 3), 0041 (`(uri query)` splits the query over its bytes;
amends 0001), 0042 (`uri-normalize` removes dot segments, and a guard covers the `//` shape
resolution can reach; amends 0022). Target v0.7.0, additive: no existing library changes shape.

WHAT IT SHIPS. `(uri easy)`: string parsers for the three modes that return an opaque `Uri`
record over validated components; raw accessors, except `uri-scheme` and `uri-host`, which
return their §6.2.2 form; decoded readings (path segments, query and form pairs, `uri-decode`,
`uri-encode`) that split before they decode and are strict UTF-8; `uri->string`, `uri-resolve`,
`uri-normalize`, `uri=?`, and `uri->components` / `components->uri` down to the low layer;
`&uri-error` with a reason, a character offset and the input. `(uri query)`: `query-pairs` and
`form-pairs`, pure, over bytevectors.

SLICE PLAN (one PR per slice; GATE after ⓪, since the records are what the code is held to):
  ⓪  records 0040–0042 and the amendment headers; the 0022 counterexample pinned in
     property.round-trip; README "Scope and limits"; CHANGELOG. No src/. — GATE.
  ①  `(uri query)`: hand-derived vectors, plus an independent oracle in the harness graded by an
     exhaustive sweep over a small alphabet.
  ②  `(uri easy)`, parse and read.
  ③  `(uri easy)`, render, resolve, normalize and compare; the §5.4 corpus run through strings.
  ④  docs/easy.org, README, CHANGELOG [0.7.0], the version bump and tag.
  CLOSE — merge gate + closing ritual (ask first) + reflection.

SETTLED IN REVIEW (2026-10-11, the maintainer, in session). Bad input raises a condition. The
first version covers read, render and resolve; building from parts is a later plan. THE QUERY
SPLIT was questioned first ("why string-split when we have a parser?"). Answer: RFC 3986's query
has no internal grammar, spans do not nest (0008), and per-pair spans would change the scanner
ABI chez-http-server builds on; so it is a core sub-split like (uri host)'s, and it must split
before it decodes or `%26` becomes a live `&`. Then: `(uri query)` as a separate library. NAME:
`(uri easy)`, not `(uri)`, because one-part names map to different files across
implementations. CASE: the plan's first draft returned scheme and host as written; reviewing
the question changed the recommendation, because a raw `uri-host` lets `Example.COM` past a
`string=?` allowlist check. Accessors normalize; the record and `uri->string` stay raw.
`uri-resolve` and `uri=?` accept strings as well as records.

FOUND WHILE PLANNING (measured 2026-10-11, macOS arm64, Chez 10.4.1 tarm64osx). (1) 0022's
Context says §5.2.2 resolution never synthesizes a `//`-leading no-authority path. False:
`foo:/a` with `.//bar` or `/.//bar` resolves to {foo, #f, "//bar"}, which recomposes to
`foo://bar` and re-parses with authority `bar`. An `http://` base hides it, because the
authority keeps the `//` inside the path, and the §5.4 corpus is all `http://a/...`. (2) Chez's
`utf8->string` maps invalid bytes to U+FFFD, so `%FF` and `%FE` would decode to `string=?`
strings. (3) Low-layer error offsets count bytes: `relative-ref "é:b"` fails `scheme-forbidden`
at byte 2, character 1. (4) main moved under the plan branch: #35 merged mid-session. The
branch already contained it, but the plan's README step named the section #35 renamed ("Parsing
a URI" is now "Using it"), and was corrected.

SLICE ⓪ OPEN (2026-10-11). Branch docs/easy-layer-slice0, STACKED on docs/easy-layer-plan,
because the records link to the plan file. When #36 squash-merges, rebase this branch onto main
(`git rebase --onto main docs/easy-layer-plan`), or the PR re-shows the plan's commits. In the
branch: records 0040, 0041, 0042; amendment headers on 0001, 0010 (item 3 superseded) and 0022;
the pin, group "§5.2.2 resolution reaches the §3.3 shape from a no-authority base" in
test/common/round-trip-tests.sps, three cases (`.//bar` and `/.//bar` against `foo:/a`, and an
`http://h/a` control). Its lane's SOURCES gain path.sls and resolve.sls, which the test now
imports through (uri resolve). README.org's recomposition bullet names the resolution case;
CHANGELOG [Unreleased] records the pin and the README change. The plan's Slice ⓪ text is updated
to match. WATCHED FAIL, on a scratch copy of src/ with each edit asserted landed: recompose
writing "/." before a //-leading path after no authority fails 3 cases and 6 checks (both
`foo:` cases and 0022's hand-built §3.3 case); remove-dot-segments case B dropping three bytes
of "/./" fails 3 cases and 9 checks (the whole new group, the `http` control included). The
lane went from 27 cases / 96 checks to 30 / 108, in both the source and aot registrations.
Measured on d189c1e plus the working tree (macOS arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3,
byte-machine c338a57): test-all 79/79, no-scheme 13/13.

PLAN PR #36 CLOSED OUT (2026-10-11). Squash-merged as 145bc08 on 0b980a5, pinned by
--match-head-commit d189c1e (gh needs the full SHA there; a short one is refused as "Could not
coerce value to GitObjectID"). Merged tree 16ea20c = tested tree 16ea20c (hash compare). The
first attempt, earlier the same day, was refused by the session's permission classifier ("merge
without review"); the maintainer asked again and the second went through. CI DID NOT RUN on any
of #36's three pushes (runs 38156441065, 38156641784, 38156709059), all refused over billing. A
PR comment records that with the local count, `make test` 79/79 on d189c1e. #37 was retargeted
to main BEFORE the plan branch went, then docs/easy-layer-slice0 was rebased with `git rebase
--onto origin/main d189c1e`: clean, and the rebased tree equals the old head's.
docs/easy-layer-plan deleted local and remote.

REFLECTION. Three things. (1) A SENTENCE IN A DECISION RECORD IS A CLAIM NOTHING CHECKS. 0022's
"resolution never synthesizes a //-leading no-authority path" stood from M7 until a feature
leaned on it, and a ten-line probe disproved it. The repair is a pinned test, not a reworded
sentence. (2) AN OPEN QUESTION IS WORTH ASKING AGAIN FROM THE CALLER'S SIDE. The draft's "scheme
and host as written" optimized for the round-trip identity. Asked as "what will a caller do with
uri-host?", the answer is compare it, which made the raw form an allowlist bug. Normalizing in
the accessor and keeping the record raw keeps both properties. (3) A STACK NEEDS ITS MERGE ORDER
WRITTEN DOWN BEFORE THE FIRST MERGE. The retarget must precede the branch deletion, and under a
squash the stacked branch's old base commits must be cut off with --onto.

MERGE STATE (2026-10-11, after #36). #36 is merged (above) and #37 targets main.
feat/uri-query was rebased onto the rebased slice-⓪ head with `git rebase --onto
docs/easy-layer-slice0 d63e2bd`; the ledger conflicted, both branches having appended here,
and kept both. When #37 squash-merges: retarget #38 to main FIRST, then `git rebase --onto
origin/main <#37's head> feat/uri-query`, then delete docs/easy-layer-slice0.

SLICE ① OPEN AND DONE IN BRANCH (2026-10-11). Branch feat/uri-query, STACKED on
docs/easy-layer-slice0 (0041 governs it, and both append to this ledger). `(uri query)` in
src/uri/query.sls: `query-pairs` and `form-pairs`, pure, importing (rnrs) and (uri percent),
exactly 0041 item 2's rules. test/common/query-tests.sps, lane uri.unit.query.chez.{source,aot}.
THREE READINGS: a 25-row hand-derived table that BOTH the product and the oracle must satisfy
(so the table grades the oracle too); the oracle, test/support/harness/uri/test/query-oracle.sls,
over lists of octets with its own hex reading, importing only (rnrs); and an exhaustive sweep of
both readings over the alphabet "a=&+%26B" (8 bytes: both separators, `+`, `%`, and the hex
digits that spell %26 and %2B). MAXLEN SET BY MEASUREMENT: 6 ran 599,186 comparisons in 0.26 s,
7 runs 4,793,490 in 1.73 s (source) and ~2.0 s (aot), so 7. The sweep emits its coverage line
and asserts its count against an independently computed total. WATCHED FAIL: first with no
library (the lane cannot load it), then against a stub returning () (the oracle passes all 25
rows in both readings; the stub fails 23 per reading, passing only "" and "&"; the sweep finds
599,172 disagreements, the 14 agreements being exactly the all-`&` words, 7 lengths × 2
readings). Then eight mutations of a scratch copy of src/, each an exact single-occurrence
substitution that refuses to run if it does not land; the sweep at MAXLEN 7:
  decode before split (query)   table 4, sweep 22,712 disagreements
  + → space after decode (form) table 2, sweep 22,712
  split at the last =           table 1+1, sweep 834,768
  keep empty pieces             table 3+3, sweep 883,554
  ; as a separator              table 1+1, sweep 0 (; is outside the alphabet: the table's catch)
  absent value as ""            table 4+4, sweep 2,963,712
  output reversed               table 7+7, sweep 2,165,346
  duplicate keys merged         table 1+1, sweep 113,408
The two 22,712s are the alphabet's symmetry: %26 and %2B are spelled the same way. CHANGELOG
[Unreleased] gains the (uri query) entry. Measured on b981dde plus this commit (macOS
arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3, byte-machine c338a57): test-all 81/81, no-scheme
13/13.

SLICE ② OPEN AND DONE IN BRANCH (2026-10-11). Branch feat/uri-easy-read, STACKED on
feat/uri-query (#38). `(uri easy)` in src/uri/easy.sls with the slice-② exports: the three
parsers, uri-string?, uri?, the eight fields, uri-path-segments, uri-query-pairs,
uri-form-pairs, uri-decode, uri-encode, and the &uri-error accessors. test/common/easy-tests.sps,
lane uri.unit.easy.chez.{source,aot}: 23 cases, 252 checks; its SOURCES are the first to name
the harness PRNG (no lane listed prng.sls before). ONE ADDITION TO THE PLAN: `uri-error-reasons`
is exported, a list WRITTEN OUT in easy.sls, because a list derived from the low layer's code
lists would make "equals the union" true by construction; the plan and 0040 item 6 say so.
DESIGN CHOICES THE CODE CARRIES: (1) decoded readings judge UTF-8 ONCE over the whole raw path
or query, then split and convert. Splitting on an ASCII delimiter can neither cut a well-formed
sequence nor mend an ill-formed one, so one judgement covers every piece, and the offset lands in
the whole text (`a=%C3&b=%A9` fails at 2). (uri query) needed no change. (2) The decode offset
maps a decoded index back to its source `%` with (uri percent)'s hex-digit-value, then to a
character index; the parse offset converts the low layer's byte offset by counting UTF-8 lead
bytes. (3) uri-host reads a normalize-components COPY; the record is never folded. WATCHED FAIL:
the library missing, then 30 mutations on scratch copies of src/, each an exact single-occurrence
substitution refused if it does not land. Every one reddened its intended case:
  lossy decode (no UTF-8 check)        21 failures in 4 cases, %FF/%FE included
  byte offset, parse | decode          2 | 1 (é:b and 😀:b | "é%FF")
  uri-parse for uri-parse-validate     7 (the validation case and the message)
  port split at the first ":"          3 (u:1@a, [::1]:443, [::1])
  absent read as "" | userinfo @a #f   4 | 1
  raw host | raw scheme                5 | 1
  fold authority | userinfo | triplet  2 | 1 | 1
  fold written into the record         3 (host read twice; authority after host)
  UTF-8 table: C0 lead, E0 overlong, ED surrogate, F0 overlong, F4 max, F5 lead, truncation,
    and an OVER-strict E0 (rejects U+0800)  1-2 each; the over-strict one also fails the
    generated encode/decode round trip
  segments: leading empty kept | decode before split   5 | 2
  reasons: one missing | one extra     1 | 1
  guards removed: string, uri?, mode, uri-decode's string   3 | 4 | 1 | 1
The round trip draws 2000 strings from (uri test prng) seed 20261011, code points from every
UTF-8 length with surrogates excluded, and also checks each encoding is a valid path. CHANGELOG
[Unreleased] gains the (uri easy) entry; the selection count moved there from the query entry.
Measured on ff06dcc plus this commit (macOS arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3,
byte-machine c338a57): test-all 83/83, no-scheme 13/13.

REVIEW FIXES ON #39 (2026-10-11, /code-review xhigh over main...feat/uri-easy-read, all ten
findings fixed in this branch on the maintainer's word). (1) THE Uri RECORD IS OPAQUE: without
`(opaque #t)`, `record-rtd` reached the mutable component bytevectors, so a caller could write
into validated bytes. Not sealed: with the rtd unreachable and the type name unexported, nothing
outside can subtype it. (2–4) THREE TEST GAPS CLOSED: decode rows with a malformed `%` before the
bad sequence (`%%FF`→1, `%zz%FF`→3, `%F%FF`→2); `a=&b` through uri-query-pairs and
uri-form-pairs (empty is not absent); userinfo with a `:` beside an IP-literal and a port.
(5) THE OFFSET MAP ASKS pct-decode: source-index restated (uri percent)'s triplet rule with
hex-digit-value; triplet-at? now decodes the three-byte window and asks whether it became one
byte, so the mapping cannot drift from the decoder. Error path only. (6) uri-error-offset IS A
Nat: the low layer reports an offset with every error result, so a #f guard would be dead code
no test could watch fail; the contract was tightened instead, and the plan now gives slice ③'s
base-not-absolute and ambiguous-components offset 0. (7) uri-host normalizes the authority
alone (a components with only that field), not the path, query and fragment. (8) decode-strictly
returns its decoded bytes, so uri-decode decodes once; the path and query readings still decode
the whole text for the judgement and then each piece, the cost of judging once. (9) CHANGELOG
[Unreleased] states the lane count once (83 and 13), in the newest entry. (10) (uri query)'s
plus->space works on a copy instead of rewriting its argument in place. WATCHED FAIL: the opaque
case failed on the unfixed code (2 failures) and again with `(opaque #t)` removed; a triplet-at?
that calls any `%` a triplet fails the three new decode rows; collapsing an empty value to #f
fails the two `a=&b` checks; a userinfo cut at its first `:` fails the new row. FOR (10) THE
CONTRAST IS THE WITNESS: with `slice` handing over the caller's own bytevector for a whole-input
piece, the OLD in-place rewrite fails only the new "neither reading modifies its argument" check
(the table stays green, since the pairs are still right), and the NEW copying plus->space passes
under the same split. Counts after: unit.easy 24 cases / 274 checks, unit.query 6 / 106. Measured
on 8922cd2 plus this commit (macOS arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3, byte-machine
c338a57): test-all 83/83, no-scheme 13/13.

SLICE ⓪ PR #37 CLOSED OUT (2026-10-11). Squash-merged as 18f528a on 145bc08, pinned by
--match-head-commit b981dde. Merged tree 3c1eb8b = tested tree 3c1eb8b (hash compare). CI DID
NOT RUN: both pushes (runs 38157173938, 38158823366) were refused over billing; a PR comment
records it with the local counts. The ledger's order held: #38 retargeted to main FIRST, then
`git rebase --onto origin/main b981dde feat/uri-query` and `git rebase --onto feat/uri-query
ff06dcc feat/uri-easy-read`, both clean, each rebased tree byte-identical to its old head (empty
`git diff --stat`); test-all 83/83 on the top; force-pushed with leases on the old heads; then
docs/easy-layer-slice0 deleted local and remote. #38 now targets main (head 682ac92), #39 sits
on it (head ec67047 before this commit). This close-out is committed on #39's branch, the top of
the stack, so no later rebase meets it at the end of the file the way #36's met slice ①'s.
NEXT MERGE: #38 the same way (retarget #39 first, rebase --onto, then delete feat/uri-query).

SLICE ③ OPEN AND DONE IN BRANCH (2026-10-11). Branch feat/uri-easy-resolve, STACKED on
feat/uri-easy-read (#39). (uri easy) gains uri->string, uri-resolve, uri-normalize, uri=?,
uri->components and components->uri; uri-error-reasons gains base-not-absolute and
ambiguous-components (offset 0, the whole input at fault). Exactly 0042 items 1–5: resolve is
strict §5.2.2 with no normalization; normalize is normalize-components THEN remove-dot-segments,
skipped for a relative-path reference; uri=? compares normalized components; the guard prefixes
"/." to a //-leading path with no authority, after both resolve and normalize; components->uri
recomposes, re-parses with validation, and requires equality. ONE ADDITION BEYOND THE PLAN:
both crossings copy. uri->components hands out fresh bytevectors, and components->uri keeps the
re-parsed copy, never its argument, so the opaque record cannot be mutated from either side.
test/common/easy-resolve-tests.sps, lane uri.unit.easy-resolve.chez.{source,aot}: 22 cases, 894
checks. Its corpus is every committed input that validates, 211 of them (8 examples, the §5.4
base, 42 references, 42 targets, 118 accepted adversarial rows), emitted on a coverage line with
the 8 and the 42 asserted. Over it: the uri->string identity, faithful rendering (re-parse gives
the same components) and idempotence of uri-normalize; faithful rendering again for every §5.4
reference resolved against the base, "foo:/a" and "foo:a/b". MEASURED FIRST (2026-10-11): the
low layer's remove-dot-segments gives "a/../b" → "/b" (so foo:a/../b normalizes to foo:/b, as
§5.2.2 resolves it) and "./a:b" → "a:b" (a scheme, if dot removal ran on a relative-path
reference: the vector that pins the skip). uri.unit.easy's SOURCES now share a URI_EASY list with
the new lane, since (uri easy) imports path, resolve and recompose. WATCHED FAIL: the exports
missing (the program cannot bind uri->components), then 13 mutations on scratch copies:
  guard removed                        6 (the foo: vectors, the normalize guard rows)
  guard ignoring the authority         1 (http://h + /.//bar)
  dots removed before percent-norm     3 (%2E%2E, the all-steps row)
  dots removed in a relative-path ref  3 (../b, a/./b, ./a:b)
  no dot removal at all                7 (normalize rows and one uri=? row)
  uri=? on raw components              6
  components->uri without equality    2 (a:b, //x)
  components->uri keeping its argument 1;  uri->components without copies  1
  base check removed                   1;  uri-resolve normalizing         1
  base-not-absolute missing from uri-error-reasons   1 (unit.easy)
ONE SURVIVOR, EQUIVALENT: relative-path-reference? without its authority conjunct. With an
authority the path is empty or rooted (§3.3), and the only case the conjunct decides is an empty
path, where dot removal is the identity. Kept, because it makes the predicate §4.2's definition;
no behaviour depends on it. CHANGELOG [Unreleased] gains the entry and the count moves to it.
Measured on f40a59b plus this commit (macOS arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3,
byte-machine c338a57): test-all 85/85, no-scheme 13/13.

REVIEW FIXES ON #40 (2026-10-11, /code-review xhigh over main...feat/uri-easy-resolve, nine
findings, all fixed in this branch on the maintainer's word). (1)+(3) ONE REASON FOR A BASE
WITHOUT A SCHEME, JUDGED FIRST: a string base was parsed as an absolute URI, so "/a" raised
scheme-required while a Uri "/a" raised base-not-absolute; and the reference was parsed before
the base was checked. Now a string base is parsed as a URI reference, its scheme checked, and
only then is the reference read. (2) components->uri refuses a #f path as an assertion (it had
read as ambiguous-components). (4) THE GUARDED PATH READS AS THE PATH IT NAMES: uri-path-segments
of "/.//bar" with no authority is ("" "bar"); uri-path still returns "/.//bar" as held, and any
other "/./" stays a "." segment. (5) refusal checks for uri->string and uri=?. (6)
components->uri builds its error string only on the error paths. (7) ONE ADVERSARIAL LOADER:
(uri test corpus) exports corpus-parse-adversarial / corpus-load-adversarial (record av: mode
input expect note), refusing a malformed row like the derived files' loaders; abnf-differential
and easy-resolve both read through it. abnf-differential's count is unchanged (9 cases, 718
checks, the same as main's copy of the file run against this tree). (8) ONE RAISE JUDGEMENT:
(uri test raised) exports raised, check-raised and check-refuses, product-independent like (uri
test ranged); both easy lanes use it, and easy-resolve now also checks a &uri-error is not an
assertion, the strictness its copy had lost. (9) URI_DIFFERENTIAL_DIR is set once, beside
URI_CORPUS_DIR, before either lane that reads it. 0040 (item 7) and 0042 gain amendment notes;
the plan and CHANGELOG follow. WATCHED FAIL: the four behaviour fixes failed first on the
unfixed code (8 failures in 3 cases), then again as mutations of the fixed code: base parsed
absolute 1, reference read first 3, no escape in segments 3, escape ignoring the authority 1,
no #f-path check 1; uri->string past `parts` 1; uri=?'s as-uri with another who 1 and 2; a
&uri-error that is also an assertion now fails BOTH lanes (easy-resolve 9, easy 32 — before,
easy-resolve's copy would have passed it); corpus-parse-adversarial without its length, verdict
or mode check 1 each. ONE EQUIVALENT SURVIVOR: the who uri=? hands to `normalize` is
unobservable, since as-uri has already refused any non-Uri. HOUSEKEEPING NOTE: an unquoted
mutation name containing ">" (uri->string-...) redirected one run's output into a stray file at
the repo root under zsh; it was found by git status, read, and removed, and the remaining names
were quoted. Counts after: unit.easy-resolve 23 cases / 921 checks, unit.easy 24 / 274,
unit.corpus 25 / 64. Measured on 0a60b6e plus this commit (macOS arm64, Chez 10.4.1 tarm64osx,
CMake 4.3.3, byte-machine c338a57): test-all 85/85, no-scheme 13/13.

PRs #38, #39, #40 CLOSED OUT (2026-10-11), merged in stack order on the maintainer's word, each
the same way: merge pinned by --match-head-commit, merged tree compared with the tested tree,
the next PR retargeted to main BEFORE its base branch was deleted, then rebased --onto main
cutting the squashed commits, the rebased tree compared with the old head (byte-identical every
time, empty `git diff --stat`), force-pushed with a lease on the old head.
  #38 (uri query)         7e9d607 on 18f528a, pinned 682ac92; tree 3eb144c = 3eb144c
  #39 (uri easy) reading  709ecd7 on 7e9d607, pinned 9a1a2d3 (rebased f40a59b); tree 1209848 = 1209848
  #40 (uri easy) resolve  605eae0 on 709ecd7, pinned c933de5 (rebased 9401d5a); tree de4d201 = de4d201
CI DID NOT RUN on any of them: the latest runs 38161218165, 38161251152, 38162598652 were refused
over billing (each annotation read), as were every earlier push; a PR comment on each records it
with its local counts (81/81, 83/83, 85/85; no-scheme 13/13). Branches feat/uri-query,
feat/uri-easy-read, feat/uri-easy-resolve deleted local and remote; local main = 605eae0. The
two claude/* branches belong to other sessions' worktrees and were left alone.

REFLECTION. Three things. (1) A STACK MERGES CLEANLY WHEN EACH STEP IS CHECKED, NOT ASSUMED. The
order (retarget, rebase --onto, compare trees, push with a lease, delete) was written in the
ledger before the first merge, and every rebased tree was compared with its tested head rather
than re-tested on faith. (2) REVIEW FIXES BELONG TO THE PR THEY REVIEW. Each review ran over the
whole unmerged stack, and its fixes landed on the top branch. That kept every rebase
conflict-free, at the cost of a fix to (uri query) showing up in #39's diff. (3) THE SHELL IS
PART OF THE INSTRUMENT. zsh read an unquoted ">" in a mutation's name as a redirect and wrote a
file into the repo root. git status caught it; quoting every name is the fix.

SLICE ④ OPEN (2026-10-11): the v0.7.0 release. Branch docs/easy-layer-release off main 605eae0.
Decision 0043 (MINOR bump, annotated tag, local evidence disclosed, no new conformance claim).
docs/easy.org is new; README.org leads with (uri easy), adds both libraries to "What it does"
and the task table, and narrows "Scope and limits"; CMakeLists VERSION 0.6.2 → 0.7.0; CHANGELOG
[Unreleased] → [0.7.0] - 2026-10-11 with the evidence preamble. EVERY EXAMPLE WAS RUN: a checker
in the session scratchpad extracts each Scheme block from an org file, runs a whole program
against its #+begin_example and each expression against its `;; =>` value. docs/easy.org: 10
examples, 0 differ; README.org: 2 programs, 0 differ. It was watched failing first: two
deliberate edits to a copy of easy.org (a port, a normalized URI) were both reported. The
checker is not yet a registered lane (0043 lists it as next work). The tag, its push and any
GitHub Release are the closing ritual, to be asked for after this PR merges (0043 item 6).
RELEASE GATE on the reconciled tree (macOS arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3,
byte-machine c338a57): configure prints "chez-uri 0.7.0"; test-all 85/85; no-scheme 13/13; the
example checker 10/10 (docs/easy.org) and 2/2 (README.org), run last, after every edit.

RELEASE PR #41 CLOSED OUT, v0.7.0 TAGGED (2026-10-11, the closing ritual, on the maintainer's
word). #41 squash-merged as daf7be0 on 605eae0, pinned by --match-head-commit 446fdf7. Merged
tree 444d045 = tested tree 444d045 (hash compare). CI DID NOT RUN: run 38163347863 refused over
billing (annotation read); a PR comment records it with the release-gate counts. Local main
fast-forwarded to daf7be0; docs/easy-layer-release deleted local and remote. TAG: annotated
v0.7.0 on daf7be0, signed per tag.gpgSign ("Good signature from DarrenN (yuzu)"), pushed;
the remote tag object 66b2fe0 peels to daf7be0. Its message carries the CI refusal on #33 to #41
and the local counts (0043 items 4–6). NO GitHub Release was cut (0043 item 6: only if the
maintainer wants one; its body would be CHANGELOG [0.7.0]).

THE EASY-LAYER MILESTONE IS COMPLETE: plan #36, records and pin #37, (uri query) #38, (uri easy)
#39 and #40, release #41. The complete selection went from 79 to 85 lanes.

REFLECTION. Three things. (1) THE PLAN WAS PROBED BEFORE IT WAS TRUSTED. Ten-line probes during
planning found that 0022's resolution claim was false, that Chez's utf8->string turns invalid
bytes into U+FFFD, and that the low layer's offsets count bytes. All three changed the design
(the `//` guard, strict UTF-8, character offsets) before any code existed, and each became a test.
(2) REVIEW FOUND WHAT A GREEN COUNT CANNOT. Two xhigh reviews raised nineteen findings. The
weightiest were contract-level: a record that was not opaque, and two reasons for one mistake.
Another was drift in the test instrument itself: copied check helpers had already diverged in
strictness. Every fix came with a witness. (3) NAME THE EQUIVALENT MUTANTS. Two survivors (the
authority conjunct in relative-path-reference?, and the `who` uri=? hands to normalize) cannot
be caught because no input distinguishes them. Recording each with its reason keeps "no
survivors" from being claimed and keeps them from being mistaken for gaps.

NEXT. (1) CI billing: nine PRs (#33 to #41) have now merged without a CI verdict. When Actions
runs again, run it on main (daf7be0 or later) and record the first green run since #28. (2) Make
byte-machine public before or with uriparse (`gh api repos/Kiyomi-Computation-Systems/byte-machine
--jq .visibility`). (3) A GitHub Release for v0.7.0, if wanted. (4) The org-example checker as a
registered lane, so docs/easy.org and README.org cannot drift from what they print (0043). (5) Out
of the easy layer's scope, if wanted: building URIs from parts, a host-kind accessor, a ranged
(uri query). (6) Carried: chez-httparse to byte-machine v0.7.0; the 2026-12-01 CMake hold review;
the 24.04 → 26.04 move (0038 item 4); chez-httparse's runner pin before 2026-10-19; the
result-level authority-form validator (0032 item 4); v0.6+ tooling (0012, 0022); the next sibling
request.

v0.7.0 GITHUB RELEASE CUT (2026-10-11, on the maintainer's request; 0043 item 6). Title "v0.7.0 —
the easy layer", from tag v0.7.0 (--verify-tag), published, not a draft or pre-release, now
Latest. Body: the CHANGELOG [0.7.0] section read from CHANGELOG.md AT THE TAG, without its
heading, as v0.6.2's was. The extraction was asserted to be a verbatim slice (70 lines), and the
published body read back matches it except for jq's trailing newline.
https://github.com/Kiyomi-Computation-Systems/uriparse/releases/tag/v0.7.0. NEXT item (3) is done.

THE EXAMPLE CHECKER IS A LANE (2026-10-11, on the maintainer's request; 0043's last "what reopens
next" item and ledger NEXT (4)). Branch test/doc-examples-lane off main 7ff7424. The scratchpad
Python checker became test/common/doc-examples-tests.sps, lane uri.example.docs.chez.{source,aot}
(label `example`, already in the pr filter and used by no lane until now; no record says what it
was reserved for). NO NEW DEPENDENCY: it is R6RS (rnrs eval). A program block's body is
evaluated in `(environment ...)` built from its own import, inside a wrapper that rebinds
display, write and newline to a string port. An expression is evaluated in (rnrs) + (uri easy)
and compared with `equal?` against its `;; =>` value read as a datum. The program imports (uri
easy), (uri collect) and (uri components) with `(only (lib))`, binding nothing, so `environment`
finds them in the AOT lane, where eval works too (measured). The doc list is README.org plus a
CONFIGURE_DEPENDS glob of docs/*.org, passed as URI_DOC_FILES: docs are data, not fingerprinted
sources, so a new guide is checked as soon as it exists. THE CHECKER GRADES ITSELF FIRST: inline
docs with known verdicts. One correct doc has every example counted and no difference. Eight
wrong docs (wrong output, wrong value, a program with no example, an expression with no value,
one that raises, a program that raises, an unclosed block, no example at all) must each give
EXACTLY one difference. An sh block next to a Scheme one is skipped, not run. WATCHED FAIL: on
copies of the docs (a wrong port and a wrong host: 2 differences; a wrong `;; =>`: 1); on 9
mutations of the checker (output always agrees, value always agrees, missing example ignored,
example search crossing a Scheme block, unclosed block dropped, empty doc passing, other
languages run as Scheme, an expression without a value dropped), every one red; a listed file
that is missing, and an empty list, both red; and the REGISTERED lane through ctest, with a
real edit to docs/easy.org, red in source and AOT, then green once restored (git diff clean).
TWO SELF-TEST GAPS FOUND BY THE MUTATIONS, both fixed before commit. (a) In the no-example case,
the stray example after the next Scheme block did not match the program, so a search that ran
past the block still found one difference, for the wrong reason; it now matches, so running past
gives zero. (b) The no-example rule lived in the real-docs group, which no self-test reaches; it
moved into check-doc. Moving it made two inline docs also empty, which the as-written run caught
(2 differences where 1 was expected); each now carries one good example first. README.org
gains one line saying the examples are run; CHANGELOG [Unreleased] gains the lane. Measured on
7ff7424 plus this commit (macOS arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3, byte-machine c338a57):
test-all 87/87, no-scheme 13/13, pr selection 87/87; the lane reports README.org 2 programs and
docs/easy.org 1 program and 9 expressions, 0 differences, in both modes.

PR #42 CLOSED OUT (2026-10-11, merged on the maintainer's word; close-out committed on main at
the maintainer's word). Squash-merged as dcb7996 on 7ff7424, pinned by --match-head-commit
806bef6. Merged tree 8dbb521 = tested tree 8dbb521 (hash compare). CI DID NOT RUN: run
38164680223 was refused over billing (annotation read); a PR comment records it with the local
counts, test-all 87/87 and no-scheme 13/13. Before test/doc-examples-lane was deleted (local and
remote), no open PR was based on it (checked). Local main was fast-forwarded to dcb7996 only after
confirming it was checked out and clean.

THE SHARED CHECKOUT MOVED UNDER THIS WORK. Between this branch's creation and its commit, another
session ("User-facing documentation and API reference", 94df59) ran `git switch -c
docs/user-docs-and-site` in /Users/yuzu/github/uriparse, then switched back to main and deleted
its branch. Uncommitted work rides along on a checkout, so the commit landed on local main; the
push sent an empty branch, and `gh pr create` reported "No commits between main and ...". The
reflog showed checkouts this session never ran. Nothing reached origin/main. RECOVERY BY REFS
ONLY, with no checkout of the shared tree: `git branch -f test/doc-examples-lane 806bef6`, a push
(fast-forward), then `git reset --keep origin/main` on main, guarded to run only while main was
checked out, clean and at 806bef6. 94df59 confirmed by message that the switch was its own, that it
touched none of these files, and that it now works in a separate worktree (docs/user-docs-and-site
is checked out there).

COORDINATION. 94df59 is rewriting the user docs as Markdown in docs/ (docs/README.md as the index,
an API reference checked against the src exports, GitHub Pages through chez-cmark-gfm's
generator), which would turn docs/easy.org into docs/easy.md. It was told by message to build on
this lane, and it was given:
- the seam: org-blocks returns (kind line text) and check-doc only consumes that list;
- the conventions, and the obligation to grade a Markdown reader with its own bad-doc twins;
- THE SILENT GAP: the lane's list is README.org plus a glob of docs/*.org. Once the guide is .md
  the glob matches nothing, README.org still has examples, and no lane fails; guide checking
  simply stops. The move and the lane's extension must land together.

REFLECTION. Three things. (1) A SHARED CHECKOUT IS SHARED STATE. A branch made at the start of a
task is not guaranteed to be checked out at commit time when other sessions use the same tree;
check the branch immediately before committing, or work in a worktree. The recovery moved refs
and left the tree alone, because another session might be standing in it. (2) A CHECKER NEEDS ITS
OWN WITNESSES. Two of the doc lane's self-tests could not fail, a stray example that did not
match and a rule placed where no self-test reached, and only mutating the checker exposed them.
(3) A CHECK OF CONTENTS CANNOT SEE A FILE VANISH. The lane fails on a wrong example, a missing
listed file or an empty doc. It cannot fail when the glob that builds its list starts matching
nothing, which is exactly what a format change does.

NEXT. (1) CI billing: ten PRs (#33 to #42) have now merged without a CI verdict. When Actions runs
again, run it on main (dcb7996 or later) and record the first green run since #28. (2) Make
byte-machine public before or with uriparse (`gh api repos/Kiyomi-Computation-Systems/byte-machine
--jq .visibility`). (3) Close the silent gap: the doc lane fails when docs/ yields no guide at all,
or the Markdown move (94df59) extends the glob and the reader in one change. (4) Out of the easy
layer's scope, if wanted: building URIs from parts, a host-kind accessor, a ranged (uri query).
(5) Carried: chez-httparse to byte-machine v0.7.0; the 2026-12-01 CMake hold review; the 24.04 →
26.04 move (0038 item 4); chez-httparse's runner pin before 2026-10-19; the result-level
authority-form validator (0032 item 4); v0.6+ tooling (0012, 0022); the next sibling request. DONE
since #41: the v0.7.0 GitHub Release, and the example checker as a lane (#42).

THE DOC LANE'S SILENT GAP IS CLOSED (2026-10-11, on the maintainer's request; NEXT (3) of the #42
close-out). Branch test/doc-lane-unread-formats off main b3b049f. THE GAP WAS WIDER THAN NOTED.
The list was README.org plus a glob of docs/*.org, so the lane could not see a doc in any other
format. That covers the guide moving to .md (the glob then matches nothing, and only README.org is
checked). It also covers the likelier case: a docs/README.md index added BESIDE easy.org, which
94df59 plans. A "fail when docs/ has no guide" rule alone would not catch that second one.
THE FIX: CMake globs every prose format under docs/, recursively (org md markdown rst adoc txt,
CONFIGURE_DEPENDS), and the lane decides per file with a pure function, doc-format:
- a dotfile is 'skip: an Emacs lock file such as .#easy.org matches *.org, and .DS_Store is junk;
- an .org file is 'org, the one format it reads;
- anything else is 'unread, and that fails.
doc-set-problems adds a docs/ with no guide it reads. Editor backups (easy.org~, #easy.org#) match
no pattern. The set check is its own case and prints a coverage line (files, read, skipped,
unread). Self-tests grade doc-format on eight paths and doc-set-problems on five sets: a guide;
a lock file beside it; a Markdown index beside it; no guide; the guide moved to Markdown.
WATCHED FAIL: on scratch file lists, a Markdown index beside the guide (red), the guide moved
to .md (red), no guide (red), and a lock file beside the guide (green, skipped=1). Four mutations
were each caught by the self-tests: .md read as org, unread files skipped, dotfiles not skipped,
the no-guide rule removed. IN THE REAL BUILD, a temporary docs/probe.md was picked up by the
CONFIGURE_DEPENDS re-glob on build and failed uri.example.docs in source and AOT, naming the file;
with it removed (a trap made sure), green again. CHANGELOG [Unreleased]'s lane entry says so.
94df59's Markdown move must now teach the lane to read .md in the same change, or its first .md
file fails the build: the intended effect. Measured on b3b049f plus this commit (macOS arm64,
Chez 10.4.1 tarm64osx, CMake 4.3.3, byte-machine c338a57): test-all 87/87, no-scheme 13/13.

PR #43 CLOSED OUT (2026-10-11, the closing ritual, on the maintainer's word). Squash-merged as
e85fd34 on b3b049f, pinned by --match-head-commit b11eb6d. Merged tree 099dcd8 = tested tree
099dcd8 (hash compare). Before merging, origin/main had not moved and the branch contained it.
CI DID NOT RUN: run 38165688046 was refused over billing (annotation read); a PR comment records
it with the local counts, test-all 87/87 and no-scheme 13/13. Before test/doc-lane-unread-formats
was deleted (local and remote), no open PR was based on it (checked). The checkout, clean, moved
from that branch to main and fast-forwarded to e85fd34.

REPORTED BY 94df59, BY MESSAGE, DURING THE MERGE: two weaknesses in the lane's self-tests, on main
since #42. Neither made #43 wrong.
(1) "Every kind of wrong doc is reported" counts differences without checking WHICH. A reader
that sees no blocks yields one difference for every row ("no example"), so every row passes with
no reader at all. 94df59 watched this happen with its Markdown rows before writing the reader. For
the org reader, "a correct doc" catches a reader that sees nothing, but a reader that half-works
could pass a row for the wrong reason.
(2) 94df59's fix makes each row name a fragment its difference must contain. That fix passed
vacuously for "a block that never closes", because check-doc prefixes the doc's name to each
difference and the label contained the fragment. Every test doc is now named doc.org or doc.md.
BOTH FIXES are in 94df59's branch docs/user-docs-and-site (its worktree, unpushed, based on
dcb7996), with four reader mutants witnessed. That branch will:
- rebase onto e85fd34;
- fold its Markdown reader into doc-format;
- widen SNIPPET-ENV to (rnrs) plus every (uri ...) library;
- let a program define after an expression (as-body);
- update the "which files are docs" rows for .md.
94df59 had asked that no Markdown reader be written here. Agreed: the fixes land with that branch,
not as a second change here.

REFLECTION. Three things. (1) A COUNT IS NOT A REASON. "Exactly one difference" is satisfied by
the wrong difference, so a broken reader passed the rows built to catch it. Pin which difference,
with a fragment the label cannot supply. It is the same shape as check-raises needing a
single-value thunk: a check the guarded failure itself can satisfy. (2) ANOTHER SESSION VARIED A
DIFFERENT AXIS. My mutations varied the checker's decisions over blocks it was given; 94df59's
varied the reader that produces the blocks, and found what mine could not. (3) THE NOTED GAP WAS
TOO SMALL. The #42 close-out named the format-move case. Listing everything the check could not
see found a likelier one (a .md beside the .org), and the fix covers both.

NEXT. (1) CI billing: eleven PRs (#33 to #43) have now merged without a CI verdict. When Actions
runs again, run it on main (e85fd34 or later) and record the first green run since #28. (2) Make
byte-machine public before or with uriparse. (3) 94df59's branch: the Markdown docs, its reader
in doc-format, and the two self-test fixes above, as one change. Review it for (1) and (2) of the
report. (4) Out of the easy layer's scope, if wanted: building URIs from parts, a host-kind
accessor, a ranged (uri query). (5) Carried: chez-httparse to byte-machine v0.7.0; the 2026-12-01
CMake hold review; the 24.04 → 26.04 move (0038 item 4); chez-httparse's runner pin before
2026-10-19; the result-level authority-form validator (0032 item 4); v0.6+ tooling (0012, 0022);
the next sibling request.

THE AKKU PACKAGE (2026-10-11, on the maintainer's word: "release this on Akku like
chez-cmark-gfm"). WHAT "LIKE" MEANT HAD TO BE READ OFF THE ARCHIVE. chez-cmark-gfm's ADR-0017
still says publishing is out of scope, yet akkuscm.org/packages/chez-cmark-gfm/ lists 2.0.0,
repacked from tag v2.0.0. So the target is a real `akku publish`. Akku's lib/publish.scm says what
that takes:
- it signs an index entry naming the v<version> tag with the publisher's GPG key;
- it uploads the entry to archive.akkuscm.org;
- the archive clones the repo at that tag, so the repo must be public, submodules arrive empty, and
  every dependency must already be on the index.
uriparse and byte-machine are private, and byte-machine is not on the index, so nothing could
be published. Branch chore/akku-package off main 6fdd6bd, in an EnterWorktree worktree. The
shape is chez-httparse's unreleased packaging, renamed:
- Akku.manifest: chez-uri 0.7.0, depending on byte-machine ^0.7.0, with no scripts and no lock;
- uri.docs.akku-manifest (source and aot, a new `docs` layer, which the pr selection includes);
- make check-akku, with test/akku/check-akku.sh and consumer.sps;
- decision 0045.
94df59 took decision 0044 by message. check-akku adds one assertion to chez-httparse's: the
package installs nothing but libraries and notices, because a program would land in .akku/bin
where the library-set check cannot see it. No (uri ...) or (generated ...) library is on the index
(akkuscm.org/libraries, read 2026-10-11).
WATCHED FAIL:
- The lane went red with no manifest. Five manifest mutations were each caught by their own
  diagnostic: version, floor, caret, no depends, unvendored dependency.
- check-akku, 7 cases entered and 7 verdicts returned. It went red on: a tracked site/*.sls, a
  programs/*.sps, a src/ library left uninstalled, no dependency (the consumer fails at import),
  and wrong consumer output. It stayed green with .akkuignore = site, and with a top-level
  build-site.sps. Those two are the verdicts 94df59 asked for on #44's files.
Measured on 6fdd6bd plus this commit (macOS arm64, Chez 10.4.1, CMake 4.3.3, akku 1.1.1-beta.0):
test-all 89/89, no-scheme 13/13, check-akku 15 libraries.

PR #45 CLOSED OUT (2026-10-11, the closing ritual, on the maintainer's word). Squash-merged as
cb26b0a on 6fdd6bd, pinned by --match-head-commit 094d1ed. Merged tree 9945081 = tested tree
9945081 (hash compare). Before merging, origin/main had not moved. CI DID NOT RUN: run
38167266479 was refused over billing (annotation read). A PR comment records it with the local
counts. The worktree was removed. Its one discarded commit was 094d1ed, whose tree is main's.
chore/akku-package was deleted locally and on the remote, and no open PR was based on it
(checked). The main checkout, clean and on main, fast-forwarded to cb26b0a.

REFLECTION. Three things.
(1) A REPO'S OWN RECORD CAN LAG ITS PUBLISHED STATE. chez-cmark-gfm's ADR said "not published",
and the archive said otherwise. Ask the live source (the archive, the API) before planning from
a sibling's docs.
(2) A WITNESS CAN MISS FOR ITS OWN REASON. The first "src/ library left uninstalled" case passed:
`.akkuignore` matches basenames at any depth, never paths (repo-scanner.scm), so
src/uri/query.sls ignored nothing. The count of verdicts was whole, 7 of 7. What showed the miss
was that a case expected to fail passed. Reading Akku's source turned that into a fact about the
tool, which decision 0045 now records.
(3) EXACT SET, NOT "SRC INSTALLS". #44's site/ libraries would have reached every consumer's
library path, the leak d65f95 is fixing in chez-cmark-gfm after publication. Asserting the exact
set is what caught it before anything shipped. Separately, a `cd` into 94df59's worktree to read it
moved this session's working directory there. Nothing was written, and the memory now says never
to cd into a peer's worktree.

NEXT. (1) CI billing: twelve PRs (#33 to #43, #45) have now merged without a CI verdict. When
Actions runs again, run it on main (cb26b0a or later), and record the first green run since #28.
(2) THE AKKU RELEASE, in 0045 item 6's order:
  (a) byte-machine public, tagged (its manifest is on its main, unreleased), and published;
  (b) bump vendor/byte-machine to that release, so the floor names a version the index has;
  (c) uriparse public, a release tag (manifest version = CHANGELOG), `make check-akku` run and
      recorded in the release record, then `akku publish` by the maintainer.
  This replaces (2) above.
(3) #44 (94df59; f90e18c + 05ab367): the Markdown docs, the reader, the self-test fixes and
.akkuignore = site. Whichever of #44 and #45 merged second rebases, so #44 does, and it must
re-measure the lane count, not add (expect 91). Review it for (1) and (2) of the #43 report.
(4) check-akku into CI when funded, in the shape of chez-cmark-gfm's akku-install job (akku
1.1.0 tarball, pinned by sha256).
(5) Carried unchanged from above: the easy layer's out-of-scope features, and NEXT (5)'s list.

SLICE: USER DOCS, THE API REFERENCE AND THE DOCS SITE (2026-10-11, session 94df59, branch
docs/user-docs-and-site off main 6fdd6bd, in its own worktree). Decision 0044. The maintainer asked
for Markdown user docs in docs/ (docs/README.md as the index) in the siblings' ELI5 style, an API
reference like chez-cmark-gfm's, and chez-cmark-gfm's site generator publishing GitHub Pages.
COORDINATION: a1417a's #42 and #43 landed the doc lane while this was being written; this branch
was stacked on #42, then rebased onto #43, and folds its Markdown reader into #43's doc-format.
Early on, this session ran `git switch -c` in the shared main checkout and carried a1417a's
uncommitted work onto its branch; it switched back within minutes, a1417a moved its commit with
ref-only moves, nothing reached origin. Worktrees from the start would have prevented it.
WHAT LANDS:
- docs/: README.md (index), installing, easy (replaces easy.org), parsing, validating, resolving,
  queries, errors, reference. 125 examples (14 programs, 111 expressions), every one run.
- uri.example.docs reads Markdown (```scheme, ```text output, list-indented fences), widens
  SNIPPET-ENV to (rnrs) + the twelve (uri ...) libraries, and runs a program as a top-level program
  (as-body: an expression before a later definition). Self-tests: Markdown twins of every wrong doc,
  each row pinned to the fragment its difference must contain, every test doc named doc.org/doc.md
  (NEXT (3) of #43's close-out, both items).
- uri.example.api-reference (source, aot): docs/reference.md against every src/*/*.sls export form,
  read as data; (uri test api-reference) is chez-cmark-gfm's (site reference) plus a `constant`
  kind. 15 libraries, 100 entries, all documented (no exemption list).
- site/, build-site.sps, test/site/ (from byte-machine's port; README.md -> index.html), make site
  and make check-site over CMARK_GFM_ROOT, .github/workflows/pages.yml (v* tag; chez-cmark-gfm
  v2.0.0 by commit 3c84828; apt chezscheme + cmark-gfm; actions/checkout@v7, upload-pages-artifact@v5,
  deploy-pages@v5). site/style.css: td code no longer breaks at hyphens.
WITNESSES. Reader/dispatch mutants, each caught by the case aimed at it: ```text read as 'other, no
un-indent, always the org reader, (uri percent) dropped from SNIPPET-ENV, .md classified 'unread,
read-format? org-only, as-body removed. Reference mutants: no `constant` kind, membership check
disabled, missing-bindings diagnostic dropped, an entry demoted to h4, an entry's Available from
moved to (uri collect), a module row deleted: all caught. Through the build: a wrong `;; =>` in
docs/easy.md reddened uri.example.docs.chez.source, naming the line; restored. Two of this
session's own example values were wrong on first writing (`/a` fails at 0, `http` gives
scheme-required at 4) and the lane caught both. No URI input was found that reaches unexpected-eof;
docs/errors.md says so rather than inventing an example.
MEASURED (macOS arm64, Chez 10.4.1 tarm64osx, CMake 4.3.3, byte-machine c338a57): test-all 89/89;
no-scheme 13/13; uri.example.docs 10 docs (1 org, 9 markdown), 0 differences in both modes;
uri.example.api-reference 15 libraries, 100 entries, 0 diagnostics in both modes; make check-site
green against chez-cmark-gfm v2.0.0. PAGES REHEARSED in ubuntu:24.04 amd64 (Chez 9.5.8, cmark-gfm
0.29.0.gfm.6): check-site green, 9 pages written. actionlint clean.
NEXT. (1) Publishing needs the maintainer: enable Pages with "GitHub Actions" as the source (a
private repository needs a paid plan), and Actions billing must be restored, as for ci.yml.
(2) Carried from #43's close-out: CI billing; byte-machine public; the easy layer's optional
extensions; the carried sibling items.

#44 ADDENDUM: AKKU AS A SOURCE FOR THE SITE'S RENDERER (2026-10-11, on the maintainer's request).
chez-cmark-gfm 2.0.0 is on the Akku index (akkuscm.org/packages/chez-cmark-gfm, source commit
3c84828 = the commit pages.yml pins); byte-machine and chez-uri are not (404, absent from the
435-name list). CMARK_GFM_ROOT now names a checkout (src/) or an `akku install` directory
(.akku/lib/); a checkout wins when both exist; CMARK_GFM_LIBDIR overrides. test/site/
cmark-gfm-root.sh pins the five cases through `make -n site`'s real CHEZSCHEMELIBDIRS and runs
first in check-site; watched failing on the old Makefile (3 of 5) and on a scratch Makefile with
the search order reversed. REHEARSED: ubuntu:24.04 amd64, Akku 1.1.0 release tarball (sha256 as
chez-cmark-gfm's CI pins it), `akku update` (index signature verified) + `akku install
chez-cmark-gfm` -> .akku/lib/cmark/gfm.sls; check-site green, 9 pages. Not exercised on macOS:
this host's akku fails to start, and 1.1.0 has a known arm64 crash (akku #69); README.org points
Mac users at a checkout. pages.yml still checks out by commit.

PR #44 CLOSED OUT (2026-10-11, the closing ritual, on the maintainer's word). #45 merged first, so
#44 was rebased twice: onto cb26b0a (conflicts in Makefile, README.org, CHANGELOG.md and
test/CMakeLists.txt, both sides kept) and then onto the #45 close-out a78dd4d (the ledger). The
lane count was re-measured, not added: test-all 91/91 and no-scheme 13/13 on the final tree, and
CHANGELOG [Unreleased] carries the count once, on the reference entry. #45's `make check-akku` ran
on the combined tree in ubuntu:24.04 amd64 with Akku 1.1.0: 15 src/ libraries, consumer green, so
`.akkuignore` = site holds. #44 was squash-merged as 3176912 on a78dd4d, pinned by
--match-head-commit c52215b. Merged tree 261d55a = tested tree 261d55a (hash compare). CI DID NOT
RUN: run 38168001897 was refused over billing (annotation read); a PR comment records it with the
local counts. Before docs/user-docs-and-site was deleted (local and remote), no open PR was based on
it (checked). The shared checkout, clean, fast-forwarded to 3176912, and the session's worktree
was removed (--force for its submodule, after both trees were checked clean and c52215b's tree was
compared equal to 3176912's).

FOUND WHILE CLOSING: #45's check-akku, run on GNU tar, prints "--no-recursion has no effect" and
"Exiting with failure status" in copy_tracked. The option comes after -T, and a pipeline's left
side cannot trip set -e, so the check passes anyway and a submodule's directory is archived
recursively. Reported to a1417a by message; not changed here.

REFLECTION. Three things. (1) A REBASE CAN COMMIT A CONFLICT MARKER. `git rebase --continue` does
not look for markers, and the check meant to guard it was `rg -c ... && git rebase --continue`. rg
exits 0 when it finds a match, so the chain continued, and the Makefile's second hunk was committed
into 9870caa. The count it printed was the warning. It was caught by reading that output and fixed
by amend before any push. The guard has to fail the chain: `! rg -q '<markers>' <files> && git
rebase --continue`. (2) RUN THE OTHER SIDE'S CHECK ON THE MERGED TREE. a1417a had witnessed
.akkuignore on its own branch; running its check-akku on the combined tree confirmed it, and on a
second platform it also found a defect in the check itself. (3) THE EXAMPLES TESTED THEIR AUTHOR.
Two values in docs/errors.md were guesses, `/a` at offset 1 and `http` as unexpected-eof, and the
lane rejected both on the first run. Where no input could be found for a code, the guide says so
instead of showing one.

NEXT. (1) Publish the site: enable Pages (Settings → Pages → Source: GitHub Actions; a private
repository needs a paid plan) and restore Actions billing. The first v* tag after that deploys it.
(2) check-akku on GNU tar (a1417a). (3) CI billing: thirteen PRs (#33 to #45) have now merged
without a CI verdict. (4) byte-machine public, then on the Akku index, then chez-uri (0045).
(5) Carried: the easy layer's optional extensions; the sibling items in #43's NEXT (5).

FIX: check-akku ON GNU TAR (2026-10-11, session 94df59, on the maintainer's request; branch
fix/check-akku-gnu-tar off main e244376). Closes NEXT (2) of the #44 close-out. The patch is the
chez-httparse session's, applied unchanged (its base blob 5d1b4f4 matched): --no-recursion moves
before -T, which GNU tar needs since the option is positional; the file list and the archive go
through files in $work, so a failing git or tar trips set -e instead of hiding inside a
pipeline; and a new check requires the package copy's vendor/<dep> to be an empty directory, as
git tracks a submodule. WITNESSED in ubuntu:24.04 amd64, Akku 1.1.0: patched with GNU tar 1.35,
pass (15 src/ libraries); the old pipeline with the new check, fail at that check, exit 2, where
the old script had passed; patched with bsdtar 3.7.2 as tar, pass. While witnessing, a git
failure (a submodule's relative .git path broken by copying the tree) stopped the patched script,
which the old pipeline would also have masked. a1417a reproduced the defect independently (gtar:
the old order copies 319 files from vendor/byte-machine, the new one 0) and was told the fix is
here. chez-httparse's identical script is its own task there.

PR #46 CLOSED OUT (2026-10-11, the closing ritual, on the maintainer's word). Squash-merged as
96b47e1 on e244376, pinned by --match-head-commit 14bb1ab; main had not moved. Merged tree 9c33dc2
= tested tree 9c33dc2 (hash compare). CI DID NOT RUN: run 38170016966 was refused over billing
(annotation read); a PR comment records it with the local evidence (make test 91/91; check-akku
witnessed three ways in ubuntu:24.04 amd64). Before fix/check-akku-gnu-tar was deleted (local and
remote), no open PR was based on it (checked). The shared checkout, clean, fast-forwarded to
96b47e1; the worktree was removed after both trees were checked clean and its tree compared equal
to 96b47e1's.

REFLECTION. Three things. (1) THE WITNESS HAD THE BUG IT WITNESSED. The first container run
printed exit=0 for every case, failing ones included: `make ... | grep | sed; echo $?` reports
sed's status, which is the very defect the patch fixes in copy_tracked. A verdict that checks the
captured status and the expected message ("failed, for the expected reason") is what made the
rerun trustworthy; see a-crash-can-count-as-a-catch. (2) A COPIED TREE IS NOT THE TREE. Copying
the worktree broke the submodule's relative .git path, and two cases failed for that reason. Run
in the mounted tree, and copy only for the mutant, which must stop at the new check before any
submodule is read. (3) A PATCH FROM ELSEWHERE IS STILL READ IN FULL, and checked against its base:
blob 5d1b4f4 matched before `git apply`. It went onto its own branch in its own worktree, not the
shared checkout its command named.

NEXT. (1) Publish the site: enable Pages (Settings → Pages → Source: GitHub Actions; a private
repository needs a paid plan) and restore Actions billing. (2) CI billing: fourteen PRs (#33 to
#46) have now merged without a CI verdict. (3) byte-machine public, then on the Akku index, then
chez-uri (0045). (4) Carried: the easy layer's optional extensions; the sibling items in #43's
NEXT (5); chez-httparse's identical check-akku script is its own task there.

PIN: byte-machine v0.7.0 -> v0.8.0 (2026-10-11, session 94df59, on the maintainer's request;
branch chore/byte-machine-0.8.0 off main cb11061). byte-machine went public and released v0.8.0
(c1f7791), its first public release. The pin moves alone (decision 0002 item 6): the gitlink and
Akku.manifest's dependency floor, nothing under src/. EVIDENCE: `make parser-refresh` at the new
pin exited 0 and wrote 28766 bytes, and src/generated/uri-scanner.sls came out byte-identical
(the URI grammar has no integer-accumulate node, the one emitted shape 0.8.0 changes). With the
floor still ^0.7.0, uri.docs.akku-manifest failed in both modes with (range-floor-mismatch
"byte-machine" "0.7.0" "0.8.0"); at ^0.8.0 it passes. A ^0.7.0 floor could not have been met from
the Akku index anyway: caret on 0.x admits no 0.8.x. MEASURED (macOS arm64, Chez 10.4.1, CMake
4.3.3, byte-machine c1f7791): test-all 91/91, no-scheme 13/13; `make check-akku` in ubuntu:24.04
amd64 with Akku 1.1.0: 15 src/ libraries, consumer green, with byte-machine 0.8.0's own manifest
and .akkuignore in the dependency. NEXT: byte-machine on the Akku index, then chez-uri (0045).

PR #47 CLOSED OUT (2026-10-11, the closing ritual, on the maintainer's word). Squash-merged as
2cc18ed on cb11061, pinned by --match-head-commit fecfae8; main had not moved. Merged tree 8d17e3d
= tested tree 8d17e3d (hash compare). CI DID NOT RUN: run 38178268454 was refused over billing
(annotation read); a PR comment records it with the local evidence. Before chore/byte-machine-0.8.0
was deleted (local and remote), no open PR was based on it (checked). The shared checkout, clean,
fast-forwarded to 2cc18ed, and its submodule, clean, was moved to the new pin with `git submodule
update --init` (c338a57 -> c1f7791). The worktree was removed after both trees were checked clean
and its tree compared equal to 2cc18ed's. #48 (CI without the token) stays open and now needs a
rebase: both add a `### Changed` section to CHANGELOG [Unreleased] and append to this ledger.

REFLECTION. Three things. (1) A FAST-FORWARD DOES NOT MOVE A SUBMODULE. `git merge --ff-only`
moved the gitlink to c1f7791 and left vendor/byte-machine checked out at c338a57 (`+` in `git
submodule status`). A build there would have run the old runtime while the tree claimed the new
one, and nothing in the suite compares the two. Catching up main after a pin bump includes `git
submodule update`. (2) THE REGENERATOR'S OUTPUT WAS READ, NOT ITS SILENCE. "Byte-identical" rests
on parser-refresh's exit 0 and "wrote 28766 bytes" at the new pin, not on a clean diff alone
(regenerate-and-diff-needs-the-regenerator-to-run). (3) A LANE MOVED THE MANIFEST WITH THE PIN.
#45's floor check refused the bump by name until Akku.manifest said ^0.8.0, and that was right on
its merits: caret on 0.x admits no 0.8.x, so ^0.7.0 could never resolve from the index.

NEXT. (1) #48: rebase onto 2cc18ed and re-test, then merge; then the maintainer can delete the
SUBMODULES_READ_TOKEN secret. (2) byte-machine on the Akku index, then chez-uri (0045). (3) Publish
the site: enable Pages and restore Actions billing (fifteen PRs, #33 to #47, merged without a CI
verdict). (4) Carried: the easy layer's optional extensions; the sibling items in #43's NEXT (5).

CI: THE SUBMODULE WITHOUT A TOKEN (2026-10-11, session 94df59, on the maintainer's request; branch
ci/anonymous-submodule off main cb11061). byte-machine went public (verified anonymously: API
HTTP 200, `git ls-remote` with no credentials), so ci.yml no longer needs SUBMODULES_READ_TOKEN.
The "Require the submodule read token" step and the GIT_CONFIG insteadOf rewrite that carried
the secret are gone; `Init submodules` stays, before Chez is built, as an anonymous `git
submodule update --init` with GIT_TERMINAL_PROMPT=0. The comment calling byte-machine private
went with it. REHEARSED, since CI is still refused over billing: in ubuntu:24.04 amd64 with no
credentials, a clone of uriparse ran the step as written at main (pin c338a57) and at #47's tip
(pin c1f7791): exit 0, the pinned commit checked out, 6 runtime libraries each. Control: a fetch
that needs credentials failed in 1s with "terminal prompts disabled", exit 128. actionlint clean.
Separate from #47 (the pin moves alone, decision 0002 item 6). NEXT: once this merges, the
maintainer can delete the SUBMODULES_READ_TOKEN Actions secret.

PR #48 CLOSED OUT (2026-10-11, the closing ritual, on the maintainer's word). #47 merged first,
so #48 was rebased onto d13ffd9: conflicts in CHANGELOG [Unreleased] (one `### Changed` section,
the pin's bullet first) and in this ledger (main's entries first). The marker guard was written to
stop on a match, `! rg -q '<markers>' <files> && git rebase --continue`, and the rebased commit was
checked for added markers. The worktree's submodule, left at c338a57 by the rebase, was moved to
the pin (c1f7791) before testing: make test 91/91, no-scheme 13/13, actionlint clean, on tree
072adfb. Force-pushed with a lease on the old head 9972056. Squash-merged as 3264053 on d13ffd9,
pinned by --match-head-commit a5e2535. Merged tree 072adfb = tested tree (hash compare). CI DID
NOT RUN: run 38179082333 was refused over billing (annotation read); a PR comment records it with
the local evidence and the credential-free rehearsal of the new step. Before ci/anonymous-submodule
was deleted (local and remote), no open PR was based on it (checked). The shared checkout, clean,
fast-forwarded to 3264053; its submodule already matched the pin. The worktree was removed after
both trees were checked clean and its tree compared equal to 3264053's.

REFLECTION. Three things. (1) TWO LESSONS FROM EARLIER TODAY HELD. The marker guard written after
#44 stopped on a match as it should, and the #47 lesson (a moved gitlink does not move the
submodule) applied to a rebase too: the rebase across the pin bump left vendor/byte-machine on
v0.7.0, and testing there would have run the old runtime. (2) A CI CHANGE MERGED WITHOUT CI. The
evidence is a rehearsal of the step as written, with no credentials, at both pins, plus a control
that a credentialed fetch fails fast. That is strong for the step's own behaviour, but not for
how it interacts with actions/checkout@v7 on a hosted runner. The first funded run on main is the
real test. (3) KEEP SEPARATE WHAT MOVES SEPARATELY. #47 and #48 shared a cause, byte-machine going
public, but decision 0002 keeps a pin alone, and the split cost only one trivial rebase.

NEXT. (1) The maintainer can delete the SUBMODULES_READ_TOKEN Actions secret: nothing reads it.
(2) When Actions billing returns, read the first run on main for `Init submodules` (anonymous,
GIT_TERMINAL_PROMPT=0) before anything else; sixteen PRs (#33 to #48) have merged without a CI
verdict. (3) byte-machine on the Akku index, then chez-uri (0045). (4) Publish the site: enable
Pages. (5) Carried: the easy layer's optional extensions; the sibling items in #43's NEXT (5).

DISTRIBUTION: THE DESIGN RECORDS STAY HOME (2026-10-14, session 94df59, on the maintainer's
request; branch chore/dist-export-ignore off main 31f2d44). Asked to make sure .plans and the like
are not distributed, and that site/ libraries are not installed. FOUND: .gitattributes had no
export-ignore, so a GitHub source archive and the Akku package would both carry .plans/ (54
entries, among them a spike .sps and a .c file), .superpowers/ and AGENTS.md. The Akku archive builds
a package the way `git archive` does: byte-machine 0.8.0's repack (sha256 matched the index) lacks
exactly its export-ignored .plans, .decisions and AGENTS.md and keeps .reference/;
chez-cmark-gfm 2.0.0 has no .gitattributes, and its published repack ships its .plans/ and
AGENTS.md. `akku install` unpacks the whole package into .akku/src/<name>/ (akku's fetch.scm),
so all of it reaches a consumer. .gitattributes's comments were chez-httparse's (an llhttp corpus,
"decision 0007", HTTP fixtures) and are rewritten for this tree: the RFC text's PROVENANCE digest
and 61 form feeds, the fingerprint sample and stale root. CHANGE: export-ignore for .plans,
.superpowers and AGENTS.md. check-akku gains check 0 (git archive --worktree-attributes at HEAD
must leave out the three and hold src/uri/easy.sls) and a named site/ check ahead of the exact
library diff. WITNESSED in ubuntu:24.04 amd64, Akku 1.1.0, each verdict on status AND message:
W1 the new checks with no export-ignore, failed "the package would ship .plans", exit 2; W2 with
export-ignore, passed, 15 src/ libraries; W3 .akkuignore emptied (bind-mounted), failed naming all
8 site/ libraries and ".akkuignore must list site", exit 2. NOT FIXED HERE: chez-cmark-gfm's
published 2.0.0 ships its .plans/ and AGENTS.md, and chez-httparse should get the same lines before
it publishes.
README.org, on the maintainer's request in the same PR: a "What is distributed" section (what the
package and a source archive leave out, what Akku installs, what check-akku checks) replaces the
one-line check-akku description, and the Layout table gains .plans/ and .superpowers/ rows,
each marked not distributed.

PR #49 CLOSED OUT (2026-10-14, the closing ritual, on the maintainer's word). Squash-merged as
8f46fc4 on 31f2d44, pinned by --match-head-commit 5fb1563; main had not moved. Merged tree 19a7b76
= tested tree (hash compare). CI DID NOT RUN: run 38549367773 was refused over billing (annotation
read); a PR comment records it with the local evidence (make test 91/91 on the merged tree,
no-scheme 13/13, check-akku witnessed three ways in ubuntu:24.04 amd64). Before
chore/dist-export-ignore was deleted (local and remote), no open PR was based on it (checked). The
shared checkout, clean, fast-forwarded to 8f46fc4; its submodule already matched the pin. The
worktree was removed after both trees were checked clean and its tree compared equal to 8f46fc4's.

REFLECTION. Three things. (1) CHECK WHAT THE CONSUMER RECEIVES, NOT ONLY WHAT INSTALLS. check-akku
modelled the package as every tracked file and judged only .akku/lib, so .plans/ could ride along
into every consumer's .akku/src/ with the check green. Check 0 now asks git archive, the archive's
own rule, what the package holds. (2) PUBLISHED ARTIFACTS SETTLED IT. Two real repacks, one with
export-ignore and one without, showed how the archive builds a package, and they turned up a
sibling's live leak (chez-cmark-gfm 2.0.0). Spawned tasks now carry that to chez-httparse and
chez-cmark-gfm. (3) A COPIED FILE'S CLAIMS NEED READING, NOT ONLY ITS NAMES. The rename audit hunts
one token, and .gitattributes passed it while describing an llhttp corpus and HTTP fixtures this
tree never had.

NEXT. (1) The v0.8.0 release, when the maintainer asks: [Unreleased] -> [0.8.0], CMakeLists and
Akku.manifest to 0.8.0, a release record like 0043, a signed tag and a GitHub Release. (2) uriparse
public, then the maintainer's `akku publish` from that tag (0045 step 3); then docs/installing.md
can offer `akku install chez-uri`. (3) The sibling tasks for chez-httparse and chez-cmark-gfm's
export-ignore. (4) Delete the SUBMODULES_READ_TOKEN secret. (5) Actions billing (seventeen PRs, #33
to #49, merged without a CI verdict) and Pages. (6) Carried: the easy layer's optional extensions;
the sibling items in #43's NEXT (5).

SITE: CHEZ-LIBUV'S LAYOUT CARRIED OVER (2026-10-16, session 94df59, on the maintainer's request;
branch fix/site-layout-from-chez-libuv off main 7dbce0f). From chez-libuv #144: a "Source code" link
in the top bar ahead of the theme toggle, a description and keywords meta on every page (uriparse's
own wording), `a.source-link` styles, the wordmark's margin 3px -> 6px, and sidebar links that
underline in the link colour on hover. From chez-libuv #142 (also chez-cmark-gfm #25): the theme
script's localStorage reads and writes inside try blocks. NOT carried: chez-libuv's hard-coded
README.md (uriparse routes the home page through page-html-name) and its stylesheet's lack of
uriparse's td alignment and td-code nowrap rules. Equivalent colour notation (rgb() for the same
hex) was left alone. TESTS FIRST: three new test/site/test-site.sps cases (the source link ahead of
the toggle, both metas inside <head>, localStorage twice and each inside a try) failed on the old
template, then 47/47. A mutant with setItem outside its try failed the try case with (2 (211)).
Behaviour: chez-libuv's .plans/theme-storage-probe.js under node 20 with the rendered scripts: the
old one is unwired when the storage getter throws or setItem throws; the new one wires and toggles
in all three modes and still stores when storage works. make check-site green (chez-cmark-gfm
v2.0.0), the site built, and the browser pane showed the link, the hover and the metas.

FIX: A ROOT-RELATIVE LINK ON THE SITE (2026-10-16, session 94df59, on the maintainer's request;
branch fix/docs-root-relative-link off main 4b414ea). The maintainer's 4b414ea added "These pages
were generated from [Markdown](/docs)" to docs/README.md. GitHub resolves /docs from the
repository root; the site is served under /uriparse/, where it is the account's /docs, a 404.
check-site passed it: (site links) left any link it did not recognise alone and never counted it.
Now a root-relative target is a dangler (reported, never rewritten) and a protocol-relative //
one stays external. TESTS FIRST: the dangler case failed on the old rule and passes on the new; the
protocol-relative case pins that the rule does not over-reach. check-site, with the link still
/docs, then failed by name, "link resolution FAILED ... danglers=((README.md . /docs))" (the
message was "anchor resolution", which no longer covered it). Fixed to ../docs, which the site
rewrites to the GitHub blob at SITE_REF; the page's old closing line, now redundant, is gone.
check-site green; the built index links .../uriparse/blob/main/docs.
