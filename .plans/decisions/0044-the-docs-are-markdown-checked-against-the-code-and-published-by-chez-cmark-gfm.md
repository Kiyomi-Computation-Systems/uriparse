# 0044: the docs are Markdown, checked against the code, and published by chez-cmark-gfm

Date: 2026-10-11
Status: accepted
References:
[0007](0007-src-is-pure-r6rs-and-chez-is-confined.md) (Chez stays out of src/),
[0040](0040-the-easy-layer-is-strings-at-the-edge-one-record-and-a-validated-domain.md),
[0043](0043-v07-releases-as-annotated-tag-and-adds-the-easy-layer.md) (the
example checker as next work)

## Context

Until now the user docs were `README.org` and one guide, `docs/easy.org`. The
byte layer was documented only by its source comments and the README's task
table. The maintainer asked for user docs in the style of the siblings'
(chez-cmark-gfm, cl-commonmark-gfm): short ELI5 guides, an index in
`docs/README.md`, an API reference, and a GitHub Pages site built with
chez-cmark-gfm's own generator.

Three questions follow, and each has an answer that rots quietly:

- **Format.** chez-cmark-gfm renders Markdown, and GitHub shows `docs/README.md`
  as the folder's index. Org would need a second renderer.
- **Truth.** A guide's examples and a reference's entries are claims about the
  code. Written once and never run, they drift: a renamed export leaves a
  reference entry for a binding that is gone, and nothing fails.
- **The renderer.** chez-cmark-gfm is a binding to the C library cmark-gfm. It
  must not become a dependency of a portable R6RS library, or reach anyone who
  clones uriparse to use it.

## Decision

1. **The guides are Markdown in `docs/`, one page per part of the library,
   with `docs/README.md` as the index.** `docs/easy.org` becomes
   `docs/easy.md`; `README.org` stays org (the maintainer's preference for
   READMEs) and links into `docs/`.

2. **Every example runs.** The `uri.example.docs` lane (#42, #43) reads
   Markdown as well as org: ```scheme fences are Scheme, ```text fences are a
   program's printed output. Expressions may call any of the twelve `(uri ...)`
   libraries a guide documents, and a program may define after an expression,
   as a top-level program can. The checker is graded on Markdown twins of every
   wrong doc, each of which must give one difference that names its fault.

3. **The reference is checked against the exports.** `docs/reference.md` uses
   chez-cmark-gfm's narrow authoring convention: a `## Modules` table, and one
   `### \`name\` (kind)` entry per binding with a body and an
   `**Available from:**` line. A new lane, `uri.example.api-reference`, reads
   every `src/*/*.sls` export form as data and fails on a missing, extra,
   duplicated or empty entry, a wrong `Available from`, or a module-table
   mismatch. Every library under `src/` is documented, the generated scanner,
   the grammar and `(uri range)` included, so there is no exemption list to
   keep true. The checker, chez-cmark-gfm's `(site reference)` with a
   `constant` kind added, lives in the harness as `(uri test api-reference)`.

4. **The site is chez-cmark-gfm's generator, copied, and run on a checkout
   named by `CMARK_GFM_ROOT`.** `site/` and `build-site.sps` come from
   byte-machine's port (chez-httparse's, with `docs/README.md` as the home
   page), `test/site/` holds its suites over this harness, and `make site` /
   `make check-site` run Chez directly. chez-cmark-gfm is not a submodule and
   is not fetched by the build: a consumer's `--recurse-submodules` clone never
   sees it. The Pages workflow checks it out at v2.0.0 by commit
   (`3c848281`), installs a distribution Chez and `cmark-gfm`, gates on
   `make check-site`, and deploys on a `v*` tag.

## Consequences

- `make test` now fails when a guide's example stops printing what it says,
  and when an export and the reference disagree. The complete selection gains
  two lanes in two modes.
- `make check-site` is not in `make test`: it needs chez-cmark-gfm and the C
  library. It runs in the Pages workflow and by hand.
- `site/` holds `.sls` files that are not part of the library. A top-level
  `.akkuignore` lists it, so an Akku package of uriparse (in progress, decision
  0045) installs `src/` alone, as chez-httparse's does.
- The site build is distribution-Chez-safe: rehearsed on `ubuntu:24.04`
  (amd64, Chez 9.5.8, cmark-gfm 0.29.0.gfm.6), both gates green and all nine
  pages written.
- Publishing needs the maintainer: Pages must be enabled with "GitHub Actions"
  as its source, and while the repository is private that needs a paid plan.
  Like ci.yml, the workflow cannot run until Actions billing is restored.
- The docs claim nothing about `unexpected-eof` that they cannot show: no URI
  input was found that reaches it, so `docs/errors.md` says the other codes
  are what you meet.
