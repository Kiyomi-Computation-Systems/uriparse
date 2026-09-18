# 0013: WPT's URL test data is an input-only corpus, and the guard is a lane

Date: 2026-09-18
Status: accepted
Plan: [the design](../2026-09-18-chez-uri-design.md) §6
References: [0003](0003-the-normative-reference-is-rfc-3986.md),
[0001](0001-the-project-is-chez-uri-and-where-it-stops.md)

## Context

[`url/resources/urltestdata.json`](https://github.com/web-platform-tests/wpt/blob/master/url/resources/urltestdata.json)
in web-platform-tests is the most hostile URL input set that exists. It is where
a decade of browser URL bugs went to be pinned as data, and nothing this project
could write would come close to it for adversarial coverage. It is
BSD-3-Clause, so it is licence-compatible with this tree.

It is also **WHATWG**, which [0003](0003-the-normative-reference-is-rfc-3986.md)
rules out as an authority and which disagrees with RFC 3986 on ordinary inputs.
[0001](0001-the-project-is-chez-uri-and-where-it-stops.md) names mixing the two
as the parser-differential security class.

So the corpus is valuable and the corpus is dangerous, and the difference
between those is entirely a matter of which columns get read.

## Decision

1. **The inputs are used. The expectations are not.** Each record's `input`
   (and `base`, where present — also an input) is fed to the scanner. Its
   `href`, `protocol`, `username`, `password`, `host`, `hostname`, `port`,
   `pathname`, `search`, `hash` and `failure` fields are WHATWG's answers to a
   question this project is not asking.

2. **The guard is structural, then audited.** The loader constructs records that
   carry the input fields *only* — the expectation fields are discarded at parse
   time, so there is nothing to dereference later. On top of that, **an audit
   lane greps the loader and every consumer for the WHATWG field names above and
   fails if one appears.** A promise in a comment is not a guard; this is the
   same habit as [0007](0007-src-is-pure-r6rs-and-chez-is-confined.md)'s import
   audit.

3. **Only this project's own invariants are asserted**, and none of them is
   about whether an input is valid:
   - the parser does not crash and is never poisoned;
   - identical spans under every chunk schedule;
   - round-trip to a fixed point on inputs that parse.

   **"WPT says this is a failure" is never an assertion**, because WHATWG's
   `failure` and RFC 3986's grammar disagree by design.

4. **It does not gate a milestone on a pass count.** There is no ratchet number
   over this corpus; it either finds a crash or a chunk-dependence, or it is
   quiet. A number over it would invite exactly the reading item 1 forbids.

5. **It is vendored as data and never hand-edited**, refreshed by a script
   naming the upstream commit — the same rule `chez-httparse` decision 0007
   applies to the llhttp corpus. A corpus edited by hand to make a lane green is
   not a corpus.
