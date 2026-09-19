# chez-uri design: the layer split, the scanner ABI, and v0.1

Date: 2026-09-18
Status: accepted — supersedes nothing; realises
[the project brief](2026-09-18-chez-uri-project-brief.md)
Decisions: [0001 through 0019](decisions/)

> **Amended by the forward-only findings of M2 (decisions 0018, 0019).** §3.1's
> eight-span scanner is superseded: byte-machine's forward-only model cannot
> split `//`-authority from a `/` path-absolute, nor userinfo from host, without
> workarounds — so the SCANNER splits the five coarse components (scheme,
> authority, path, query, fragment) plus the mode-3 `leading-token`, and
> userinfo/host/port and the whole host grammar (§6's M4) move into the pure
> core as functions over the `authority` field. A path-absolute's dropped leading
> `/` is recovered by the `on-rooted` event (0018). §5's library table and §6's
> milestone sizing shift accordingly. The rest of this document — the layer
> thesis (§2), the modes (§3.3), the errors' shape (§3.4), the core (§5), v0.1's
> stopping point (§6) — stands.

The brief says what to build and why it is its own repository. This document
says what the thing *is*: the constraints the generator actually imposes, the
span and callback surface those constraints permit, and where v0.1 stops.

Everything in §1 was checked against `vendor/byte-machine`'s source at v0.6.0,
not against its `.reference/` prose. Where a claim below cites a file and line,
that is the line that enforces it.

---

## 1. What byte-machine enforces

Five facts shape every decision after this section.

1. **One span is active at a time, machine-wide.** `span-transfer`
   (`src/byte-machine/verify.sls:1756`) sets the abstract state to
   `(active s)` at a span-start and `none` at a span-end; a span-start reached
   with another span open is refused `invalid-span-state` — *"span overlap:
   another span is already open"* (`:1775`). **Spans do not nest.** A component
   and a sub-component cannot both be spans.

2. **No event or decision callback may fire while a span is open.**
   `span-active-at-pause` (`:1798`) refuses every `pause` node and every
   `callback` node reachable with a span active. A callback that reports
   something about a span must run *after* that span has closed.

3. **Paths into a node must agree about the active span.** The lattice joins to
   `top` on disagreement and reports `inconsistent-span-state` (`:1886`). Two
   routes may converge only where they agree — in practice, where both have
   closed whatever they opened.

4. **A span may still be open at an *error* terminal.** Only `stop` and
   `finish` are checked (`span-active-at-exit`, `:1804`). Error routes need no
   span-end nodes, which keeps the error arms cheap.

5. **An empty span is observable.** `byte-machine-span-fragment-step/v2`
   delivers the single empty fragment when `from == to` and nothing has been
   delivered yet (`src/byte-machine/runtime.sls:831`), and the `span-completion`
   step always invokes the declared completion callback (`:1211`).

Fact 5 is the one the brief does not mention, and it is the one the whole
component ABI rests on. See §3.2.

---

## 2. The layer split

The seam is where the brief put it, and it is a type as well as a boundary.

```
bytes ──► (generated uri-scanner)  ── spans, events, errors ──►  (uri collect)
             the machine                                            the shell
                                                                       │
                                                              uri-components
                                                                       │
                                          ┌────────────────────────────┤
                                          ▼                            ▼
                                   (uri percent)               (uri normalize)
                                   (uri path)                  (uri recompose)
                                   (uri resolve)
                                          the pure core
```

- **The machine** is the only thing that is *fed*. It finds boundaries, reports
  offsets, and emits nothing.
- **`(uri collect)`** is the imperative shell: it copies span fragments — copies,
  per byte-machine's one rule that a delivered range is valid only for the
  dynamic extent of the callback — into a `uri-components` value. It is the
  only library that allocates proportionally to input, and it does so because
  its caller asked for the components.
- **The core** is total functions over `uri-components` and bytevectors. Every
  one of them can be called with a literal and compared to a constant.

`uri-components` is the seam type: five fields, each a bytevector **or `#f`**.
`#f` is *absent*; a zero-length bytevector is *present and empty*. §3.2 is why
the machine can tell them apart, and §5.2 of RFC 3986 is why it must.

---

## 3. The scanner ABI (decisions 0008, 0004, 0009)

### 3.1 The spans

Eight, **all declared at M2**, before most of them validate anything. Fact 1 is
the reason: a span cannot be refined into sub-spans later, so shipping one
`authority` span at M2 and splitting it at M4 would be a breaking change to
every consumer. Splitting it now costs only delimiter work — finding `@`, `:`
and `[`…`]` — which is exactly what M2 is.

| span | present when | absent means |
|---|---|---|
| `scheme` | a `:` closed the leading token | a relative reference |
| `leading-token` | mode 3 only, until the verdict | n/a — see §4 |
| `userinfo` | an `@` appeared in the authority | no userinfo |
| `host` | an authority was present | **no authority** |
| `port` | a `:` followed the host | no port |
| `path` | always | never absent |
| `query` | a `?` appeared | no query |
| `fragment` | a `#` appeared | no fragment |

There is deliberately **no `authority` span.** `authority = [ userinfo "@" ]
host [ ":" port ]` makes `host` mandatory whenever an authority is present, and
`host` may be an empty `reg-name`. So *the presence of `host` is the presence of
the authority*, and the empty authority in `http:///p` is a `host` span that
fires with zero bytes — distinguishable from `http:/p`, where it does not fire
at all.

**The path is one span, not one per segment.** `/` is not in `pchar`, so
segmentation is a total function of the path bytes and belongs in the core,
where `remove_dot_segments` needs it anyway. One span per segment would cost N
callbacks per path and give the consumer nothing the core cannot recover.

### 3.2 Absent is not empty, and the mechanism already carries it

RFC 3986 §5.3 recomposes on *defined*, not on *nonempty*:

```
if defined(query) then append "?" + query
```

and §5.2.2 branches the same way. `http://a` and `http://a?` are different URIs
and resolve differently. By fact 5:

- an **absent** component fires **nothing** — no data fragment, no completion;
- an **empty but present** component fires its data callback once with
  `from == to`, then its completion callback;
- a **nonempty** component fires one or more data fragments, then completion.

So presence is carried by *whether the callbacks fire at all*. No presence
flags, no sentinel events, no extra fields.

**Every component span therefore declares both callbacks.** A span with only a
data callback cannot report an empty-but-present component across a feed
boundary, because the final empty fragment of an already-delivered span is
suppressed (`runtime.sls:840`) — the completion event is the one signal that is
always exactly once.

### 3.3 The modes

One settable `uint` field, `mode`, width 8, declared initial `0`, read at
`make-parser` (byte-machine ≥ v0.5, generated ABI 8; we pin 9). The mechanism
is chez-httparse decision 0021's; the reasoning is its 0017's.

| value | name | production | leading token is |
|---|---|---|---|
| 0 | *unset* | — | refused at offset 0 |
| 1 | `uri` | §3 `URI` | a `scheme`; anything else is an error |
| 2 | `relative-ref` | §4.2 `relative-ref` | a `segment-nz-nc`; a `:` is an error |
| 3 | `uri-reference` | §4.1 `URI-reference` | undecided — see §4 |

`0` refuses rather than guesses. A field initial cannot be made mandatory, so
the alternative to a refusing default is a silently permissive one; decision
0004 records the trade and 0009 gives it the code `mode-unset`.

### 3.4 Errors

We inherit no error vocabulary. chez-httparse took llhttp's code/reason pairs
(its 0013); there is no equivalent to take here, so the set is ours to define
and it is part of the scanner's public API — it is what the ratchet pins.

**An error names the ABNF production that failed.** The offset comes free from
`parser-error-offset`. Decision 0009 sets the rule and the v0.1 set.

### 3.5 Three rules the spike turned up

Each of these was found by watching something fail, not by reading the
reference. They are cheap to obey and expensive to discover at M4.

1. **Every success terminal in this grammar is a `finish`, never a `stop`.** A
   `stop` node an EOF walk can reach is refused `eof-reachable-stop`
   (`verify.sls`, pass-eof-execution). A URI may legally end at almost any
   component boundary, so every one of those boundaries is on an EOF route, and
   a `stop` anywhere among them fails verification. The spike's first draft used
   `stop` after the verdict and drew four diagnostics.

2. **Every delimiter edge is `reexecute`, never `advance`.** A span-end emits
   `[mark, cursor)`. An `advance` on the delimiter moves the cursor past it
   *before* the span closes, putting the delimiter inside the span. The spike's
   first draft advanced on `:` and reported `foo:` as a **four**-byte scheme.
   The delimiter is consumed by the node after the span-end, not by the edge
   into it.

3. **An empty fragment carries emptiness, not a position.** When a span closes
   at `parser-finish!` the mark is re-anchored to 0 (byte-machine decision 0042
   item 4), so `?` with an empty query reports `(0 0)` — not `(1 1)`. A
   feed-boundary flush suppresses empty fragments, so the delivery happens at
   the span-end. `(uri collect)` must read `from == to` as *present and empty*
   and must never treat an empty fragment's `from` as an offset.

---

## 4. The scheme / first-segment ambiguity

The brief calls this the one hard design question. It is narrower than it looks,
and the reason is worth writing down, because it is why a forward-only machine
can do this at all.

```abnf
scheme        = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
segment-nz-nc = 1*( unreserved / pct-encoded / sub-delims / "@" )
```

`+` is `sub-delims`; `-` and `.` are `unreserved`. So **`scheme`'s charset is a
strict subset of `segment-nz-nc`'s**, and `scheme` merely additionally requires
its first byte to be `ALPHA`. Both readings therefore stay live *together* over
exactly the same prefix, and the reading is decided by the first byte that is
either a delimiter (`:` → scheme; `/`, `?`, `#`, EOF → segment) or a byte inside
`segment-nz-nc` but outside the scheme set (e.g. `_`, `~`, `%`, `!`, `@` → segment).
There is no point at which the machine must know something it has not yet seen.

What it *cannot* do is rename a span. `make-span-declaration` binds a span to
its callbacks at build time, so an optimistically-opened `scheme` span cannot
become a `path` span when the delimiter disappoints.

**The resolution.** Modes 1 and 2 have no ambiguity — the caller has removed it
— and open `scheme` or `path` directly. Mode 3 opens `leading-token`, closes it
at the delimiter, and *then* fires a zero-width event naming the verdict:
`on-scheme-confirmed` or `on-segment-confirmed`. Fact 2 is why the event comes
after the close and not before; facts 1 and 3 are why the three routes may
converge afterwards, since all three have closed whatever they opened.

The leading-token scanner is therefore built **three times** — the same handful
of nodes with a different span name and a different verdict — and all three
converge on the shared continuation at the delimiter. That is a duplicated
scanner, not a duplicated grammar.

**Mode 3's price, stated plainly.** When the verdict is `segment`, the path is
the concatenation of the `leading-token` span and the `path` span. `(uri
collect)` stitches them. Modes 1 and 2 exist so that a caller who knows which
form it expects never pays this.

**What is ruled out.** "Parse in mode 1; on error, re-parse in mode 2" is
host-level backtracking. It forces the caller to buffer the entire reference
before it can commit to a reading, which is the one thing a streaming scanner
exists to avoid. Decision 0004 records the rejection.

---

## 5. The core

**Bytevectors throughout.** A URI is a byte string: `%C3%A9` is two bytes, and
§6.2.2.1 case normalization is *ASCII only*. Staying in bytevectors makes
`(rnrs unicode)` structurally unreachable rather than merely discouraged —
which matters because `string-downcase` there performs full Unicode folding,
under which U+212A (KELVIN SIGN) lowercases to ASCII `k` and a host containing
it would compare equal to one that does not. `utf8->string` appears once, at the
edge, as a convenience. Decision 0010.

### Libraries

| library | layer | lands |
|---|---|---|
| `(uri vocabulary)` | pure, imports **nothing** — span, callback and error names, and the mode integers | M2 |
| `(uri grammar)` | build time only — the source machine | M2 |
| `(generated uri-scanner)` | committed artifact; imports `(rnrs)` and `(byte-machine runtime)` | M2 |
| `(uri components)` | the seam type; absent ≠ empty | M2 |
| `(uri collect)` | **shell** — callbacks to components | M2 |
| `(uri percent)` | core — percent decode/encode | M5 |
| `(uri normalize)` | core — §6, including the hand-written ASCII fold | M5 |
| `(uri path)` | core — §5.2.4 `remove_dot_segments`, §5.2.3 `merge` | M6 |
| `(uri resolve)` | core — §5.2.2 | M6 |
| `(uri recompose)` | core — §5.3 | M6 (was M7 — decision 0021) |

**Amendment (decision 0021).** `(uri recompose)` moved to M6, not M7: §5.2.2
reference resolution ends by recomposing the target per §5.3, and the §5.4 gate
needs a resolved *string* to compare, so recompose ships with resolve. M7 keeps
the round-trip *property* (parse → normalize → recompose → parse = fixed point),
which is a stronger claim than the renderer itself.

`(uri vocabulary)` importing nothing is the same argument chez-httparse's
decision 0021 item 4 makes for `(httparse modes)`: three parties must agree on
these names — the grammar that declares them, the harness that binds them per
fixture, and an embedder writing callback bindings — and a pure table is also
what an embedder can import without dragging the builder and verifier in behind
it.

---

## 6. v0.1 is resolution-first

Decision 0011. The order is **M1 → M2 → M5 → M6 → M7 → release**, and the
brief's M3 (charset validation) and M4 (the host grammar) are **v0.2**.

The reason is that §5.4 is the only normative corpus this project has, and
reference resolution depends on component *splitting* (M2) and on nothing in M3
or M4. Taking M5–M7 next reaches "passes all of §5.4" on the highest-confidence
work available, and unblocks `chez-http-server` at the same M2 either way.

**What v0.1 therefore is, and what it must not claim.** A URI *splitter* and a
complete, correct pure core — not a validator. It will accept bytes the ABNF
rejects: `http://exa mple.com/`, `%ZZ`, a malformed `IPv6address`. `README.org`
says so in those words. The house rule is that a property is measured or it is
not claimed, and "RFC 3986 compliant" is a claim v0.1 has not earned.

**One correction to the brief's sizing, carried forward.** M3 is cheaper than
it reads. M2 already builds a byte-dispatch node per component to find the
delimiters; charset validation changes those nodes' *fallback edge* from "accept"
to "error" and adds two nodes per component for `pct-encoded`. The node count
barely moves. Its timing is therefore a choice that can be revisited at M2 — as
a scope decision, not a re-plan — and this document records the estimate so the
revisit has something to check against.

> **Superseded by [decision 0024](decisions/0024-charset-validation-is-the-cores-over-the-split-components.md).**
> The grammar-side sizing above predates [decision 0019](decisions/0019-the-scanner-splits-five-coarse-components-and-the-core-owns-the-authority.md),
> which redrew the functional-core line: charset errors are the CORE's, raised
> over the split component bytevectors, and the scanner stays delimiter-only
> (0019 item 5, enforced green by `vocabulary-tests.sps`). So M3 does NOT change
> the scanner's fallback edges or regenerate `(generated uri-scanner)`; it adds a
> pure `(uri charset)` and rebases offsets in the shell. Two further corrections
> 0024 records: the brief's "port digits" and the `http://exa mple.com/`
> space-in-host case above are **M4**, not M3 — the authority is one opaque span
> until M4 splits userinfo/host/port, and an error cannot name the violated
> production (0009 item 1) without that split.

**And one to M4.** The brief budgets `IPv6address` at 150–250 nodes and reserves
a `decision`-callback fallback against it. That estimate is ABNF's shape, not
the grammar's: ABNF cannot count, so the RFC writes nine alternatives for what
is a three-counter machine. byte-machine has uint fields, `field-branch` and
`integer-accumulate`; tracking groups-seen, saw-`::` and hex-digit-count and
routing on `:` / `.` / `]` should come in near 40–60 nodes. `dec-octet` falls
out of the same observation — accumulate into a **u8** and the overflow edge
*is* the `> 255` test, leaving one extra check ("a leading `0` means length 1"),
which also rejects `0000`. Measure at M4 as the brief says; do not reserve the
fallback.

---

## 7. The instrument (decisions 0005, 0012, 0013, 0014, 0015)

There is no RFC 3986 conformance corpus with provenance — nothing plays the role
llhttp played for `chez-httparse`. Five instruments replace it, each with one
job, and naming the jobs separately is what stops the fifth quietly becoming an
oracle.

| instrument | job | provenance | gates a milestone? |
|---|---|---|---|
| RFC §5.4 / §5.2.4 / §1.1.2 vectors | is resolution **correct** | normative | **yes** — M6 is 100% or not done |
| abnfgen over Appendix A | every valid shape parses | the normative grammar | yes, under per-production floors |
| charset-aware mutation of the above | every invalid shape is rejected, **at the right offset** | ours, derived | yes |
| WPT `urltestdata.json`, inputs only | robustness | adversarial, BSD-3-Clause | no pass count, by design |
| uriparser, local + opt-in | **finds work for the other four** | none — not an authority | **no** |

The first four carry v0.1 on their own. The fifth is a search heuristic over an
input space nothing else can survey, and decision 0014 item 3 is what keeps it
one: the lane fails on an *unclassified* disagreement, never on a disagreement.

Two errata land on the first row and are rejected against the ABNF before
transcription, not after a lane goes red — decision 0015.

## 8. Portability

Decision 0007. `src/` imports `(rnrs)`, `(byte-machine …)` and this project's
own libraries, asserted by a lane rather than trusted.

**Every `.sls` and `.sps` carries a `#!r6rs` line.** byte-machine v0.6.0 (#137)
ran its whole toolchain on Guile 3.0.11 and Racket 9.3 with byte-identical
emission; Racket needs that line and Chez and Guile accept it. It is free today
and a retrofit later.

Nothing about that makes this project's own portability a *claim*. Until a
second implementation runs in CI, `README.org` says only that the source is
R6RS.

---

## 9. Open questions carried forward

1. ~~**Does a callback node verify on an EOF route?**~~ **Answered 2026-09-18 —
   yes.** A spike built the exact shape (`eof-target → span-end → callback →
   finish`) against byte-machine v0.6.0: it verifies, and feeding `foo` then
   `parser-finish!` fires `on-token-data (0 3)`, `on-token-complete`,
   `on-segment-confirmed`, reaching `finished`. Decision 0004's mode 3 holds as
   written. The same spike witnessed decision 0008 item 4: `?` reports an empty
   data fragment plus a completion, `a` reports nothing at all. It becomes a
   lane at M2 rather than staying a loose file. Three constraints it turned up
   are recorded in §3.5.

2. ~~**Is there an allocation lane?**~~ **Answered 2026-09-18 — no**, decision
   0016. The property is byte-machine's and is measured there; the one thing
   this project allocates, `(uri collect)`, allocates on purpose. A benchmark
   lane, when there is something to measure, reports rather than asserts.

3. **Should the machine flag "this component contained a `%`"?** It would let
   the core skip a scan. Not v0.1; the core scans.
