# Contributing to uriparse

Thanks for helping. A **small fix**, such as a typo, a doc fix, or a bug with a
test that shows it, needs only the checks below. **Bigger work**, such as a new
export, a change to the grammar, or a change to which URIs the parser accepts
or refuses, starts as an issue, so the design is agreed before the code is
written. [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986) is the judge: what
it allows is what this parser accepts, so changing that is a design decision,
not a fix.

## Setup

You need Chez Scheme 10.4.1 or newer, the full system rather than Petite, and
CMake 3.26 or newer. The Developing section of [README.org](README.org) has the
rest.

```sh
git clone --recursive https://github.com/Kiyomi-Computation-Systems/uriparse.git
cd uriparse
make test
```

`make help` lists every target. A clone without `--recursive` needs
`git submodule update --init` for byte-machine at `vendor/byte-machine`.

## The checks

CI runs these on every pull request, on Linux. Keep them green:

- `make test`: the pull-request selection passes. It also runs every example
  in `README.org` and `docs/`, checks `docs/reference.md` against the real
  exports, and checks `Akku.manifest` against `CHANGELOG.md` and the pin.
- `make test-all`: every test.
- `make no-scheme`: the build's own CMake checks, with no Scheme installed.
- `make check-help`: every target has a description in `make help`.

Two more run where their tools are installed. CI doesn't run them on pull
requests:

- `make check-site CMARK_GFM_ROOT=/path/to/chez-cmark-gfm`: the docs site
  builds, and every link and anchor in it resolves. It also runs before each
  release tag publishes the site.
- `make check-akku`: installs the package with Akku as a user would, and
  checks that only the libraries in `src/` land. It needs `akku`.

## When you change…

- **The grammar** (`src/uri/grammar.sls`): run `make parser-refresh` and
  commit what it writes to `src/generated/uri-scanner.sls`. The
  `uri.determinism.generated-artifact` lane fails until you do.
- **The `vendor/byte-machine` pin:** move it on a commit of its own, with
  the regenerated scanner (`make parser-refresh`) and `Akku.manifest`'s range
  for it. The `uri.docs.akku-manifest` lane fails until the range's floor is
  the pinned version.
- **The RFC 3986 corpus:** `test/conformance/rfc3986/` is extracted from the
  RFC text in `test/vendor/`, and neither is edited by hand. After changing
  the extractor (`cmake/UriCorpus.cmake`), run `make corpus-refresh`; the
  `uri.harness.corpus-provenance` lane fails until you do. Name any new
  third-party code or test data, and its license, in NOTICE.
- **An export:** document it in `docs/reference.md`. The
  `uri.example.api-reference` lane fails until the reference lists exactly
  what each library under `src/` exports.
- **A doc example:** every Scheme example in `README.org` and `docs/` runs. A
  program must print the output shown after it (a `text` block in Markdown,
  `#+begin_example` in Org), and an expression must give the value on its
  `;; =>` line. The `uri.example.docs` lane fails otherwise.
- **The Makefile:** give each new target a `## ` description, so `make help`
  lists it. `make check-help` fails until it has one.
- **`docs/`:** it is for people using the library. Keep it short and plain. A
  new page goes in `docs/` and in `site/pages.sls`, the nav's order;
  `make check-site` fails until both name it.
- **What ships:** a release archive and the Akku package are `git archive`
  of the tag. A new top-level path that is only for development needs an
  `export-ignore` rule in `.gitattributes`. `.akkuignore` keeps directories off
  a user's library path, by name at any depth. `make check-akku` checks both.

## Code

- Libraries are R6RS `.sls` files under `src/`, and each holds its own code:
  no shared include files.
- **Functional core, imperative shell.** The libraries under `src/` are pure
  and import only `(rnrs)`, byte-machine's libraries and each other, never
  `(chezscheme)`. Chez-specific code stays in the build and the tests. The
  `uri.harness.import-audit` lane fails when a library names `(chezscheme)`
  or doesn't start with `#!r6rs`.
- Each export has a comment giving its type, Typed Racket style:
  `;; uri-host : Uri -> (Option String)`.
- R6RS forbids assigning an exported variable, so reach mutable state through
  procedures.
- The library runs on macOS, Linux and Windows, on x86-64 and arm64. CI runs
  Linux only, so say in the pull request where you tested.
- Comments and docs say what the code does and why, in the present tense.
  They don't cite issues, pull requests, plans or dates; that history belongs
  in commits and CHANGELOG.md.

## Tests

- Write the test first, and watch it fail before you make it pass. A test
  that passes whether the code is right or wrong is worse than none.
- A change in behavior comes with a test that fails without it.
- An expected value comes from RFC 3986, from its examples or from an
  independent oracle in `test/support/harness/uri/test/`, never from a run of
  this parser. A value read off the code under test keeps passing after
  the code is wrong.
- A lane is a program in `test/common/` using `(uri test harness)`,
  registered with `uri_add_scheme_lane` in `test/CMakeLists.txt`, in source
  and AOT modes. Its `SOURCES` list every library it loads.
  `ctest --preset pr -R <name>` runs the lanes whose names match, after
  `make build`.
- Test what the code does, never what a comment says.

## Pull requests

- Commit messages and PR titles follow
  [Conventional Commits](https://www.conventionalcommits.org): `feat:`,
  `fix:`, `docs:`, `test:`, `refactor:`, `chore:`.
- Name branches `feat/<slug>`, `fix/<slug>`, `docs/<slug>` and so on.
- Pull requests are squash-merged, so the PR title becomes the commit's.
- A change users can see gets an entry under `## [Unreleased]` in
  [CHANGELOG.md](CHANGELOG.md).

## How the project is developed

Feature work starts as a plan in `.plans/`, and each lasting decision gets a
numbered record in `.plans/decisions/`. `.superpowers/sdd/progress.md` is the
development ledger. [AGENTS.md](AGENTS.md) holds the project's rules in full.
Following them is encouraged for features, not demanded of small fixes. None
of these is in a release archive; read them in the repository.

## Security

Don't open a public issue for a suspected vulnerability.
[SECURITY.md](SECURITY.md) says how to report it privately.
