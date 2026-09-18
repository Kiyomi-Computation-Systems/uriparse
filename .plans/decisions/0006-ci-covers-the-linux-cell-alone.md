# 0006: CI covers the Linux cell alone

Date: 2026-09-18
Status: accepted
Plan: [the brief](../2026-09-18-chez-uri-project-brief.md)
References: `byte-machine` decision 0041, `chez-httparse` decision 0004

## Context

This is a private repository on billed CI minutes. `byte-machine` has already
had to strike its Tier 1 matrix down to "verified locally" under a zero CI
budget (its decision 0041), and `chez-httparse` covers one cell for the same
reason. Development happens on macOS arm64; the thing that has to keep working
for anyone else is Linux.

## Decision

1. **CI is one cell: Linux, Chez built from source and cached.** It runs the
   `pr` selection, then `release`, then `no-scheme`.

2. **No macOS runners.** macOS arm64 is where this is developed and is exercised
   continuously by that fact; a paid runner would re-verify the one cell that is
   never in doubt. This is a standing instruction in `AGENTS.md`, recorded here
   so the reason survives the instruction.

3. **Windows and arm64 Linux are deferred, and deferred means not run — not
   passing.** No lane, no badge and no README sentence says otherwise. The build
   layer carries no platform branching, so the prediction is that they work; a
   prediction is not a result.

4. **The `BACKEND` argument is carried forward from day one.** `chez-httparse`'s
   Scheme lanes already take it (`cmake/HttparseSchemeLane.cmake`, whose error
   message reads *"Known backends: chez"*). The hook costs nothing now and is
   exactly the thing that would otherwise have to be retrofitted the day a
   second R6RS implementation enters CI
   ([0007](0007-src-is-pure-r6rs-and-chez-is-confined.md)).

5. **An empty test selection is a failure, never a silent pass.** That rule
   lives in the CTest presets themselves (`execution.noTestsAction`), not only
   in the `Makefile`, so the preset path and the `make` path cannot disagree.
