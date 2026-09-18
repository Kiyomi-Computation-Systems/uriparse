# 0015: errata 4547 and 5428 are rejected; RFC 3986 as published is the text

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §6
References: [0003](0003-the-normative-reference-is-rfc-3986.md) items 3 and 5,
[0005](0005-the-corpus-is-the-rfcs-own-vectors.md) item 2

## Context

[0005](0005-the-corpus-is-the-rfcs-own-vectors.md) makes RFC 3986 §5.4 the
anchor of the whole resolution layer and says a vector is never edited to make a
test pass. Checking the [errata](https://errata.rfc-editor.org/search/?rfc_number=3986)
before transcribing anything found that **two reported errata touch exactly the
text this project depends on**, and that someone will eventually raise them
against a lane. This record is the answer, written before the first
disagreement rather than after.

RFC 3986 has two **Verified** errata, and neither matters here: 2525 (§3.1,
updates a reference from RFC 2718 to RFC 4395) and 7590 (§5.2.4, removes a
stray hyperlink from a "1"). Everything below is **Held for Document Update**,
which is not normative text.

## Decision

1. **This project implements RFC 3986 as published.** A "Held for Document
   Update" erratum is a note to a future editor, not a change to the standard.
   Each one that touches this project's scope is adjudicated against the ABNF
   and recorded; none is adopted merely for having been filed.

2. **Erratum 4547 (§5.4.2, excess `..` segments) is rejected.** It proposes
   changing two Abnormal Examples:

   | reference | RFC 3986 says | 4547 proposes |
   |---|---|---|
   | `../../../g` | `http://a/g` | `http://a/../g` |
   | `../../../../g` | `http://a/g` | `http://a/../../g` |

   **The RFC settles this against itself, twice.** §5.2.4 step 2C says to
   replace the prefix and "remove the last segment and its preceding '/'
   **(if any)** from the output buffer" — the parenthetical is precisely the
   empty-output-buffer case, and it discards the excess `..` rather than
   emitting it. And §5.4.2's own prose warns in as many words: *"Parsers must be
   careful in handling cases where there are more '..' segments in a
   relative-path reference than there are hierarchical levels in the base URI's
   path."* The algorithm and the vectors agree; the erratum contradicts both.

   **The §5.4.2 vectors are transcribed as published**, and this record is why.

3. **Erratum 5428 (§4.2, `path-abempty` in `relative-part`) is rejected.** It
   claims the ABNF "excludes '/' being a valid URI". It does not:

   ```abnf
   path-absolute = "/" [ segment-nz *( "/" segment ) ]
   ```

   The bracket makes everything after the slash optional, so `/` **is**
   `path-absolute`, which **is** an alternative of `relative-part`. The reporter
   read the optional group as required.

   **Witnessed by a second implementation**: uriparser 1.0.2 parses `/` cleanly
   as `absolutePath = TRUE` with no segments
   ([`.plans/spikes/2026-09-18-uriparser-oracle-probe.c`](../spikes/2026-09-18-uriparser-oracle-probe.c)).
   A fixture pins `/` as a valid `relative-ref` so the reading is checked rather
   than asserted here.

4. **Four errata are open and adjudicated at their milestone, not now.** They
   touch code that does not exist yet, and reading them now would produce a
   position with nothing to check it against. Each is resolved **before** the
   code it concerns is written:

   | erratum | section | concerns | adjudicate at |
   |---|---|---|---|
   | 4789 | §5.2.3 | `merge` when the base path is empty or ends in `/..` | M6 |
   | 2933 | §5.2.2 | `merge`'s parameters and the authority component | M6 |
   | 2033 | §3.3 | spelling `path-empty` as `""` rather than `0<pchar>` | M2 (cosmetic) |
   | 4942 | §3.2.2 | `reg-name`'s definition via `sub-delims` | v0.2, M4 |

   4789 and 2933 are the two that could actually move behaviour, and they land
   in the one milestone gated at 100% on a normative corpus
   ([0011](0011-v01-is-resolution-first.md) item 3). If either is adopted and
   §5.4 still passes, both facts go in the record.

5. **Rejected errata are not re-litigated per pull request.** 4393 and 4394
   (reordering `dec-octet`, restructuring `IPv6address`) were rejected upstream
   as misuses of ABNF, and 3330, 7019, 4293 and 8442 concern Appendix B's
   regular expression, which this project does not implement. They are noted
   here so a reader who finds them knows they were seen.
