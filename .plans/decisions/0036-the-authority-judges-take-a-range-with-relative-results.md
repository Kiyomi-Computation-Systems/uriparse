# 0036: validate-authority and authority-host-span take a range, and every number they return is relative to start

Date: 2026-09-25
Status: accepted
Plan: GitHub issue #24. chez-http-server is adding RFC 9112 §3.2's `Host` rules. Its core
keeps header values as spans `[start, end)` of the socket's buffer and never copies them, so
a `Host` value must be judged in place. Additive, pure Scheme.
References:
[0025](0025-the-host-grammar-is-the-cores-over-the-opaque-authority.md) (the M4 host grammar
and the bracket-aware split these extend),
[0034](0034-validate-component-judges-a-range-so-a-span-is-validated-in-place.md) (#21, the
same change for `validate-component`: its item 6 deferred this one until a request measured
the need, and this is that request).

## Context

`validate-authority` and `authority-host-span` judged a whole bytevector: each began with
`(define n (bytevector-length bv))` and split from index 0. Every helper below them already
took `[s, e)` and returned indices into `bv`: `scan`, `validate-userinfo`,
`validate-reg-name`, `validate-port`, `ip-literal-interior` and `find-byte`. So the whole-bytevector
assumption lived only in the two entry points.

Issue #24 measured the cost on v0.5.0 (Darwin arm64, Chez 10.4.1), and the program was re-run
here with identical output. `validate-authority` on a bytevector already in hand allocates
0 B. Copying a `Host` value out of its line first costs 16 B (`x`), 32 B (`example.com`,
`example.com:8080`, `[::1]:8080`) and 64 B (a 41-byte host). That cost grows with the value,
and every request would pay it. chez-http-server chose to wait for this rather than carry the
copy.

## Decision

1. **Both procedures take an optional `start` and `end`.** The signatures are
   `validate-authority : Bytevector [Nat [Nat]] -> (values (Option Symbol) (Option Nat))`
   and `authority-host-span : Bytevector [Nat [Nat]] -> (values Nat Nat)`.
   - `start` and `end` default to 0 and the length (a `case-lambda`, so `start` alone runs
     to the end).
   - Each procedure has ONE implementation over `[s, e)` (`authority-fault`, `host-span`),
     which returns indices into `bv`. The one-argument call hands it `[0, length)` directly
     and skips the range check, as 0034 did, so its results are unchanged for every input.

2. **The verdict on `bv[start, end)` is the verdict on those bytes alone.** Nothing outside
   the range is read. An `@`, `]` or `:` past `end` does not split, close or delimit
   anything, and a `%` whose HEXDIGs would lie past `end` is malformed.

3. **Every number either procedure returns about a range is relative to `start`.** That means
   `validate-authority`'s fault index, and BOTH of `authority-host-span`'s bounds. The issue
   allowed absolute bounds too. The maintainer chose relative (2026-09-25) so that one rule
   covers every ranged judge, `validate-component`'s index included. A caller indexes its
   buffer at `start` plus the bound. The in-repo callers pass whole bytevectors, where
   relative and absolute coincide: `(uri normalize)`'s `downcase-host` and the authority-form
   port check in `(uri collect)` are unchanged.

4. **A range not within the bytevector is an assertion violation that names the procedure
   called** (`validate-authority` or `authority-host-span`). That covers a non-fixnum,
   `start < 0`, `start > end` and `end > length`. It is refused, never clamped. The four-line
   check is local to `(uri host)`, not shared with `(uri charset)`'s: sharing it would mean a
   new library, and new lane source registrations, for no behaviour.

5. **Judging a span allocates nothing that grows with its length.** A check pins this for both
   procedures, over three shapes (reg-name, IPvFuture, and userinfo + host + port), each held
   as the value span of a `Host: …\r\n` line. Each length takes the least of three windows.
   Measured: 0 B per call for both procedures, on the issue's five hosts and on 4000-byte
   reg-name and IPvFuture values.

6. **The `Host` rule itself stays the server's.** RFC 9110 §7.2's `Host = uri-host [ ":" port ]`
   has no userinfo, but `validate-authority` judges an RFC 3986 authority, which may carry
   one. So a server refuses the userinfo itself: `authority-host-span`'s host start is not 0
   exactly when the span contains an `@`. Likewise, an empty value is a valid (empty) authority
   here; whether an empty `Host` is acceptable is the server's call.

7. **No new library, no lane registration, no scanner/grammar change, and no release-scoped
   doc edit at merge.** `(uri host)` gains no export; its export list is unchanged. The README
   and CHANGELOG note rides the next release (0032 item 5).

## Evidence

The already-registered `unit.host` lane (15 cases, 247 checks, 0 failures on the source lane,
Darwin arm64, Chez 10.4.1 tarm64osx, 2026-09-25) now also covers:

- **Agreement with the independent oracle.** The shared authority battery plus six cut-edge
  shapes, each placed in 12 hostile surroundings, must give `oracle-scan-authority`'s verdict
  on the span copied out. The surroundings are:
  - `" "`, invalid everywhere;
  - a leading `@` or `[`, which re-splits a scan from 0;
  - a trailing `]`, `@x`, `x:` or ` :1`, each of which completes a delimiter search bounded
    by the buffer;
  - a trailing `[`, which opens a literal after an empty host that ends at `end`;
  - `41`, which completes a cut `%`.
- **Hand-derived host bounds.** `authority-host-span` had no direct check before. There are
  now 15 pins, derived by hand from the split. They must hold for the whole bytevector, and
  for the span (relative) in every surrounding.
- **Pinned `Host` lines**, with both the fault and the bounds for each: valid reg-name and
  IPv6-with-port values; a bad reg-name, port and pct-encoded; an IP-literal whose `]` lies
  past `end`; userinfo; and `start` alone.
- **Refusal.** Six bad ranges per procedure, each required to raise with that procedure as its
  who.
- **Allocation.** As in item 5.

Mutation-witnessed. There were 32 mutants, each asserted to land: every `s`/`e` bound and
default in both procedures, each relative rebase, `start` ignored, a copy, and each clause of
the range check and its who.
- 31 redden the lane. Two of those first SURVIVED, and the fix was two more surroundings:
  - the empty-host test measured against the buffer's length (needs a `[` right after `end`);
  - the `:` search to the buffer's end (needs an invalid byte before a later `:`).
- ONE survives and is equivalent: `authority-host-span`'s empty-host test measured against the
  buffer's length. When the host starts at `end` it reads `bv[end]`, but every branch after
  that returns `(end, end)`, the same bounds, so no check can observe it.

Registered suite on the change: release 77/77, 0 failures.

## Consequences

- chez-http-server judges a `Host` value in place, copying nothing, and its RFC 9112 §3.2
  invalid-value rule can land on this.
- 0034 item 6's deferral is discharged. What stays deferred is a result-level authority-form
  validator (0032 item 4), if a request measures the need.
