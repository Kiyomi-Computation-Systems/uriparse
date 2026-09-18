# 0007: `src/` is pure R6RS, carries `#!r6rs`, and Chez is confined to four places

Date: 2026-09-18
Status: accepted
Item 5 settled by: [0016](0016-there-is-no-allocation-lane.md) (there is none)
Plan: [the design](../2026-09-18-chez-uri-design.md) §7

## Context

`byte-machine`'s `src/` is pure R6RS — `graph`, `verify`, `compile`, `interpret`,
`runtime` and the four `private/` libraries import `(rnrs)` and each other and
nothing more — and every generated artifact imports `(rnrs)` and
`(byte-machine runtime)` and nothing else. `chez-httparse` preserved that: not
one file under its `src/` mentions `(chezscheme)`.

So **chez-uri's shipped surface is portable by default.** It does not have to be
earned, only not broken.

Two things have changed since the brief was drafted. `byte-machine` v0.6.0
(`#137`, 2026-09-18) ran its whole toolchain on **Guile 3.0.11** and **Racket
9.3** (`plt-r6rs`), and in both the emitter produced a library byte-identical to
the Chez one and the generated parser returned the same statuses and offsets.
Racket needs exactly one accommodation — a `#!r6rs` line atop each `.sls` —
which Chez and Guile also accept, checked in both directions.

## Decision

1. **`src/` imports `(rnrs)`, `(byte-machine …)` and this project's own
   libraries — nothing else.** Asserted by an import-audit lane rather than
   trusted: nothing under `src/` may mention `(chezscheme)`. A few lines of
   CMake, the same habit as the rename audit and the plan-header audit.

2. **Every `.sls` and `.sps` in this project begins with `#!r6rs`**, from the
   first file. It is free today and a retrofit later, and it is the one thing a
   measured port was found to need.

3. **Where Chez is unavoidable, it is imported narrowly and enumerated.**
   `chez-httparse`'s harness is the model — `(only (chezscheme) machine-type
   scheme-version getenv system statistics sstats-bytes real-time
   with-output-to-string display-condition)` — eight names, so the whole
   portability surface is readable at a glance. `tools/emit-machine.ss` imports
   `(chezscheme)` wholesale and is the counter-example. **Copy the harness, not
   the emitter.**

4. **Chez belongs in exactly four places**: the test harness, the emitter, any
   benchmark runner, and the CMake probe.

5. **One lane cannot be portable, and says so where it is defined.** Allocation
   measurement needs `statistics` / `sstats-bytes`, which have no standard
   spelling and no common analogue. Whether chez-uri has an allocation lane at
   all is settled at M1; if it does, it is Chez-only by construction.
   **Settled: there is none — [0016](0016-there-is-no-allocation-lane.md).**

6. **Portability is not claimed until it is measured here.** `README.org` says
   the source is R6RS. It does not say the library runs on Guile or Racket until
   a second implementation runs in this project's CI. The house rule is that a
   property is measured or it is not claimed, and items 1–3 make a port *likely*,
   which is not the same thing.
