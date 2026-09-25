# 0034: validate-component judges a range, so a span is validated in place

Date: 2026-09-24
Status: accepted
Plan: GitHub issue #21 (chez-http-server M2.3 keeps the request-target as a span
`[start, end)` of the socket's buffer and judges origin-form's path and query with
`validate-component`, which takes only a whole bytevector, so the span must be copied
first). Additive, pure Scheme.
References:
[0024](0024-charset-validation-is-the-cores-over-the-split-components.md) (the M3
component validator this extends, and its component-relative index),
[0032](0032-validation-composes-over-a-parse-result-so-a-reused-collector-can-be-validated.md)
(the previous sibling ask on the validation surface, and the deferral/doc precedent
followed here).

## Context

`validate-component : Symbol Bytevector -> (values (Option Symbol) (Option Nat))` judged a
whole bytevector: `validate-scheme` and `validate-content` looped from 0 to
`(bytevector-length bv)`, and the pct-encoded guard was bounded by the same length. There
was no way to judge `[start, end)` of a larger bytevector without copying it out.

A server cannot use the collector for origin-form. RFC 9112 §3.2.1's absolute-path is
`1*( "/" segment )`, but a collector parse reads a leading `//` as an authority, as RFC
3986 requires: `//a@b:c/d` is a valid origin-form target, yet `uri-parse-validate
'uri-reference` answers `invalid-port` at 6. So the server splits at the first `?` and
calls `validate-component` itself. Issue #21 measured the cost (Darwin arm64, Chez 10.4.1,
uriparse v0.4.0): `validate-component` allocates 0 bytes, while the copy costs 16, 80 and
512 bytes at 2-, 46- and 500-byte targets. The copy is the only per-request cost that grows
with the target, and the server's decision requires that none does.

## Decision

1. **`validate-component` takes an optional `start` and `end`:
   `Symbol Bytevector [Nat [Nat]] -> (values (Option Symbol) (Option Nat))`.** They default
   to 0 and the bytevector's length (a `case-lambda`, so `start` alone runs to the end). The
   two-argument call judges `[0, length)` with the same per-component judge as the ranged
   call, and skips only the range check (that range is valid by construction). It is one
   implementation, not two, so the whole-bytevector and ranged verdicts cannot drift. It
   keeps the same name rather than adding a second one (the issue allowed either): one
   judge, one name.

2. **The verdict on `bv[start, end)` is the verdict on those bytes alone.** Nothing outside
   the range is read. A `%` whose two HEXDIGs would lie past `end` is malformed
   (`invalid-pct-encoded` at that `%`), even when the bytes after `end` would complete it.
   An empty range is an empty component (a valid path, query or fragment; an invalid
   scheme at 0).

3. **The index is relative to `start`.** This is the existing "component-relative" contract
   (0024 item 3): the component is the range. The caller rebases it, just as `(uri
   collect)` already rebases to an absolute offset. The two-argument call's indices are
   unchanged.

4. **A range not within the bytevector is an assertion violation**, which names
   `validate-component`. That covers a non-fixnum, `start < 0`, `start > end` and
   `end > length`. It is refused, never clamped: a clamped range would judge bytes the
   caller did not name. An unknown component is named FIRST, before the range or the
   bytevector is looked at, as the two-argument call always did (`(validate-component
   'bogus 42)` still reports the component, not `bytevector-length`).

5. **Judging a span allocates nothing that grows with its length.** This property is the
   point of the change, and a check pins it for all four components (a 2-byte and a 4000-byte
   span allocate the same over 1000 calls, each the least of three windows so a collection
   firing inside one window cannot redden it). What was measured is stronger: 0 bytes per
   call for every component at 2, 46, 500 and 4000 bytes (the 160 B read is the statistics
   call itself, the same at 0 calls). What
   this decision promises is length-independence.

6. **A ranged `validate-authority` is DEFERRED** (the issue's optional part: chez-http-server
   keeps parse-and-validate for the rare absolute-form and CONNECT targets in v1). Its
   helpers already take `[s, e)` (`validate-userinfo`, `validate-reg-name`,
   `validate-port`), so it is a small additive change once a request measures the need.

7. **No new library, no lane registration, no scanner/grammar change, and no
   release-scoped doc edit at merge.** `(uri charset)` gains no export; its export list is unchanged. `(uri
   collect)` still calls the two-argument form on its component bytevectors. The README and
   CHANGELOG note rides the next release (0032 item 5).

## Evidence

The already-registered `unit.charset` lane (14 cases, 1274 checks, 0 failures on the source
lane, Darwin arm64, Chez 10.4.1 tarm64osx, 2026-09-24) now also covers:

- **Agreement with the independent oracle.** For every component, 15 shapes and 7 hostile
  surroundings, the ranged verdict matches `oracle-scan` on the span copied out. The
  surroundings are `" "`, invalid in every component, so a scan from 0 or on to the buffer's
  end trips on it; `"41"`, which completes a `%` or `%4` cut at `end`; and a valid prefix,
  which moves an absolute index off the relative one.
- **Hardcoded pins, independent of the oracle.** A request line's path and query spans; the
  origin-form `//a@b:c/d` span beside the collector's `invalid-port@6` reading; a triple cut
  by `end`; the relative index; empty spans; the scheme's first byte and a later one; and
  `start` alone.
- **Refusal.** Six bad ranges on `"a b"`, each required to raise with `validate-component`
  as its who: a primitive's own bounds or fixnum check is an &assertion too, so the who is
  what makes a row a witness of the guard. For `(1 0)` and `(0 9)` a scan that trusted the
  range would stop at the space and answer instead of raising.
- **Ordering.** An unknown component (`'authority`) is named before a bad range and before
  a non-bytevector.
- **Allocation.** Length-independence for all four components, as in item 5.

Each was mutation-witnessed: 20 mutants, each asserted to land, each reddening the lane
(scan from 0; scan or scheme-scan to the buffer's end; pct guard bounded by the buffer;
absolute index in each of the three reporting arms; scheme ALPHA read at 0; scheme empty by
length; no range guard, which reddens all six refusal rows; each half of the guard; `start`
ignored; judging a copy; a copy in the scheme, query or fragment arm alone; the length, or
the range, checked before the component).

## Consequences

- chez-http-server judges origin-form's path and query in place. Its copy workaround and the
  explicit copy term in its length-independence check can go, once it consumes a uriparse
  that carries this change.
- `validate-component`'s whole-bytevector behaviour is unchanged for every input, misuse
  diagnostics included (the existing single-byte, battery and exhaustive `%XY` oracle
  agreement, and the M3 negative/positive corpora, drive the two-argument form end to end;
  the ordering check pins the unknown-component diagnostic).
- What stays deferred is a separate choice, not a gap: a ranged `validate-authority`
  (item 6).
