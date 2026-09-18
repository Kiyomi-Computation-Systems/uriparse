# 0017: M1's evidence is macOS arm64 local; the Linux cell is unfunded and unrun

Date: 2026-09-18
Status: accepted
Amends: [0006](0006-ci-covers-the-linux-cell-alone.md) for M1
References: `byte-machine` decision 0041 (the same situation, the same answer)
Milestone: M1

## Context

[0006](0006-ci-covers-the-linux-cell-alone.md) says CI is one cell — Linux,
Chez built from source and cached, running `pr`, then `release`, then
`no-scheme`. The workflow that does it landed in M1 and was configured
correctly.

It has never run. Its first invocation, on the M1 pull request, returned:

> The job was not started because recent account payments have failed or your
> spending limit needs to be increased.

This repository is private and on billed CI minutes, and those are exhausted
for the month. The job did not fail; **it did not start**.

This is the same position `byte-machine` reached at its Milestone 9, and its
decision 0041 is the precedent: a Tier 1 cell made unaffordable is struck by an
explicit amendment, never waived quietly in release notes.

## Decision

1. **M1's evidence is macOS arm64, locally, and nothing else.** Measured on
   Chez Scheme 10.4.1, machine type `tarm64osx`:

   | selection | result |
   |---|---|
   | `no-scheme` | 10 of 10 |
   | `pr` | 38 of 38 |
   | `release` | 38 of 38 |
   | `corpus-refresh` | a no-op against the committed tree |
   | mutation totals | 77 (CMake), 67 (Scheme) |

2. **The Linux amd64 cell is DEFERRED, and deferred means not run — not
   passing.** [0006](0006-ci-covers-the-linux-cell-alone.md) item 3 already
   says this about Windows and arm64 Linux; it now applies to the one cell that
   record said CI *would* cover. No badge, no README sentence and no changelog
   line says otherwise.

3. **Two things have therefore never executed anywhere**, and are predictions
   rather than results until a funded run says so:
   - the OS and architecture derivation on a Linux `machine-type`. The harness
     reads Chez's own `(machine-type)` and maps `ta6le` → `linux/amd64`; every
     local run has only ever seen `tarm64osx`.
   - the ahead-of-time lanes on a cold runner, building every object from
     scratch under a version-and-machine-keyed object root.

   The build layer carries no platform branching, which is why the prediction
   is that both pass. A prediction is not a result.

4. **The workflow stays in the tree, unchanged.** Deleting it would turn a
   funding gap into a capability gap, and the next funded month would have to
   rebuild it. It is configured, committed, and unrun, and this record is the
   trail.

5. **This is an M1 amendment, not a standing policy.**
   [0006](0006-ci-covers-the-linux-cell-alone.md) is unchanged for every later
   milestone. The first funded run discharges item 3; when it does, the result
   goes in a record rather than only in a green tick, because item 3's two
   predictions are the ones a first run exists to answer.

## Why this is not simply "merge it anyway"

The merge is fine — the work is measured, on one cell, and that cell is the one
this project is developed on. What would not be fine is the tree continuing to
say CI covers Linux while nothing has ever run there. The house rule is that a
property is measured or it is not claimed, and the cost of keeping that rule
here is one file.
