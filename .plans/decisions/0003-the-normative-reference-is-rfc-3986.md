# 0003: RFC 3986 is the normative reference, and disagreement is adjudicated against the ABNF

Date: 2026-09-18
Status: accepted
Plan: [the brief](../2026-09-18-chez-uri-project-brief.md)

## Context

`chez-httparse` had an oracle. It could run llhttp on the same bytes and diff
the traces, and every hard question reduced to "what does upstream do". **This
project has no oracle**, and that is the single biggest difference in how it
must be built.

What it has instead is a specification with normative test vectors in it, and a
field full of implementations that disagree with each other. Browsers implement
WHATWG URL, which is a different standard. Most libraries are deliberately lax.
A few are strict in one component and lax in another. "Popular" is not a
tiebreak.

The rule has to exist **before** the first disagreement, not after, or the first
disagreement writes it.

## Decision

1. **RFC 3986 (STD 66) is the normative reference, and nothing else is.** Not
   WHATWG URL, not RFC 3987, not a popular library's behaviour, not a browser.

2. **No implementation is authoritative.** Differential testing runs against two
   or more independent implementations and treats **agreement as evidence and
   disagreement as a case to adjudicate against the ABNF**, never as a bug
   report against this parser.

3. **A divergence is named and witnessed or it fails the lane.** This is
   `chez-httparse` decision 0018's rule, transferred unchanged, and it matters
   more here rather than less: over there an unexplained divergence meant a bug,
   because llhttp was right by definition. Here it means nobody has read the
   grammar yet. Each accepted divergence gets a decision record naming the
   production, quoting the clause, and pinning a fixture.

4. **"But browsers do X" is answered by this record in one line.** WHATWG is a
   different normative reference. If its behaviour is ever wanted it is a
   separate machine with a separate corpus
   ([0001](0001-the-project-is-chez-uri-and-where-it-stops.md)), not a mode of
   this one.

5. **Where the RFC is silent or ambiguous, the silence is recorded, not
   resolved by taste.** A decision record naming the section and the reading
   taken, with the alternative reading written down, so a later reader can see
   it was a choice.
