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
