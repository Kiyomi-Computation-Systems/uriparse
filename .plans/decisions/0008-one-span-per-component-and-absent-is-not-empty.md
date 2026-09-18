# 0008: one span per component, both callbacks, and absent is not empty

Date: 2026-09-18
Status: accepted, then **amended in part by [0019](0019-the-scanner-splits-five-coarse-components-and-the-core-owns-the-authority.md)**
Plan: [the design](../2026-09-18-chez-uri-design.md) §3
Milestone: M2 — the span vocabulary is declared in full here

> **Amendment (0019).** Item 1's eight spans and item 3's "no authority span" are
> superseded: byte-machine's forward-only model cannot split userinfo from host,
> so the SCANNER emits ONE `authority` span (there IS one now) and
> userinfo/host/port are pure CORE functions over its bytes. Six scanner spans
> remain — scheme, authority, path, query, fragment, leading-token. Everything
> below about **absent vs empty** (items 4, 7) and **both callbacks** (item 5)
> stands unchanged and now governs the `authority` span; item 6 (path is one
> span) stands. Read this record for the absent/empty mechanism; read 0019 for
> which spans the scanner actually opens.

## Context

RFC 3986 §5.3 recomposes on *defined*, not on *nonempty*:

```
if defined(query) then append "?" + query
```

and §5.2.2 branches the same way. `http://a` and `http://a?` are different URIs
and resolve differently; so do `http:/p` (no authority) and `http:///p` (an
authority that is empty). A component ABI that cannot tell absent from empty
cannot implement §5, and this is the kind of thing that is cheap to design in
and expensive to retrofit.

Two `byte-machine` facts decide the shape, and both were read from the source:

- **One span is active at a time, machine-wide.** `span-transfer`
  (`verify.sls:1756`) tracks a single slot; a span-start with another span open
  is refused *"span overlap: another span is already open"* (`:1775`). **Spans do
  not nest.**
- **An empty span is observable.** `byte-machine-span-fragment-step/v2` delivers
  the single empty fragment when `from == to` and nothing has been delivered yet
  (`runtime.sls:831`), and the `span-completion` step always invokes the declared
  completion callback (`:1211`).

## Decision

1. **Eight spans, all declared at M2**, before most of them validate anything:

   | span | present when | absent means |
   |---|---|---|
   | `scheme` | a `:` closed the leading token | a relative reference |
   | `leading-token` | mode 3 only, until the verdict | n/a — [0004](0004-the-ambiguity-is-the-callers-and-the-mode-is-a-settable-field.md) |
   | `userinfo` | an `@` appeared in the authority | no userinfo |
   | `host` | an authority was present | **no authority** |
   | `port` | a `:` followed the host | no port |
   | `path` | always | never absent |
   | `query` | a `?` appeared | no query |
   | `fragment` | a `#` appeared | no fragment |

2. **The full vocabulary is declared at M2 even though validation lands later.**
   Spans do not nest, so shipping one `authority` span now and splitting it into
   three at M4 would be a breaking change to every consumer. Splitting it now
   costs only delimiter work — finding `@`, `:` and `[`…`]` — which is precisely
   what M2 is.

3. **There is no `authority` span.** `authority = [ userinfo "@" ] host [ ":"
   port ]` makes `host` mandatory whenever an authority is present, and `host`
   may be an empty `reg-name`. **The presence of `host` is the presence of the
   authority**, and the empty authority in `http:///p` is a `host` span firing
   with zero bytes.

4. **Presence is carried by whether the callbacks fire at all.** An absent
   component fires nothing; an empty-but-present one fires its data callback once
   with `from == to` and then completion; a nonempty one fires fragments and then
   completion. No presence flags, no sentinel events, no extra fields.

5. **Every component span declares BOTH a data and a completion callback.** A
   span with only a data callback cannot report an empty-but-present component
   across a feed boundary, because the final empty fragment of an
   already-delivered span is suppressed (`runtime.sls:840`). The completion event
   is the one signal that arrives exactly once per present component.

6. **The path is one span, not one per segment.** `/` is not in `pchar`, so
   segmentation is a total function of the path bytes and belongs in the core,
   where `remove_dot_segments` needs segments anyway. One span per segment costs
   N callbacks per path and gives the consumer nothing the core cannot recover.

7. **`uri-components` mirrors this exactly**: five fields, each a bytevector or
   `#f`. `#f` is absent; a zero-length bytevector is present and empty. The two
   are never conflated, and `(uri collect)` is the only place the distinction is
   constructed.

## What this rules out

**Nested spans** — an `authority` span with `host` inside it. The verifier
refuses it, and the alternative (build the machine twice, as llhttp does with
`separateSpans`) buys a redundant surface nothing would exercise.

**A presence bitmask field.** It would be a second source of truth for something
the callback sequence already says unambiguously, and the two would eventually
disagree.
