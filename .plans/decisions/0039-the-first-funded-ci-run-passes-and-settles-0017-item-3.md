# 0039: the first funded CI run passes on the Linux cell, and settles 0017 item 3

Date: 2026-10-01
Status: accepted
Settles: [0017](0017-m1-ships-on-one-cell-and-it-is-not-the-linux-one.md) item 3 (its two
never-executed predictions), as its item 5 asks: in a record, not only a green tick
References: [0006](0006-ci-covers-the-linux-cell-alone.md) (the one Linux cell), PR #28

## Context

[0017](0017-m1-ships-on-one-cell-and-it-is-not-the-linux-one.md) deferred the Linux cell
because the billed minutes had run out, and its item 3 named two things that had never
executed anywhere. The minutes came back on 2026-10-01. All 65 runs before that, from
M1's PR on 2026-09-18 to #27, were refused before a single step ran. The jobs API shows no
step in any of them.

The first run that started was not yet a run of the suite. The workflow had never fetched
the private `vendor/byte-machine` submodule, so it would have stopped at configure. PR #28
fixed that and added a lane for a CMake 3 policy trap only the runner could hit (CHANGELOG
[Unreleased]). Its first attempt stopped where it was built to stop, at the missing
`SUBMODULES_READ_TOKEN` secret. The second attempt, after the secret was added, is the
first run of this suite on Linux.

## Decision

1. **The Linux cell has run, and passed.** Run 36870151249, attempt 2, on 2ccdb17:

   | | |
   |---|---|
   | image | `ubuntu-24.04`, release `20260920.314` |
   | Chez | 10.4.1, built from source (cache miss), machine type `ta6le` |
   | CMake | 3.31.6 |
   | `pr` | 78 of 78 |
   | `release` | 78 of 78 |
   | `no-scheme` | 12 of 12 |

2. **Prediction 1 held: `ta6le` derives `linux/amd64`.** The job sets `URI_EXPECT_OS=linux`
   and `URI_EXPECT_ARCH=amd64`. With them set, the bootstrap and self-test lanes, source and
   aot, require the live `(adapter-os)` and `(adapter-architecture)` to equal them, not just
   to be known. All four passed. The comparison is live: on macOS arm64 the same four lanes
   pass with `URI_EXPECT_OS=darwin` and all four fail with `linux`.

3. **Prediction 2 held: the ahead-of-time lanes pass on a cold runner.** A fresh runner has
   no build tree, so every object was compiled in that run, under
   `build/dev/chez-objects/10.4.1/ta6le`, the root keyed by Chez version and machine type.
   All 25 `.chez.aot` lanes passed, in `pr` and again in `release`.

4. **What it does not settle.** CI is still one cell
   ([0006](0006-ci-covers-the-linux-cell-alone.md)). Windows and arm64 Linux are still not
   run, and deferred still means not run. The runner's CMake is the image's choice, not
   this project's floor. 3.31.6 is now the oldest CMake this suite has passed on, but the
   declared 3.26 floor is still untested.

5. **The never-run disclosure retires.** The README's "CI has not run" banner gives way to
   this result. The CHANGELOG sections for v0.1.0 to v0.6.1, and decisions 0023 to 0037,
   stay as written: each was true when it shipped. A release cut from here can cite a
   green run on its own commit instead of carrying 0017's disclosure.
