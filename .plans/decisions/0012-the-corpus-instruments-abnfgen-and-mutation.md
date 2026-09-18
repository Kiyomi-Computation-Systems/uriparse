# 0012: the grammar generates the positive corpus, and mutation generates the negative one

Date: 2026-09-18
Status: accepted
Amends: [0005](0005-the-corpus-is-the-rfcs-own-vectors.md) item 4
Plan: [the design](../2026-09-18-chez-uri-design.md) §6

## Context

[0005](0005-the-corpus-is-the-rfcs-own-vectors.md) item 4 says that where the
RFC gives no vectors, the instrument is a property rather than an invented
expectation. That is right and it is incomplete: a property needs inputs, and
"inputs this project made up" has the same provenance problem as "expectations
this project made up".

A survey of what exists online found no RFC 3986 conformance corpus with
provenance. Every candidate is either a parser author's own test file — which
is a record of what that parser does, not of what the grammar says — or is
WHATWG, which is [0003](0003-the-normative-reference-is-rfc-3986.md)'s
different normative reference.

The thing that was being overlooked is that **the ABNF is not only an acceptor.
It is a generator.** RFC 3986 Appendix A is a complete, normative grammar, and
[abnfgen](https://www.quut.com/abnfgen/) turns an ABNF grammar into conforming
text — with a `-c` coverage mode that, in its own words, tries "to cover each
leaf and branch of the grammar" rather than picking productions at random,
including minimum and maximum repetition counts.

A corpus generated from the normative grammar has better provenance than any
library's test file, because its authority is the same document the parser is
being held to.

## Decision

1. **The positive corpus is generated from RFC 3986 Appendix A by abnfgen.**
   Every string it produces must parse. A rejection is a bug in this parser or a
   transcription error in the grammar file, and the grammar file is checked
   against the RFC before it is believed.

2. **The generated corpus is committed, and abnfgen is not required to run the
   tests.** Same shape as the generated parser
   ([0002](0002-byte-machine-consumption-the-gitlink-and-abi-9.md) item 4):
   derived, committed so that what CI runs is reviewable as a diff, with a
   refresh target and a determinism lane. CI never installs abnfgen; a
   contributor refreshing the corpus does.

3. **The corpus is reproducible from three things, all committed**: the
   transcribed `rfc3986.abnf`, the seed, and the count. `abnfgen -r <seed>` is
   deterministic, so a refresh that produces different bytes means one of the
   three moved and the determinism lane says which.

4. **The negative corpus is charset-aware mutation of the positive one, and it
   is where error-offset expectations come from.** Untargeted mutation does not
   work — flipping a letter inside a path segment still parses. The mutator
   picks a production, picks an offset inside it, and substitutes a byte outside
   *that production's* charset. Because we chose the offset, **the expected error
   offset is known without being hand-written**, which is what the brief's M3 and
   M4 ("error offsets for each") otherwise had no source for.

5. **Per-production coverage floors, so a lane that selected nothing cannot pass
   vacuously.** This is [0005](0005-the-corpus-is-the-rfcs-own-vectors.md) item
   4's floor, applied per ABNF production rather than per input kind.

6. **Generated vectors are never counted in the same number as the transcribed
   ones.** [0005](0005-the-corpus-is-the-rfcs-own-vectors.md) item 3 stands: two
   provenances, two counts. "Passes 50 of 50 §5.4 vectors" and "passes 10 000
   generated vectors" are different claims and are reported as such.

## Two caveats, recorded rather than discovered later

**abnfgen is old and its licence is unstated.** The manual page is dated 4 March
2002 and names no licence. This does not block item 1, because what is committed
is the *corpus* — derived from RFC 3986's grammar, with abnfgen in the position
a compiler occupies — and not abnfgen itself. It does mean abnfgen is a local,
optional, contributor-side tool and never a build dependency. If its status ever
becomes a problem, item 3 is what makes it replaceable: another ABNF generator
fed the same committed grammar file produces another corpus, and only the seed
semantics change.

**abnfgen generates only valid input.** It has no near-miss or mutation mode.
That is the whole reason item 4 exists, and it is why the mutator is ours and is
charset-aware rather than random.
