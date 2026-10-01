# 0038: the Linux cell is a named image, and the Chez cache is keyed on its OS release

Date: 2026-10-01
Status: accepted
Amends: [0006](0006-ci-covers-the-linux-cell-alone.md) item 1
References: actions/runner-images#14748 (the label moves), actions/runner-images#11926
(24.04 holds CMake at 3.31.6), [0039](0039-the-first-funded-ci-run-passes-and-settles-0017-item-3.md)
(the first funded run, on 24.04)

## Context

[0006](0006-ci-covers-the-linux-cell-alone.md) item 1 makes CI one cell: Linux, with Chez
built from source and cached. The workflow ran that cell on `ubuntu-latest`, a label GitHub
moves. Today it means Ubuntu 24.04, where the first funded run passed
([0039](0039-the-first-funded-ci-run-passes-and-settles-0017-item-3.md)). GitHub starts
moving it to 26.04 on 2026-10-19 and plans to finish by 2026-11-19
(actions/runner-images#14748). Two things would move with it, and no commit here would
show either:

- **The libraries the cached Chez links against.** The cache key named only `runner.os` and
  `runner.arch`. Both releases report the same values for these (`Linux`, `X64`). So a 26.04
  runner would restore a Chez that was built on 24.04.
- **CMake.** The image supplies it. Image 20260920.314.1 (24.04) has 3.31.6, and image
  20260920.143.1 (26.04) has 4.4.3. A script run with `cmake -P` gets its policy defaults
  from that CMake, not from this project. CI is also the only place this suite runs on
  CMake 3, because every local run uses CMake 4.

## Decision

1. **The cell is `ubuntu-24.04`, x86-64, and the workflow names it.** Moving to another
   image is a commit of its own, reviewed like any other change to what CI measures. GitHub's
   label schedule never moves it.

2. **The Chez cache key includes the OS release.** A step reads `ID` and `VERSION_ID` from
   the runner's `/etc/os-release`, which gives the key
   `chez-Linux-ubuntu-24.04-X64-10.4.1-threads`. The release comes from the machine rather
   than being copied from `runs-on`, so a bump changes the key without a second edit that
   someone could forget. An empty `ID` or `VERSION_ID` fails the step. The key follows the
   release and not the weekly image version. Ubuntu keeps library ABIs stable within a
   release, but promises nothing across releases. A new key starts with no cache entry, so
   the first run on a branch that has none builds Chez again. That miss is the re-key
   working, not a fault.

3. **The pin fixes the release, not every tool on it.** GitHub updates the 24.04 image every
   week. That image's own toolset holds CMake at 3.31.6 "to avoid CMake 4.0 compatibility
   issues" (actions/runner-images#11926), and it is due for review on 2026-12-01. If that
   review lifts the hold, CI's CMake changes with no commit here, and this record does not
   prevent it. The `Record the runtime identity` step prints CMake's version, so the change
   would at least show in the job log.

4. **The commit that moves the image states what moves with it.** At least:
   - the CMake version it brings;
   - whether any CI run still exercises CMake 3 (26.04 ships CMake 4);
   - an actionlint that knows the new label. actionlint 1.7.12 rejects `ubuntu-26.04` as
     an unknown label.

5. **Unchanged:** one Linux cell, no macOS (0006 item 2), and the job id `linux-amd64`, so
   the check name stays the same. The release does not change either: the first funded run
   was already on 24.04 (image 20260920.314, CMake 3.31.6;
   [0039](0039-the-first-funded-ci-run-passes-and-settles-0017-item-3.md)), reached through
   `ubuntu-latest`. Naming the image keeps the cell on the release that run measured.

## Evidence

Checked on macOS arm64 on 2026-10-01, before this change's first CI run:

- **actionlint** 1.7.12, with shellcheck 0.11.0: clean.
- **The new step's script**, run the way the runner runs a `run:` block
  (`bash --noprofile --norc -eo pipefail`, with `$GITHUB_OUTPUT` created empty first). This
  was done inside the `linux/amd64` images `ubuntu:24.04` and `ubuntu:26.04`.
  - It writes `release=ubuntu-24.04` in one and `release=ubuntu-26.04` in the other, so the
    two keys differ.
  - Before this change, both images produced the same key, `chez-Linux-X64-10.4.1-threads`.
  - If `VERSION_ID` is removed, `ID` is removed, or `VERSION_ID` is empty, the step exits 1
    and writes nothing.
- **Nine mutations** of the workflow were each caught by the check written for them. Each
  check reached a verdict, so no crash was counted as a catch. The mutations were:
  - back to `ubuntu-latest`;
  - an unreviewed bump to `ubuntu-26.04`;
  - the release dropped from the key;
  - each `:?` guard removed;
  - the step moved after the restore;
  - the output sent to stdout;
  - the step id renamed;
  - the separator dropped.

  actionlint alone caught only three of these: the bump, the move and the rename.
