# 0005: the corpus is RFC 3986's own vectors, cited by section

Date: 2026-09-18
Status: accepted
Amended by: [0012](0012-the-corpus-instruments-abnfgen-and-mutation.md) (item 4),
[0013](0013-wpt-url-test-data-is-an-input-only-corpus.md) (a second input-only corpus),
[0015](0015-errata-4547-and-5428-are-adjudicated-against-the-abnf.md) (two disputed vectors)
Plan: [the brief](../2026-09-18-chez-uri-project-brief.md), M1

## Context

`chez-httparse`'s "0 deferred, 274 of 274" means something because llhttp's
corpus has provenance: those bytes came from a named upstream at a named commit
and were never hand-edited. A corpus assembled by its own author to be passed
by its own parser means nothing at all, and a number reported over one is worth
less than no number.

This project has no vendored corpus available. What it has is a specification
that contains normative test vectors.

## Decision

1. **The corpus is transcribed from RFC 3986, and every vector cites its
   section.** A `PROVENANCE` file records section numbers, not a prose
   description.

   - **§5.4.1 "Normal Examples" and §5.4.2 "Abnormal Examples"** — roughly fifty
     reference-resolution cases against the base `http://a/b/c/d;p?q`, each with
     its exact expected target. This is a real, citable, normative corpus and it
     is the anchor for the whole resolution layer.
   - **§5.2.4** — `remove_dot_segments` worked by hand on two inputs, step by
     step. Transcribed as step traces, not just as end results.
   - **§1.1.2** — example URIs across ftp, http, ldap, mailto, news, tel, telnet
     and urn. Exactly the scheme diversity llhttp's corpus lacks, and the smoke
     set for `path-rootless`.

2. **A vector is never edited to make a test pass.** If this parser disagrees
   with a §5.4 vector, this parser is wrong, or
   [0003](0003-the-normative-reference-is-rfc-3986.md) item 5 applies and the
   ambiguity gets its own record. The vector does not move.

3. **Vectors this project writes are a separate set, separately labelled.** They
   are needed — the RFC gives no scanner vectors — but they are this project's
   own and never counted in the same number as the transcribed ones. Provenance
   that is averaged is provenance destroyed.

4. **Where the RFC gives no vectors, the instrument is a property, not an
   invented expectation.** Two of them, per the brief:
   - **the chunking property** — a parse that reaches no error produces the same
     spans however the bytes arrive, and the committed artifact agrees with the
     interpreted grammar. Asked of every generated input, under a per-kind floor
     so a lane that selected nothing cannot pass vacuously.
   - **the round-trip property** — parse → normalize (§6) → recompose (§5.3) →
     parse reaches a fixed point, and the second parse's spans equal the first's.

5. **The comparator is mutation-witnessed before it is trusted.** M1 exits on a
   deliberately corrupted expectation failing it. A test that passes whether the
   code is right or wrong is worse than no test.
