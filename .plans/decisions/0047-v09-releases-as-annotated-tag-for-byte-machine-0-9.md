# 0047: v0.9 releases as the annotated tag v0.9.0, for byte-machine 0.9, with no library change

Date: 2026-11-11
Status: accepted
References:
[0046](0046-v08-releases-as-annotated-tag-and-is-the-first-public-release.md) (the release
checklist this follows),
[0045](0045-chez-uri-ships-on-akku-as-exactly-src-after-byte-machine.md) (the package, its
manifest lane and `make check-akku`),
[0002](0002-byte-machine-consumption-the-gitlink-and-abi-9.md) (the pin, which moved on a
commit of its own),
[0030](0030-the-rfc-3986-conformance-audit-is-clean-recognition-equivalence-is-earned.md)
(the validation claim every release since v0.3 carries unchanged).

## Context

The arc since v0.8.0 (tag on 9416299) is three merged pull requests:
- #53, CONTRIBUTING.md, SECURITY.md, the issue and pull-request templates, and
  `make check-help`;
- #54, the Akku install in `docs/installing.md` and README.org, once chez-uri 0.8.0 was on
  the index;
- #55, the byte-machine pin to v0.9.0, with the regenerated scanner and the manifest's floor
  at `^0.9.0`.

No `(uri …)` library changed: `git diff v0.8.0 -- src/uri` is empty. The one file under
`src/` that changed is `src/generated/uri-scanner.sls`, which #55's `make parser-refresh`
rewrote at the new pin: 7 self-advancing transitions became loops, through 4 byte tables.
Its export, `uri-scanner-machine`, and its ABI, 9, are unchanged. The complete selection is
still 91 lanes. `CMakeLists.txt` declares `VERSION 0.8.0`, and `Akku.manifest` names
`chez-uri` `0.8.0`, depending on byte-machine `^0.9.0`.

Akku reads a caret range on 0.x by its minor: `^0.8.0` is `>=0.8.0 <0.9.0`. So chez-uri
0.8.0, the version on the index, can't be installed beside jsonparse or chez-httparse, which
now need byte-machine 0.9. byte-machine 0.9.0 is on the Akku index (listed 2026-11-10), and
its archive's 215 files match tag `v0.9.0` byte for byte.

CI passed on each pull request's merged head, on linux-amd64 (ubuntu-24.04, Chez 10.4.1
ta6le, CMake 3.31.6), with pr 91/91, release 91/91 and no-scheme 13/13, read from each
run's log: #53 in run 40099620952, #54 in 40111534872, #55 in 42731219525. It passed on
main at af64f39, this release's base, too (run 42731710645). #55 was also measured on macOS
arm64: test-all 91/91, no-scheme 13/13.

## Decision

1. **The bump is MINOR, 0.8.0 → 0.9.0,** for 0046 item 1's reason. No library changed, so
   the code alone would allow a patch. The dependency does not: the vendored byte-machine
   crossed a 0.x minor, and `^0.9.0` admits no 0.8.x. `CMakeLists.txt` `VERSION` and the
   manifest's version move to `0.9.0`. A search found no other version surface: every file
   git tracks outside `vendor/`, grepped for `0.8.0`, `v0.8`, `^0.8` and `0.9`. `docs/` and
   README.org name no version. The `(uri …)` libraries stay unversioned. The tag is
   annotated `v0.9.0` on the squash-merged release commit; signing follows `tag.gpgSign`.

2. **`CHANGELOG.md`: `[Unreleased]` becomes `[0.9.0] - 2026-11-11`,** with a preamble
   giving the evidence basis and a fresh `[Unreleased]`. Its entries were reread together,
   as the ledger's v0.8.0 close-out asks, and none is stale at the tag, so none changes.
   "chez-uri 0.8.0 is on the Akku index" stays true: publishing 0.9.0 leaves 0.8.0 there.
   The frozen entries are untouched.

3. **No new conformance claim.** Parsing and validation are exactly v0.8.0's, and the
   scoped claim reads as before.

4. **The evidence is disclosed.** The CHANGELOG preamble names each pull request's CI run
   and the release gate. The tag message adds the release pull request's own CI run.

5. **The release gate is a fresh measurement on the release tree,** on Linux amd64 (Chez
   10.4.1 ta6le from jsonparse's pinned Guix; CMake/CTest 4.1.3). Before its commit:
   - `make test-all`: 91/91;
   - `make no-scheme`: 13/13;
   - `make check-help`: green;
   - `make check-site` with chez-cmark-gfm 2.0.0 and `SITE_REF=v0.9.0`: site 49/49, render
     9/9, the four invariants green;
   - `make check-akku`, by hand, with Akku 1.2.0: chez-uri 0.9.0 and byte-machine
     installed, the 15 libraries in `src/` landed, and the consumer read a URI through both
     layers.

   The squash merge is pinned with `--match-head-commit`, and the merged tree hash is
   compared with the tested one before tagging.

6. **The publish steps are the maintainer's, each asked for first,** as in 0046 item 6.
   1. The release PR's squash merge, as the closing ritual (AGENTS.md).
   2. The signed tag `v0.9.0` and its push. The push runs `pages.yml`, which publishes the
      site with `SITE_REF=v0.9.0`.
   3. A GitHub Release whose body is the CHANGELOG's `[0.9.0]` section.
   4. `akku publish` from the tag (0045 step 3), as for v0.8.0. It needs the maintainer's
      GPG key.

## Consequences

- Once 0.9.0 is on the index, an application can install chez-uri beside jsonparse or
  chez-httparse. chez-http-server's own move to byte-machine 0.9 waits for it.
- chez-uri 0.8.0 stays on the index, for programs that still pin byte-machine 0.8.
- `make check-akku` does not wait on the index. It writes an `Akku.lock` that points each
  package at a copy of its tracked files, byte-machine's from `vendor/`, and a bare
  `akku install` installs from the lock; only `akku lock` reads the index. What the index
  serves is checked apart from it: byte-machine 0.9.0's archive against its tag, before
  this release, and chez-uri 0.9.0 by an install in a throwaway project once it is listed,
  as for 0.8.0.
- What reopens next is unchanged from 0046:
  - akku in CI, so `check-akku` stops being a manual gate;
  - building URIs from parts;
  - a host-kind accessor;
  - a ranged `(uri query)`, if a server measures the need.
