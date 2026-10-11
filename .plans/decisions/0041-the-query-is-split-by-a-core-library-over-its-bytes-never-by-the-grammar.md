# 0041: the query is split by a core library over its bytes, never by the grammar

Date: 2026-10-11
Status: accepted
Plan: [the easy-layer plan](../2026-10-11-easy-layer.md)
Amends: [0001](0001-the-project-is-chez-uri-and-where-it-stops.md) (the
`application/x-www-form-urlencoded` out-of-scope bullet)
References:
[0008](0008-one-span-per-component-and-absent-is-not-empty.md) (spans do not
nest),
[0013](0013-wpt-url-test-data-is-an-input-only-corpus.md) (WHATWG's expectations
are not read),
[0019](0019-the-scanner-splits-five-coarse-components-and-the-core-owns-the-authority.md)
(the core sub-splits what the scanner holds opaque),
[0040](0040-the-easy-layer-is-strings-at-the-edge-one-record-and-a-validated-domain.md)

## Context

RFC 3986 defines `query = *( pchar / "/" / "?" )`. Inside it, `&` and `=` are
sub-delims, allowed bytes with no structure. §3.4 says queries "often" carry
`key=value` pairs but defines no such thing, so the scanner rightly returns
`q=1&r=2` as one value. The pairs come from HTML's
`application/x-www-form-urlencoded`. 0001 keeps that out of the grammar, and
allows it in "a clearly separate module".

The scanner cannot be the place to split. Spans do not nest (0008), and per-pair
spans would change the scanner ABI chez-http-server is built on, for a convention
that is not RFC 3986. 0019 met the same wall for the authority and moved the
userinfo/host/port split into a core function over the authority's bytes. A
query split is the same shape, one component over.

Leaving the split to users is not neutral either. The obvious version decodes
first and splits second, and gets `%26` wrong:

```
q=a%26b&r=1   split, then decode  →  (("q" . "a&b") ("r" . "1"))
              decode, then split  →  (("q" . "a") ("b" . #f) ("r" . "1"))
```

## Decision

1. **`(uri query)`, in `src/uri/query.sls`, is a pure core library over
   bytevectors.** It imports `(rnrs)` and `(uri percent)`, and sits beside
   `(uri host)`.

   ```
   query-pairs : Bytevector -> (Listof (Pairof Bytevector (Option Bytevector)))
   form-pairs  : Bytevector -> (Listof (Pairof Bytevector (Option Bytevector)))
   ```

2. **The split, in order:**
   - Split on `&` only. `;` is not a separator: RFC 3986 names none, and WHATWG
     dropped `;`.
   - Skip empty pieces: `a&&b` has two pairs, while `""` and `"&"` have none.
   - Split each piece at its **first** `=`: `a=b=c` gives `("a" . "b=c")`. No
     `=` gives an absent value, so `a` is `("a" . #f)` while `a=` is
     `("a" . "")` (0008, one level down).
   - `form-pairs` only: map `+` to a space on the **raw** bytes, before
     decoding. So `x=%2B+y` reads `"+ y"`, where `query-pairs` reads `"++y"`.
   - Percent-decode each key and value with `pct-decode`, after the split.
   - Keep input order and duplicates: `a=1&a=2` is two pairs.

3. **Total.** Every bytevector splits, and nothing is rejected. Charset belongs
   to `(uri charset)`; UTF-8 belongs to the easy layer (0040 item 5).

4. **It does not claim WHATWG conformance.** `form-pairs` reads `+` the HTML
   way, but it keeps absent values (WHATWG reads `a` as `""`), and the easy
   layer is strict UTF-8 (WHATWG substitutes U+FFFD). Under 0013, WPT's
   urlencoded expectations are WHATWG's answers and are not read. The reference
   is a hand-derived vector table plus an independent oracle that imports
   neither `(uri percent)` nor `(uri query)`.

5. **No ranged `[start, end)` form yet.** chez-http-server reads the query as a
   string today. If a server measures the need, the ranged form follows the way
   `validate-component`'s did (0034).

## What this rules out

- **Scanner spans for pairs**, and any change to the scanner ABI for them.
- **Decode-then-split**, and `+` → space after decoding.
- **A hash table as the result.** It loses order and duplicates.
- **`+` as a space by default.** In RFC 3986, `+` is a literal sub-delim.

## Consequences

- 0001 gains a header line. Its bullet stands for the grammar: the RFC 3986
  query stays opaque in the scanner, in `uri-components` and in every low-layer
  function. This record adds the separate split that bullet allowed.
- The easy layer exposes the split as `uri-query-pairs` and `uri-form-pairs`
  (0040).
