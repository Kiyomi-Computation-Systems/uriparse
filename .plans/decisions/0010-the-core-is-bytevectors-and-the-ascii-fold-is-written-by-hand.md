# 0010: the core is bytevectors, and the ASCII fold is written by hand

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §5

## Context

The core — percent coding, §6 normalization, §5.2.4 `remove_dot_segments`, §5.2
resolution, §5.3 recomposition — is pure functions over immutable inputs. What
those inputs *are* is a real fork, and it decides how close the Unicode
machinery sits to the normalization code.

RFC 3986 §6.2.2.1 normalizes scheme and host case, and it means **ASCII case
only**. R6RS's `string-downcase` lives in `(rnrs unicode)` and performs full
Unicode case folding, which is wrong here and length-changing in general:
U+0130 lowercases to two code points, and **U+212A (KELVIN SIGN) lowercases to
ASCII `k`**, so a host containing it would compare equal to one that does not.
That is a correctness bug and a portability bug at once, and it is among the most
likely places for two implementations to disagree.

## Decision

1. **Bytevectors throughout the core.** A URI is a byte string: `%C3%A9` is two
   bytes, not one character, and percent coding is defined on octets. Staying in
   bytevectors makes `(rnrs unicode)` structurally unreachable from the
   normalization code rather than merely discouraged there.

2. **`utf8->string` appears once, at the edge, as a convenience** — never inside
   a core function, never in a comparison, never before a fold.

3. **No string-level convenience layer in v0.1.** It is the most usable option
   and it is two surfaces to keep in agreement, where the second is the one no
   vector exercises. This is `chez-httparse` decision 0021 item 3's objection,
   which applies unchanged.

4. **The ASCII case fold is written by hand, in `(uri normalize)`.** Bytes
   `#x41`–`#x5A` map to `#x61`–`#x7A`; every other byte is returned unchanged.
   Nothing else.

5. **It is tested against an input that proves it did nothing.** A host
   containing the UTF-8 encoding of U+212A must survive the fold byte-identical,
   and a test asserting that must be watched failing against a
   `string-downcase`-based implementation before it is believed. A test that
   passes whether the code is right or wrong is worse than no test.

6. **`(uri vocabulary)` imports nothing.** Span, callback and error names and
   the mode integers live there, and three parties must agree on them: the
   grammar that declares them, the harness that binds them per fixture, and an
   embedder writing callback bindings. A pure table is also what an embedder can
   import without dragging the builder and verifier in behind it — `chez-httparse`
   decision 0021 item 4's argument for `(httparse modes)`.
