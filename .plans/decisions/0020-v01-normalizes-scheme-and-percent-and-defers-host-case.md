# 0020: v0.1 normalizes scheme case and percent-encoding, and defers host case

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §5 (the core), §6 (v0.1 is
resolution-first)
References:
[0010](0010-the-core-is-bytevectors-and-the-ascii-fold-is-written-by-hand.md)
(bytevectors throughout; the ASCII fold is hand-written),
[0011](0011-v01-is-resolution-first.md) (v0.1 is a splitter with a complete core,
not a validator; the host grammar M4 is v0.2),
[0019](0019-the-scanner-splits-five-coarse-components-and-the-core-owns-the-authority.md)
(the authority is one opaque bytevector until the core sub-parses it)

## Context

M5 builds `(uri normalize)` on top of `(uri collect)`'s five-field
`uri-components`, and RFC 3986 §6.2.2 syntax-based normalization has three
*scheme-independent* transforms:

1. §6.2.2.1a — the **scheme** (and host) is case-insensitive → lowercase.
2. §6.2.2.1b — the two hex digits of every `pct-encoded` triplet → uppercase.
3. §6.2.2.2 — decode a `%XX` **iff** its octet is unreserved (§2.3).

Two of the three are unobstructed here. But §6.2.2.1a names the scheme **and the
host**, and in this milestone's seam the authority is a single opaque bytevector
`[ userinfo "@" ] host [ ":" port ]` — the scanner emits it coarse and the core
does not sub-parse it (decision 0019), and the host grammar is M4, deferred to
v0.2 (decision 0011). So the host cannot be isolated, and §6.2.2.1a's *host*-case
rule has no honest implementation at M5. The maintainer chose M5 at the milestone
gate and directed that this deferral be documented rather than faked or
front-loaded into M4.

## Decision

1. **v0.1 `(uri normalize)` applies exactly these §6.2.2 transforms:**
   - §6.2.2.1a **scheme case → lowercase**, a hand-written ASCII `A`–`Z`→`a`–`z`
     fold (the scheme is a leaf ASCII token, `ALPHA *( ALPHA / DIGIT / "+" / "-"
     / "." )`, §3.1).
   - §6.2.2.1b **hex digits of every valid `%XX` → uppercase**.
   - §6.2.2.2 **decode `%XX` whose octet is unreserved** (§2.3), and only those;
     every other triplet stays encoded with its hex uppercased.

   Applied per component to what each admits: the **scheme** gets the case fold
   only (the scheme production carries no `pct-encoded`); **authority, path,
   query, fragment** get percent-normalization (unreserved-decoding is
   position-independent, so normalizing the whole authority bytevector is correct
   for userinfo, host and port alike); an **absent (`#f`) field stays absent**,
   an empty field stays empty.

2. **Host case is DEFERRED to the host grammar (M4/v0.2).** §6.2.2.1a lowercases
   the scheme *and* the host, but host-lowercasing requires isolating the host,
   and `userinfo` is case-**sensitive** — §6.2.2.1 names only scheme and host, not
   userinfo. Lowercasing the whole authority would corrupt it:

   ```
   input authority:  User:S3cret@Example.COM
   correct:          User:S3cret@example.com   (only the host lowercased)
   whole-string:     user:s3cret@example.com   (userinfo case destroyed)
   ```

   Preserving authority case until the host is sub-parsed is *conservative and
   standards-compliant*: it never produces a wrong answer, it only postpones an
   optional false-negative reduction. When M4's host split lands, host-case is the
   **same** ASCII fold applied to the isolated host — no rework, just a newly
   reachable component.

3. **Out of scope, named so a reader is not misled:**
   - §6.2.2.3 = §5.2.4 **dot-segment removal** — M6, the resolution milestone,
     gated on the §5.4 corpus (decision 0011). A v0.1 normalizer does **not**
     collapse `/./` or `/../`.
   - §6.2.3 **scheme-based normalization** (default-port elision, empty-path→`/`,
     empty-`:port` elision) — requires knowing a scheme's defaults; a *generic*
     normalizer must not apply it.
   - §6.2.4 **protocol-based normalization** — depends on live protocol behaviour;
     out of scope entirely.

4. **The honesty obligation.** Because v0.1 performs two of §6.2.2.1's transforms
   and not the third, it must not present itself as a full §6.2.2.1 normalizer.
   `normalize-components` is documented as *scheme case + percent normalization;
   host case deferred*, and `README.org`'s "will not claim" list carries the
   host-case caveat beside decision 0011's "not RFC 3986 compliant". A caller must
   not assume `HTTP://EXAMPLE.COM` normalizes equal to `http://example.com`
   (scheme yes, host no). This is the parser-differential class the brief's
   standing risks warn of; the mitigation is that the gap is **named, not
   silent** — and a test pins host case as *preserved*, so a later change that
   started lowercasing the authority without the M4 split would redden rather than
   ship.

5. **Total, over bytevectors (decision 0010).** `normalize` never rejects (v0.1 is
   non-validating, decision 0011): a malformed `%XX` is left byte-for-byte, as in
   `(uri percent)`. No `(rnrs unicode)` — the scheme fold is a hand-written ASCII
   map, because Unicode folding is length-changing and would fold e.g. U+212A
   KELVIN SIGN to ASCII `k`, making a host that contains it compare equal to one
   that does not.

## Consequences

- `(uri normalize)` exports `normalize-scheme`, `pct-normalize` and
  `normalize-components`; it imports `(uri percent)` (the hex primitives and
  `unreserved-byte?`) and `(uri components)` (the seam type). It re-uses percent's
  mechanics rather than re-deriving the hex or the unreserved test.
- Host case is the **only** §6.2.2.1 transform not performed at v0.1; M4 closes it
  with no change to this library's shape.
- The §6.2.2 worked example — `example://a/b/c/%7Bfoo%7D` ≡
  `eXAMPLE://a/./b/../b/%63/%7bfoo%7d` — normalizes correctly under M5 **except**
  the two dot-segment differences, which are M6. The `(uri normalize)` test
  asserts the M5 portion (scheme-case, `%63`→`c`, `%7b`/`%7d`→`%7B`/`%7D`) and
  leaves the dot-segments for the resolution milestone.

- **Normalization CREATES dot-segments; M6 must resolve AFTER it (a note for the
  resolution milestone).** §6.2.2.2 decodes the unreserved marks, and `.` (`%2E`)
  is a mark, so `pct-normalize` maps `/a/%2E%2E/b` to `/a/../b` — M5 does not
  *remove* dot-segments (§6.2.2.3/§5.2.4 is M6) but it does *manufacture* them
  from encoded input. That makes the order load-bearing and security-relevant:
  §5.2.4 `remove_dot_segments` acts only on **literal** `.`/`..`, so it must
  consume an M5-normalized path. Normalize-then-resolve and resolve-then-normalize
  **differ** for encoded-dot inputs — resolving RAW components would let encoded
  traversal (`%2E%2E%2F`) survive as a live `../`. Therefore M6 resolves
  normalized paths, never raw ones; `(uri normalize)`'s tests pin `pct-normalize`
  producing `/a/../b` from `/a/%2E%2E/b`, so the boundary is visible in the suite
  rather than only here.
