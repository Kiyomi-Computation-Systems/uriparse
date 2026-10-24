# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| The latest release (see [CHANGELOG.md](CHANGELOG.md)) | ✅ |
| Earlier releases | ❌ |

## Reporting a vulnerability

Please report suspected vulnerabilities privately via GitHub:
**Security → Report a vulnerability** on this repository. Do not open a
public issue.

You can expect an acknowledgement within 7 days.

Servers use this library to decide where a request goes and what it may
reach, so these reports are especially welcome:

- a URI it accepts that RFC 3986 refuses, or reads differently from the RFC:
  a different host, port, path or query;
- a path that normalizing or resolving lets climb above where it started;
- percent-decoding that yields bytes or a string the input doesn't spell,
  or accepts UTF-8 it should refuse;
- input that makes it allocate in proportion to its size, or loop, or read
  outside the span it was given.

Please include your platform, Chez version, the procedure you called and
the exact input, as a string or as bytes.

A report about byte-machine's runtime, which the scanner runs on, is welcome
here too.
