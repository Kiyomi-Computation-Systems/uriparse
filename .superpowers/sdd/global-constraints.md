## Global Constraints

Every task brief in this milestone is bound by the following. They are the house
rules the sibling projects (`chez-httparse`, `byte-machine`) enforce, restated in
chez-uri's own spellings and measured on chez-uri's own tree.

- Toolchain floors: CMake 3.26 declared (preset schema v6 + margin; 4.3.3 is
  what has actually run here), Chez Scheme 10.4.1 (the full system, not Petite;
  the ahead-of-time lane needs `compile-program`). Discovery tries `scheme`,
  `chez`, `chezscheme` and rejects Petite and anything older.
- Exit-status vocabulary for Scheme lanes: 0 pass, 1 assertion failure(s),
  2 harness/configuration/registration error (includes empty selection and
  launcher refusals), 3 provenance failure. `URI_EXIT_STATUS_VOCABULARY` is the
  single source of what an exact-exit registration may assert.
- Launcher diagnostics: refusals exit 2 with prefix `uri-launcher:`
  (`uri-fingerprint:` for the manifest launcher); harness output lines carry
  `uri-harness:`.
- Measured baseline (2026-09-18, Darwin arm64, Chez 10.4.1 machine-type
  tarm64osx, CMake/CTest 4.3.3): release preset 38/38; no-scheme preset 10/10;
  fingerprint sample bytes `chez-uri\n`. Every count that enters a record is
  re-measured on this tree at the time of writing, dated and platform-stamped;
  do not carry these numbers forward by arithmetic.
- Mutation-signature rule: EXPECT_STATUS/EXPECT_OUTPUT_MATCHES only where the
  status/output was measured; EXPECT_SURVIVES only with a written reason the
  suite re-prints; an uncaught mutation strengthens a test, never loosens it.
  Assert the edit landed before reading its result, and read the failure, not
  the exit status: a mutation refused at verification is a structural guarantee,
  not a test witness.
- Empty selection is failure at every layer: test presets keep
  `noTestsAction: error`, the Makefile keeps `--no-tests=error`, the mutation
  engine refuses an empty suite or stage, the Scheme harness exits 2 on an
  empty selection.
- Conventional Commits. Run the suite before every commit; fix failures first.
- `src/` imports `(rnrs)`, `(byte-machine ...)` and this project's own libraries
  and nothing else (decision 0007), asserted by the import-audit lane rather
  than trusted. Chez is confined to the harness, the emitter, any bench runner
  and the CMake probe, and is imported narrowly where it appears.
- Every `.sls` and `.sps` carries a `#!r6rs` line (design §8): Racket needs it,
  Chez and Guile accept it, and byte-machine v0.6.0 emits it.
- No new dependencies. The `byte-machine` generator arrives only as the pinned
  submodule decision 0002 describes, at a release tag by gitlink, in the first
  slice that actually invokes the emitter — a pin nothing exercises only rots.
  When the pin moves it moves alone (decision 0002 item 6).
- The seam type distinguishes **absent from empty**: a `uri-components` field is
  a bytevector *or* `#f`; `#f` is absent, a zero-length bytevector is present and
  empty (design §2, §3.2; decision 0008). This is carried by whether a span's
  callbacks fire at all, not by a presence flag.
- The rename-audit lane fails the build if anything under `cmake/`, `test/` or
  `.github/` names a project this repo does not depend on. chez-uri depends on
  `byte-machine` and on nothing from `chez-httparse` (the source it was copied
  from), so a copied file must be renamed. Legitimate `byte-machine` references
  become allowlisted forms only where the submodule requires them — the audit's
  question is "does every occurrence match a declared legitimate form", not
  "does the token occur" (sibling decision 0011's shape).
