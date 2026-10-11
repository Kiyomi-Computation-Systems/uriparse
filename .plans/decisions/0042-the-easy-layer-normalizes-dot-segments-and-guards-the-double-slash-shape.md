# 0042: the easy layer normalizes dot segments, and guards the `//` shape resolution can reach

Date: 2026-10-11
Status: accepted, then **amended in review** (2026-10-11, #40)
Plan: [the easy-layer plan](../2026-10-11-easy-layer.md)
Amends: [0022](0022-the-round-trip-property-is-a-one-step-parse-recompose-identity.md)
(its claim about §5.2.2 resolution)
References:
[0020](0020-v01-normalizes-scheme-and-percent-and-defers-host-case.md)
(normalization creates dot segments),
[0040](0040-the-easy-layer-is-strings-at-the-edge-one-record-and-a-validated-domain.md)
(every `Uri` holds validated components)

> **Amendment (review of #40).** Two readings of a guarded path. `uri-path`
> returns it as held, `/.//bar`. `uri-path-segments` reads it as the path it
> names, `("" "bar")`: with no authority, `/.//` is the only way to write a path
> beginning `//`, so its `.` is the escape, never a segment. Any other `/./` is an
> ordinary dot segment. And `components->uri` refuses a set whose path is `#f` as
> an assertion violation, not as `ambiguous-components`: RFC 3986's path is never
> undefined, only empty.

## Context

0022's Context says the parser never emits the §3.3 shape: no authority, and a
path that begins `//`. That holds. It then says §5.2.2 resolution never reaches
the shape either, because neither the parse nor `merge` / `remove-dot-segments`
"ever synthesizes ... a `//`-leading no-authority path". **That is false.**
Measured 2026-10-11 against the low layer:

```
resolve  base foo:/a   ref .//bar   → {scheme foo, authority #f, path "//bar"}
recompose                           → "foo://bar"
re-parse                            → {scheme foo, authority "bar", path ""}
```

`/.//bar` against `foo:/a` gives the same target. §5.2.4's case B rewrites `/./`
to `/`, so a path that begins `/.//` comes out beginning `//`. With no authority,
§5.3 writes that path straight after `foo:`. An authority in the base keeps the
`//` inside the path, which is why the §5.4 corpus (all `http://a/...`) never
meets it.

The easy layer meets it twice. `uri-resolve` wraps `resolve-components`. And
`uri-normalize` should remove dot segments (§6.2.2.3), so it would take
`foo:/.//bar` to the same shape. A `Uri` that renders to a different URI breaks
0040's invariant.

## Decision

1. **`uri-resolve` is strict §5.2.2, and does not normalize.** It wraps
   `resolve-components` and reproduces all 42 §5.4 targets exactly, as strings.

2. **`uri-normalize` is the full §6.2.2 syntax-based normalizer.** It runs
   `normalize-components` (scheme and host case, percent-encoding), *then*
   `remove-dot-segments` on the path. The order is load-bearing:
   percent-normalization turns `%2E%2E` into `..`, which the removal then
   collapses (`http://h/a/%2E%2E/b` → `http://h/b`; §2.3 makes them
   equivalent). Dot removal is skipped for a **relative-path reference** (no
   scheme, no authority, a path not beginning `/`). There, `..` means something:
   `remove-dot-segments("../b")` is `"b"`, which resolves differently. §6.2.3
   scheme-based normalization is not done. Over the validated domain,
   `uri-normalize` is idempotent, and a lane asserts it. (0022 item 2 showed it
   is not idempotent over the lenient domain; `%%341` cannot be a `Uri`.)

3. **`uri=?` is `uri-components=?` over the two `uri-normalize`d values.**

4. **The guard.** When a `Uri` the easy layer builds has no authority and a path
   beginning `//`, `/.` is prefixed to the path. `/.//bar` is a valid
   `path-absolute` that re-parses unchanged, and `remove-dot-segments` maps it
   back to `//bar`, so it names the same resource. The guard runs after
   `uri-resolve` and after `uri-normalize`. It is idempotent: normalizing
   `/.//bar` removes the dot, and the guard restores it.

5. **`components->uri` checks instead of trusting.** It recomposes, re-parses in
   `uri-reference` mode with validation, and requires the result to equal its
   argument. A hand-built set that would change meaning, such as `(#f #f "a:b"
   #f #f)` (which re-parses with scheme `a`), raises `ambiguous-components`.

6. **The low layer does not change.** `recompose` stays the §5.3 algorithm as
   written (0022 item 4). The shape is pinned in `property.round-trip` as a
   third expected non-round-trip, next to the two 0022 pins. The group's three
   cases are `.//bar` and `/.//bar` against `foo:/a`, plus an `http://h/a`
   control whose authority keeps the `//` inside the path.

## Evidence

The pin was watched failing (2026-10-11, the source lane, Chez 10.4.1) under two
mutations of a scratch copy of `src/`, each asserted landed before its result
was read. Before the pin, the lane ran 27 cases and 96 checks; with it, 30 and
108.

- `recompose` writing `/.` before a `//`-leading path after no authority: 3
  cases fail, 6 checks. Those are both `foo:` cases, plus 0022's existing
  hand-built §3.3 case.
- `remove-dot-segments` case B dropping three bytes of `/./` instead of two: 3
  cases fail, 9 checks. Those are all three cases of the new group, the `http`
  control included.

## Consequences

- 0022 gains a header line. Its item 4 stands, and so does its domain claim over
  parse outputs. Only the resolution sentence was wrong.
- The README's "Scope and limits" bullet on recomposition named only hand-built
  components. It now names the resolution case too.
- The easy layer's renderer can emit `/.//` where §5.3 would emit `//`. That
  departs from the literal §5.3 output for one shape, the one where the literal
  output is a different URI.
