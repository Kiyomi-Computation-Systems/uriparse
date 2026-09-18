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

GATE ⓪: stopping for review. Next is Slice ①: `src/uri/grammar.sls` for modes 1
and 2, the emitter, the committed `(generated uri-scanner)`, and the second ABI
lane + the determinism lane over it.
