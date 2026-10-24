---
name: Bug report
about: Something broke, or a URI parsed unexpectedly
labels: bug
---

<!-- A suspected vulnerability? Don't file it here: SECURITY.md says how to
report it privately. -->

**Environment**

- OS and architecture (e.g. macOS 15 arm64, Ubuntu 24.04 x86_64):
- Chez Scheme version (`chez --version`):
- uriparse version or commit:

**What happened**

**What you expected**

Which part of RFC 3986 says so, if you know (a section, or an ABNF rule)?

**How to reproduce it**

Ideally the exact input, as a string or as bytes, and the procedure you
called: `string->uri` from `(uri easy)`, say, or `uri-parse` from
`(uri collect)` for bytes.

**Does `make test` pass on your machine?**
