# 0018: a path-absolute leading slash is recovered by an event, not carried in the span

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §3.1, §4
Amends: the design's implicit assumption that the `path` span carries the whole
path byte-for-byte, including a path-absolute's leading `/`
References: [0004](0004-the-ambiguity-is-the-callers-and-the-mode-is-a-settable-field.md)
(the verdict-event pattern this reuses), [0008](0008-one-span-per-component-and-absent-is-not-empty.md)
(the span model)

## Context

After a `scheme ":"` (mode 1) or at the start of a relative reference (mode 2),
a leading `/` is ambiguous until the next byte:

- `//h/p` — the two slashes introduce an **authority**; they are a delimiter, in
  no span; `host` = `h`; `path` = `/p`.
- `/p` — `path-absolute`; the leading `/` **is** path content; `path` = `/p`.

The design (§3.1) called splitting this "delimiter work". It is not, and the
obstruction is **provable from byte-machine v0.6.0's source**, not merely
unfound. Verified here with three spikes (kept under the session scratchpad):

1. A span's delivered range is `[mark, cursor)`, and the mark is **always** the
   cursor at span-open (`runtime.sls:748,1177`). The mark is only ever written
   to the cursor, to `0` on close/finish, or to the feed start (`:754,1022,
   1370`) — **there is no way to move it backward**.
2. The only span primitives are start and end (`graph.sls:124`); there is no
   cancel or reset, and re-opening a **currently-open** span is refused at verify
   (`verify.sls:1770-1777`). A captured byte cannot be un-captured.
3. The machine is forward-only; to read byte 2 you must `advance` past byte 1,
   and a sequence-dispatch keeps its matched prefix on a mismatch (measured:
   `/x` delivers path `x`, the `/` gone).

So byte 1 (the leading `/`) must be in **no span** for `//h/p` but **inside the
path span** for `/p` — opposite, irrevocable fates, decided before byte 2 is
legible. A `uint` field can carry the *decision* forward but cannot back-date a
span over a consumed byte (a field-routed machine produced byte-identical spans).
**Impossible.**

## Decision

1. **The scanner uses the "authority-canonical" structure.** The `host` span
   fires **iff** an authority was present — empty for `http:///p`, non-empty for
   `http://h`, and never for `http:/p` — which is byte-perfect on the one
   load-bearing property (decision 0008 item 3). The `path` span for the
   authority and rootless cases carries its bytes exactly, leading `/` included
   (path opens *on* the post-authority `/`).

2. **A path-absolute `path` span omits its own leading `/`.** For `/p` the span
   delivers `p`; for `/` it delivers empty; the leading `/` was consumed at the
   two-byte decision with no span open, and no mark reaches back to it. This is
   the single, bounded cost — exactly one byte, the leading slash, and only on a
   path-absolute reference.

3. **A zero-width event `on-rooted` fires exactly in the path-absolute branch**
   — a leading `/` with no authority. It is a verdict event of the same kind as
   decision 0004's `on-scheme-confirmed` / `on-segment-confirmed`: it names what
   the leading `/` turned out to be, carries no bytes, and fires *after* the
   decision, never with a span open (`span-active-at-pause`, `verify.sls:1798`).

4. **`(uri collect)` reconstructs the path component out of band:** `path =
   (if on-rooted-fired "/" "") ++ path-span-bytes`. The `uri-components` path is
   therefore byte-exact (`/p`), even though the span is not — which is what §5.3
   recomposition and §5.2.2 resolution require, and it is why the recovery is a
   correctness requirement, not a nicety.

5. **`on-rooted` joins the callback vocabulary** as a third verdict event beside
   the two mode-3 confirms. It is not a presence flag (decision 0008 item 4's
   "no sentinel events" is about presence, which the callback sequence already
   carries); it reports genuinely new information the sequence cannot — a byte
   the span omits.

## What this rules out

**Pre-opening the `path` span on the first `/`.** It makes path-absolute exact
but fires a **phantom `//` path fragment on every authority case** — path fires
twice, the first delivering the delimiter `//` as bogus path content — because
the tentatively-captured slash(es) must be delivered before `host` can open
(one span at a time, `verify.sls:1774`). Verified. It is strictly worse: it
corrupts the five authority cases to save the one path-absolute byte that an
event recovers cleanly.

**A `rooted` field read after the parse.** Offered and declined: the event fires
inline with the parse, is consistent with 0004's verdict events, and needs no
post-parse field read. (The field mechanism was proven equivalent and kept only
as the rejected alternative.)

## A note for the author of the grammar

A byte edge (`advance`/`reexecute`) may **not** target a `finish` terminal —
only an EOF transition may (`non-eof-into-finish`, `verify.sls:1213-1214`). Reach
`finish` through a dispatch's `eof-target` or a zero-width span chain, never a
byte edge. This is the shape the `on-rooted` verdict and the empty-path arms take.
