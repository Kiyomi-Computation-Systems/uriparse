# 0045: chez-uri ships on Akku as exactly the libraries in src/, after byte-machine is on the index

Date: 2026-10-11
Status: accepted
References:
[0043](0043-v07-releases-as-annotated-tag-and-adds-the-easy-layer.md) (the release record a
publishing release extends),
[0044](0044-the-docs-are-markdown-checked-against-the-code-and-published-by-chez-cmark-gfm.md)
(the docs site, whose `site/` libraries the package must leave out).

## Context

chez-cmark-gfm 2.0.0 is on the Akku index: `akku install chez-cmark-gfm` fetches
`chez-cmark-gfm_2.0.0_repack.tar.xz`, built from the public repository at tag `v2.0.0`.
chez-uri is to be released the same way. chez-httparse and byte-machine already carry an
`Akku.manifest`, unreleased; chez-httparse's `make check-akku` and its manifest lane are
the shape this record copies.

What `akku publish` does, read from akku 1.1.1-beta.0's `lib/publish.scm`:

- it reads `Akku.manifest` from the working tree, and turns the `origin` remote into a public
  `https://` URL (`git@github.com:` included);
- it names the commit of tag `v<version>`, or HEAD with a warning when there is no such tag;
- it writes `<name>_<version>.akku`, asks y/N, signs the file with the publisher's own GPG
  key (`gpg --sign --detach`), and uploads both to `archive.akkuscm.org/archive/packages/`.

The archive then builds the tarball from that commit of the repository. So the repository
must be clonable by the archive, which means public, and a submodule arrives empty, so a
dependency must come from the index. On 2026-10-11 uriparse and byte-machine are both
private, and byte-machine is not on the index.

## Decision

1. **The package is `chez-uri`**, the CMake project's name, beside chez-cmark-gfm and
   chez-httparse. The homepage is the uriparse repository.
2. **It installs exactly the `.sls` files git tracks under `src/`**: the 14 `(uri …)`
   libraries and `(generated uri-scanner)`, plus `LICENSE` and `NOTICE`. Akku leaves out
   `test/` as test code and installs programs only from `bin/`, `demos/` or `programs/`, so
   `tools/emit-machine.ss` and a top-level `build-site.sps` stay out without help. No
   library on the index is named `(uri …)` or `(generated …)` today; the `uri` libraries
   it lists are `(chibi uri)`, `(coap uri)`, `(ocelotl net uri)`,
   `(riastradh schemantic-web uri)` and `(slib uri)`.
3. **It depends on `("byte-machine" "^X.Y.Z")`, where X.Y.Z is the vendored copy's latest
   release.** The scanner imports `(byte-machine runtime)` and `(uri grammar)` imports
   `(byte-machine graph)`. A consumer then resolves no byte-machine older than the one the
   suite ran against. There is no `depends/dev`, because the suite runs through CMake
   against the submodule.
4. **The manifest's version is the latest release in `CHANGELOG.md`.** A release moves both.
5. **No `scripts` clause and no `Akku.lock`.** There is nothing to build. A library package
   leaves locking to its consumers, and `akku lock` cannot resolve byte-machine anyway until
   it is on the index.
6. **The order is fixed by item 3 and the Context.** The steps are:
   1. byte-machine goes public, is tagged, and is published.
   2. uriparse's submodule moves to that byte-machine release, so the floor names a version
      the index has.
   3. uriparse goes public, its release is tagged, and `akku publish` runs from the tag.
   The publish is the maintainer's: it needs their GPG key, and the archive has to accept
   the upload.

Two checks hold this:

- `uri.docs.akku-manifest` (source and aot, layer `docs`, in the pr selection) holds items 3
  and 4 against `CHANGELOG.md` and `vendor/byte-machine/CHANGELOG.md`, and refuses a manifest
  with no dependency.
- `make check-akku` installs the package with Akku into a throwaway project. The lock points
  each package at a copy of its git-tracked files. The check asserts item 2 exactly, then
  runs `test/akku/consumer.sps` with only Akku's library path. It is a target, not a lane,
  because it needs akku.

Witnessed on 2026-10-11, with akku 1.1.1-beta.0 and Chez 10.4.1:

- **The lane:** all five manifest mutations failed it, each with its own diagnostic. The five
  were a version the changelog has not released, a floor below the vendored version, a range
  that is not caret, no `depends`, and a dependency nothing vendors.
- **`check-akku` failed on four changes, each with its own message:** a tracked `site/*.sls`
  library, a program under `programs/`, a `src/` library left uninstalled, and a manifest
  with no dependency (the consumer fails at import). It also failed on a consumer printing
  something else.
- **It passed on the two changes that should pass:** `.akkuignore` listing `site`, and a
  top-level `build-site.sps`.
- Seven cases were entered and seven verdicts returned.

## Consequences

- **`.akkuignore` matches basenames, at any depth, never paths.** `find-artifacts*` in
  `lib/repo-scanner.scm` tests `(member fn ignored-files)` against each file's or directory's
  own name, at every level. So `site` (PR #44) leaves out every directory named `site`,
  `test/site/` included, and a line like `src/uri/query.sls` matches nothing. A future
  exclusion has to be a name that occurs nowhere else in the tree.
- **No CI run proves `check-akku`.** CI installs no akku. Until it does, `make check-akku`
  runs by hand before a release tag, and the release record says it ran. chez-cmark-gfm's
  `akku-install` job, which installs the akku 1.1.0 release tarball by sha256, is the shape
  to copy when CI is funded.
- **Until step 1 lands, nothing here is installable through Akku**, and the docs must not
  claim it is (`akku install` from a clone needs `akku lock`, which needs byte-machine on the
  index). The README names only the manifest and `make check-akku`.
- These findings are pinned to akku 1.1.1-beta.0 as installed on the development machine. A
  later reader relying on them should re-read `lib/publish.scm` and `lib/repo-scanner.scm`
  rather than trust the citations above.
