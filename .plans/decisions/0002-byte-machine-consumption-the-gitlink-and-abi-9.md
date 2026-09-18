# 0002: byte-machine is a pinned submodule, and the generated ABI is 9

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §1

## Context

`byte-machine` is consumed the way `chez-httparse` consumes it: as a submodule
pinned by gitlink, with the emitted parser committed to this tree. Two numbers
have to be pinned along with it — the upstream tag and the generated-runtime
ABI — and a stale pin that nothing loads is worse than no pin, because it rots
silently.

At the time of writing, `byte-machine` is **v0.6.0** and the generated ABI it
emits is **9**. The brief was drafted against ABI 8 (`chez-httparse` decision
0021's number) and is superseded on that point by this record.

## Decision

1. **`vendor/byte-machine` is a submodule pinned by gitlink**, at a release tag,
   never at a branch.

2. **The submodule does not land until M2.** M1 builds the instrument and
   invokes no emitter. A pin nothing exercises is a pin nothing notices going
   stale — `chez-httparse` decision 0002 item 2 and its own M1 correction.

3. **The generated ABI is 9**, and the number is asserted in **two** places: a
   lane that reads it from the committed artifact, and a lane that reads it from
   a freshly emitted one. Two checks, neither able to go stale quietly, is
   `chez-httparse` decision 0005 item 5 working as designed.

4. **`src/generated/uri-scanner.sls` is committed and derived.** Committed so
   that what this project ships is reviewable as a diff and loadable without a
   generator; derived from `src/uri/grammar.sls` by one emitter. A **determinism
   lane** re-emits and compares bytes, so a grammar edit without a refresh
   reddens rather than shipping a stale artifact. `make parser-refresh` and that
   lane run the same script.

5. **A generated parser depends on `(byte-machine runtime)` and nothing else
   from upstream.** Not `graph`, not `verify`, not `compile`, not `interpret`.
   This is upstream's own boundary rule and it is what lets a deployed consumer
   ship without the compiler.

6. **When the pin moves, it moves alone.** One commit carries the submodule, the
   two ABI lanes and the regenerated artifact, and nothing else, so that the
   artifact diff is reviewable on its own. A dependency bump folded into a
   behaviour milestone is a red lane nobody can attribute.
