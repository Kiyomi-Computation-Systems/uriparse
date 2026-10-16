# 0046: v0.8 releases as the annotated tag v0.8.0, the first public release, with no library change

Date: 2026-10-16
Status: accepted
References:
[0043](0043-v07-releases-as-annotated-tag-and-adds-the-easy-layer.md) (the release checklist
this follows),
[0044](0044-the-docs-are-markdown-checked-against-the-code-and-published-by-chez-cmark-gfm.md)
(the docs and the site),
[0045](0045-chez-uri-ships-on-akku-as-exactly-src-after-byte-machine.md) (the Akku order, whose
step 3 this release opens),
[0030](0030-the-rfc-3986-conformance-audit-is-clean-recognition-equivalence-is-earned.md)
(the validation claim every release since v0.3 carries unchanged).

## Context

The arc since v0.7.0 (tag on daf7be0) is ten merged pull requests:
- #42 and #43, the doc-examples lane: every documented example runs, and a doc the lane
  cannot read fails it;
- #44, user guides in Markdown, a checked API reference, and the docs site;
- #45 and #46, the Akku manifest and `make check-akku`, then its GNU `tar` fix;
- #47, the byte-machine pin to v0.8.0, its first public release;
- #48, CI fetching byte-machine without a token;
- #49, the design records left out of what is distributed;
- #50 and #51, the site's top bar, a theme toggle that survives refused storage, and a
  check-site failure on root-relative links.

Nothing under `src/` changed: `git diff v0.7.0 -- src/` is empty, and #47's
`make parser-refresh` at the new pin rewrote the scanner byte-identical. The complete
selection grew from 85 lanes to 91: `uri.example.docs`, `uri.docs.akku-manifest` and
`uri.example.api-reference`, each in source and AOT. `CMakeLists.txt` declares
`VERSION 0.7.0`, and `Akku.manifest` names `chez-uri` `0.7.0`.

byte-machine is public, and 0.8.0 is on the Akku index. uriparse is public, and CI runs
again: #50 and #51 passed on linux-amd64. #42 to #49 merged earlier, each refused CI over
billing, on macOS arm64 evidence.

## Decision

1. **The bump is MINOR, 0.7.0 → 0.8.0.** No library changed, so the code alone would
   allow a patch. The dependency does not: the vendored byte-machine moved across a 0.x
   minor, and the package's `^0.8.0` floor admits no 0.7.x, so a program that also uses
   byte-machine has to move with it. It is also the first public release and the first
   on Akku. `CMakeLists.txt` `VERSION` and the manifest's version move to `0.8.0`. The
   `(uri …)` libraries stay unversioned. The tag is annotated `v0.8.0` on the
   squash-merged release commit; signing follows `tag.gpgSign`.

2. **`CHANGELOG.md`: `[Unreleased]` becomes `[0.8.0] - 2026-10-16`,** with a preamble
   giving the evidence basis and a fresh `[Unreleased]`. Four lines the release made
   stale are corrected:
   - the Akku entry's `^0.7.0` floor;
   - its "nothing is published yet";
   - the doc lane's `docs/*.org`, since the guides are Markdown now;
   - the pin entry's account of the floor.

   The site entry gains its URL. The frozen entries are untouched.

3. **No new conformance claim.** Parsing and validation are exactly v0.7.0's, and the
   scoped claim reads as before.

4. **The evidence is disclosed.** The CHANGELOG preamble names the CI runs and the PRs
   that had none. The tag message adds the release pull request's own CI run.

5. **The release gate is a fresh measurement on the release tree.** Before its commit:
   - `make test-all` (the complete selection);
   - `make no-scheme`;
   - `make check-site` with chez-cmark-gfm 2.0.0;
   - `make check-akku`, by hand, since CI installs no akku (0045).

   The squash merge is pinned with `--match-head-commit`, and the merged tree hash is
   compared with the tested one before tagging.

6. **The publish steps are the maintainer's, each asked for first.**
   1. The release PR's squash merge, as the closing ritual (AGENTS.md).
   2. The signed tag `v0.8.0` and its push. The push runs `pages.yml`, which publishes the
      site with `SITE_REF=v0.8.0`, so its `../` links name the tag's files.
   3. A GitHub Release whose body is the CHANGELOG's `[0.8.0]` section.
   4. `akku publish` from the tag (0045 step 3). It needs the maintainer's GPG key.

## Consequences

- chez-http-server and chez-httparse are unaffected: no library changed.
- Until the publish lands, the docs do not offer `akku install chez-uri` (0045: they must
  not claim what the index does not have). Once it lands, `docs/installing.md` gains an
  Akku path, in a pull request of its own.
- What reopens next is a separate choice. The candidates are:
  - akku in CI, so `check-akku` stops being a manual gate;
  - building URIs from parts;
  - a host-kind accessor;
  - a ranged `(uri query)`, if a server measures the need.
