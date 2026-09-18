# 0016: there is no allocation lane; a benchmark reports and does not assert

Date: 2026-09-18
Status: accepted
Settles: [0007](0007-src-is-pure-r6rs-and-chez-is-confined.md) item 5
Milestone: M1

## Context

[0007](0007-src-is-pure-r6rs-and-chez-is-confined.md) item 5 left one question
open for M1 to answer: does chez-uri have an allocation lane at all? The
question mattered because allocation measurement needs `statistics` and
`sstats-bytes`, which have no standard spelling and no common analogue, so such
a lane is Chez-only **by construction** — it is the one thing in the tree that
could not follow the rest to a second implementation.

The brief describes the scanner as "allocating nothing proportional to input",
and a lane holding that at zero is the obvious way to keep it true.

## Decision

1. **There is no allocation lane.** Not deferred — not wanted.

2. **The property is byte-machine's, and is measured there.** "The runtime
   stores no feed bytevector or slice after `parser-feed!` returns" is
   upstream's contract, asserted by its own retention lane, which holds a
   parser across a full collection and checks that a weak reference to the fed
   bytevector reads `bwp` — in both executors, with a negative control so the
   probe cannot pass by always answering "gone". A lane here would re-measure a
   dependency's guarantee and report it as this project's.

3. **The one thing chez-uri allocates, it allocates on purpose.** `(uri
   collect)` copies span fragments into a `uri-components` value because
   byte-machine's one rule is that a delivered range is valid only for the
   dynamic extent of the callback. That is proportional to the components the
   caller asked for, by design. There is no invariant to hold at zero, and a
   lane asserting a budget would be asserting a number someone picked.

4. **`README.org` does not claim the scanner allocates nothing proportional to
   input.** The claim is true of the machine and is not this project's to make
   without measuring it. A property is measured or it is not claimed.

5. **When there is something worth measuring, it is a BENCHMARK lane, which
   reports and does not assert.** The label already exists in the test
   vocabulary — `benchmark # measured rates, reported rather than asserted` —
   and it is the honest shape: a rate that varies with the host is evidence for
   a reader, not a gate for a pull request. It stays Chez-only and says so
   where it is defined.

## What this rules out

**A per-parse allocation budget.** It would be a number chosen to pass, it
would drift with every Chez release, and its failures would be
indistinguishable from a noisy runner. `chez-httparse` can afford one because
it has an upstream whose allocation behaviour is the thing under test; this
project does not.
