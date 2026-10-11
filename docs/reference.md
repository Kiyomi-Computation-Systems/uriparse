# API reference

Every library uriparse has, and every binding each one exports. The guides
explain how the pieces fit together; this page answers the smaller
question: what exactly is this binding, and where does it come from?

## Reading this page

Each entry starts with a signature, in the same notation as the comments in
the source:

```scheme
;; uri-port : Uri -> (Option Nat)
(uri-port (string->uri "http://a:8080/"))
;; => 8080
```

reads as "`uri-port` takes a URI record and returns a natural number, or
`#f`". The names used:

| Name            | Means                                                      |
|-----------------|------------------------------------------------------------|
| `(Option T)`    | a `T`, or `#f`                                             |
| `Nat`           | an exact integer, zero or more                             |
| `Octet`         | an exact integer from 0 to 255: one byte                   |
| `Uri`           | a URI record from `(uri easy)`                             |
| `Components`    | five parts from `(uri components)`                         |
| `Result`        | a parse result from `(uri collect)`                        |
| `Collector`     | a collector from `make-uri-collector`                      |
| `[x]`           | an optional argument                                       |
| `(values A B)`  | two return values                                          |

**Available from** names every library that exports the binding. The test
suite checks this page against the source: every export has exactly one
entry, naming exactly the libraries that export it, and nothing else has an
entry.

## Modules

| Module                    | What it is for                                              |
|---------------------------|-------------------------------------------------------------|
| `(uri easy)`              | URIs as strings: parse, read, decode, resolve, compare      |
| `(uri collect)`           | parse and validate bytes, at once or in chunks              |
| `(uri components)`        | the five parts of a URI, as bytevectors                     |
| `(uri charset)`           | check the characters of a scheme, path, query or fragment   |
| `(uri host)`              | check an authority; find its host                           |
| `(uri resolve)`           | resolve a reference against a base                          |
| `(uri recompose)`         | write parts back out as a URI                               |
| `(uri normalize)`         | normalize case and percent-encoding                         |
| `(uri path)`              | remove dot segments; merge paths                            |
| `(uri query)`             | split a query into `key=value` pairs                        |
| `(uri percent)`           | percent-encode and decode bytes                             |
| `(uri vocabulary)`        | the scanner's modes, spans, callbacks and error codes       |
| `(generated uri-scanner)` | the generated scanner, for embedding it yourself            |
| `(uri grammar)`           | the grammar the scanner is generated from; build time only  |
| `(uri range)`             | the range check the in-place validators share; internal     |

Most programs need only `(uri easy)`. A server reading bytes uses
`(uri collect)` and `(uri components)`, and reaches for the others as it
needs them. The last three are there for completeness: you will not need
them unless you are generating or embedding the scanner.

## URIs as strings: parsing

### `string->uri` (procedure)

`string->uri : String -> Uri`

Parses and validates an absolute URI: one with a scheme. Raises a
`&uri-error` when the string is not one.

**Available from:** `(uri easy)`\
**Details:** [Parsing](easy.md#parsing)

### `string->uri-reference` (procedure)

`string->uri-reference : String -> Uri`

Parses and validates a URI reference: an absolute URI or a relative
reference. Raises a `&uri-error` when the string is neither.

**Available from:** `(uri easy)`\
**Details:** [Parsing](easy.md#parsing)

### `string->relative-ref` (procedure)

`string->relative-ref : String -> Uri`

Parses and validates a relative reference: one with no scheme. Raises a
`&uri-error` when the string is not one, with `scheme-forbidden` when it has
a scheme.

**Available from:** `(uri easy)`\
**Details:** [Parsing](easy.md#parsing)

### `uri-string?` (predicate)

`uri-string? : String [Mode] -> Boolean`

Whether the string parses and validates in the mode: `'uri` (the default),
`'uri-reference` or `'relative-ref`. Never raises a `&uri-error`. An unknown
mode is an assertion violation.

**Available from:** `(uri easy)`\
**Details:** [Parsing](easy.md#parsing)

### `uri?` (predicate)

`uri? : Any -> Boolean`

Whether the value is a URI record. The record is opaque: its parts are
reachable only through the procedures on this page.

**Available from:** `(uri easy)`

## URIs as strings: reading

### `uri-scheme` (accessor)

`uri-scheme : Uri -> (Option String)`

The scheme, in lowercase. `#f` for a relative reference.

**Available from:** `(uri easy)`\
**Details:** [Reading](easy.md#reading)

### `uri-authority` (accessor)

`uri-authority : Uri -> (Option String)`

The authority, `userinfo@host:port`, as written. `#f` when there is no `//`;
`""` for `file:///x`.

**Available from:** `(uri easy)`\
**Details:** [Reading](easy.md#reading)

### `uri-userinfo` (accessor)

`uri-userinfo : Uri -> (Option String)`

The userinfo, as written, case kept. `#f` when no `@` comes before the host;
`""` for `http://@a`.

**Available from:** `(uri easy)`\
**Details:** [Reading](easy.md#reading)

### `uri-host` (accessor)

`uri-host : Uri -> (Option String)`

The host, normalized: lowercase, with needless `%XX` decoded and the hex of
any other `%XX` in uppercase. An IPv6 or future address keeps its brackets.
`#f` when there is no authority. The record itself is never changed.

**Available from:** `(uri easy)`\
**Details:** [Reading](easy.md#reading)

### `uri-port` (accessor)

`uri-port : Uri -> (Option Nat)`

The port as a number: `080` is 80. There is no range check, since RFC 3986
has none. `#f` when there is no port, and when it is empty (`http://a:`).

**Available from:** `(uri easy)`\
**Details:** [Missing or empty](easy.md#missing-or-empty)

### `uri-path` (accessor)

`uri-path : Uri -> String`

The path, as written. Never `#f`: `""` when there is none. A path
`(uri easy)` had to guard reads as held, such as `/.//bar` for the path
`//bar`.

**Available from:** `(uri easy)`\
**Details:** [Reading](easy.md#reading)

### `uri-query` (accessor)

`uri-query : Uri -> (Option String)`

The query, as written. `#f` when there is no `?`; `""` for `http://a?`.

**Available from:** `(uri easy)`\
**Details:** [Missing or empty](easy.md#missing-or-empty)

### `uri-fragment` (accessor)

`uri-fragment : Uri -> (Option String)`

The fragment, as written. `#f` when there is no `#`; `""` for `http://a#`.

**Available from:** `(uri easy)`\
**Details:** [Missing or empty](easy.md#missing-or-empty)

## URIs as strings: decoding

### `uri-path-segments` (procedure)

`uri-path-segments : Uri -> (Listof String)`

The path split on `/`, then each segment decoded. The empty segment before a
leading `/` is dropped: `""` is `()`, `/` is `("")`, `/a/b/` is
`("a" "b" "")` and `a/b` is `("a" "b")`. Raises `invalid-utf-8` when a
segment does not decode to UTF-8.

**Available from:** `(uri easy)`\
**Details:** [Decoding](easy.md#decoding)

### `uri-query-pairs` (procedure)

`uri-query-pairs : Uri -> (Listof (Pairof String (Option String)))`

The query's `key=value` pairs, split before decoding. A key with no `=` has
the value `#f`. `+` is a literal `+`. `()` when there is no query. Raises
`invalid-utf-8` when the query does not decode to UTF-8.

**Available from:** `(uri easy)`\
**Details:** [Decoding](easy.md#decoding)

### `uri-form-pairs` (procedure)

`uri-form-pairs : Uri -> (Listof (Pairof String (Option String)))`

As `uri-query-pairs`, but `+` reads as a space, as HTML forms write it.

**Available from:** `(uri easy)`\
**Details:** [Decoding](easy.md#decoding)

### `uri-decode` (procedure)

`uri-decode : String -> String`

Percent-decodes a string. Raises `invalid-utf-8` rather than produce `�`. A
`%` without two hex digits stays a `%`, and `+` stays a `+`.

**Available from:** `(uri easy)`\
**Details:** [Decoding](easy.md#decoding)

### `uri-encode` (procedure)

`uri-encode : String -> String`

Percent-encodes every byte of the string's UTF-8 except the unreserved ones
(letters, digits, `-`, `.`, `_`, `~`), with uppercase hex. The result is safe
in any part of a URI.

**Available from:** `(uri easy)`\
**Details:** [Only ASCII](easy.md#only-ascii)

## URIs as strings: resolving and comparing

### `uri->string` (procedure)

`uri->string : Uri -> String`

The URI as a string. A parsed URI comes back exactly as written.

**Available from:** `(uri easy)`\
**Details:** [Resolving, normalizing, comparing](easy.md#resolving-normalizing-comparing)

### `uri-resolve` (procedure)

`uri-resolve : (U Uri String) (U Uri String) -> Uri`

Resolves a reference (the second argument) against a base (the first),
strictly, as RFC 3986 section 5.2.2 says. A string is parsed as a URI
reference. A base with no scheme raises `base-not-absolute`. Does not
normalize.

**Available from:** `(uri easy)`\
**Details:** [Resolving, normalizing, comparing](easy.md#resolving-normalizing-comparing)

### `uri-normalize` (procedure)

`uri-normalize : Uri -> Uri`

Normalizes as RFC 3986 section 6.2.2 says: the scheme and host in lowercase,
percent-encoding tidied, then `.` and `..` removed. A relative-path reference
such as `../a` keeps its dot segments, which point somewhere until it is
resolved. Nothing that depends on the scheme, such as a default port, is
changed. Normalizing twice gives the same as once.

**Available from:** `(uri easy)`\
**Details:** [Resolving, normalizing, comparing](easy.md#resolving-normalizing-comparing)

### `uri=?` (procedure)

`uri=? : (U Uri String) (U Uri String) -> Boolean`

Whether two URIs are equal after `uri-normalize`. Absent and empty parts
still differ. A string is parsed as a URI reference.

**Available from:** `(uri easy)`\
**Details:** [Resolving, normalizing, comparing](easy.md#resolving-normalizing-comparing)

### `uri->components` (procedure)

`uri->components : Uri -> Components`

The URI's five parts, as fresh bytevectors: changing them cannot change the
URI.

**Available from:** `(uri easy)`\
**Details:** [Crossing to the byte layer](easy.md#crossing-to-the-byte-layer)

### `components->uri` (procedure)

`components->uri : Components -> Uri`

Writes the parts out, then parses and validates the result as a URI
reference. Raises the reason when the parts are not valid, and
`ambiguous-components` when they would parse back as something else. A set
with no path (`#f`) is an assertion violation: a path is never missing, only
empty.

**Available from:** `(uri easy)`\
**Details:** [Crossing to the byte layer](easy.md#crossing-to-the-byte-layer)

## URIs as strings: errors

### `uri-error?` (predicate)

`uri-error? : Any -> Boolean`

Whether the value is a `&uri-error` condition, the one `(uri easy)` raises
for bad input. It is also an `&error`, with a `&who` and a `&message`.

**Available from:** `(uri easy)`\
**Details:** [The easy layer](errors.md#the-easy-layer)

### `uri-error-reason` (accessor)

`uri-error-reason : UriError -> Symbol`

What is wrong: one of `uri-error-reasons`.

**Available from:** `(uri easy)`\
**Details:** [Every reason](errors.md#every-reason)

### `uri-error-offset` (accessor)

`uri-error-offset : UriError -> Nat`

Where it is wrong, as a character index into the input.

**Available from:** `(uri easy)`\
**Details:** [The easy layer](errors.md#the-easy-layer)

### `uri-error-input` (accessor)

`uri-error-input : UriError -> String`

The string that was wrong.

**Available from:** `(uri easy)`\
**Details:** [The easy layer](errors.md#the-easy-layer)

### `uri-error-reasons` (constant)

`uri-error-reasons : (Listof Symbol)`

Every reason a `&uri-error` can carry: the scanner's, character and
authority codes, plus `invalid-utf-8`, `base-not-absolute` and
`ambiguous-components`.

**Available from:** `(uri easy)`\
**Details:** [Every reason](errors.md#every-reason)

## Parsing bytes

### `uri-parse` (procedure)

`uri-parse : Symbol Bytevector -> Result`

Splits the bytes into five parts, in the mode `'uri`, `'relative-ref` or
`'uri-reference`. Lenient: it finds the parts and does not check their
characters. Never raises for bad input; an unknown mode raises a
`uri-vocabulary-error`.

**Available from:** `(uri collect)`\
**Details:** [Parse once](parsing.md#parse-once)

### `make-uri-collector` (procedure)

`make-uri-collector : Symbol -> Collector`

A collector for parsing input that arrives in chunks, in a mode. An unknown
mode raises a `uri-vocabulary-error`.

**Available from:** `(uri collect)`\
**Details:** [Parse in chunks](parsing.md#parse-in-chunks)

### `uri-collect-feed!` (procedure)

`uri-collect-feed! : Collector Bytevector Nat Nat -> FeedResult`

Gives the collector the bytes from `start` to `end` of the bytevector. A
chunk may end anywhere. The return value is byte-machine's feed result, which
you can ignore: an error is kept, and `uri-collect-finish!` reports it.
Bytes fed after `uri-collect-finish!` are ignored, so reset first.

**Available from:** `(uri collect)`\
**Details:** [Parse in chunks](parsing.md#parse-in-chunks)

### `uri-collect-finish!` (procedure)

`uri-collect-finish! : Collector -> Result`

Ends the input and returns the result, the same as `uri-parse` would give for
all the bytes fed.

**Available from:** `(uri collect)`\
**Details:** [Parse in chunks](parsing.md#parse-in-chunks)

### `uri-collector-reset!` (procedure)

`uri-collector-reset! : Collector -> unspecified`

Puts the collector back to new, keeping its mode, for the next input.
Nothing is reallocated.

**Available from:** `(uri collect)`\
**Details:** [Reuse a collector](parsing.md#reuse-a-collector)

### `uri-parse-result?` (predicate)

`uri-parse-result? : Any -> Boolean`

Whether the value is a parse result.

**Available from:** `(uri collect)`

### `uri-parse-ok?` (accessor)

`uri-parse-ok? : Result -> Boolean`

Whether the parse worked.

**Available from:** `(uri collect)`\
**Details:** [The result](parsing.md#the-result)

### `uri-parse-components` (accessor)

`uri-parse-components : Result -> (Option Components)`

The five parts when the parse worked; `#f` when it did not.

**Available from:** `(uri collect)`\
**Details:** [The result](parsing.md#the-result)

### `uri-parse-error-code` (accessor)

`uri-parse-error-code : Result -> (Option Symbol)`

What went wrong when the parse failed; `#f` when it worked.

**Available from:** `(uri collect)`\
**Details:** [The byte layer](errors.md#the-byte-layer)

### `uri-parse-error-offset` (accessor)

`uri-parse-error-offset : Result -> (Option Nat)`

Where it went wrong, as a byte index into the input; `#f` when it worked.

**Available from:** `(uri collect)`\
**Details:** [The result](parsing.md#the-result)

### `uri-parse-component-offset` (procedure)

`uri-parse-component-offset : Result Symbol -> (Option Nat)`

The byte index where a part (`'scheme`, `'authority`, `'path`, `'query` or
`'fragment`) starts in the input. `#f` when the part is absent or the parse
failed.

**Available from:** `(uri collect)`\
**Details:** [The result](parsing.md#the-result)

## Parts as bytes

### `make-uri-components` (record constructor)

`make-uri-components : (Option Bytevector) (Option Bytevector) (Option Bytevector) (Option Bytevector) (Option Bytevector) -> Components`

Five parts, in the order scheme, authority, path, query, fragment. Each is a
bytevector or `#f`, for absent. Anything else raises a
`uri-components-error`.

**Available from:** `(uri components)`\
**Details:** [The five parts](parsing.md#the-five-parts)

### `uri-components?` (predicate)

`uri-components? : Any -> Boolean`

Whether the value is a set of five parts.

**Available from:** `(uri components)`

### `uri-components-scheme` (accessor)

`uri-components-scheme : Components -> (Option Bytevector)`

The scheme, without its `:`.

**Available from:** `(uri components)`\
**Details:** [The five parts](parsing.md#the-five-parts)

### `uri-components-authority` (accessor)

`uri-components-authority : Components -> (Option Bytevector)`

The authority, without its `//`, in one piece.

**Available from:** `(uri components)`\
**Details:** [The five parts](parsing.md#the-five-parts)

### `uri-components-path` (accessor)

`uri-components-path : Components -> (Option Bytevector)`

The path. A parse always gives one, perhaps empty.

**Available from:** `(uri components)`\
**Details:** [The five parts](parsing.md#the-five-parts)

### `uri-components-query` (accessor)

`uri-components-query : Components -> (Option Bytevector)`

The query, without its `?`.

**Available from:** `(uri components)`\
**Details:** [The five parts](parsing.md#the-five-parts)

### `uri-components-fragment` (accessor)

`uri-components-fragment : Components -> (Option Bytevector)`

The fragment, without its `#`.

**Available from:** `(uri components)`\
**Details:** [The five parts](parsing.md#the-five-parts)

### `uri-component-absent?` (predicate)

`uri-component-absent? : (Option Bytevector) -> Boolean`

Whether a part is absent: `#f`.

**Available from:** `(uri components)`\
**Details:** [The five parts](parsing.md#the-five-parts)

### `uri-component-present?` (predicate)

`uri-component-present? : (Option Bytevector) -> Boolean`

Whether a part is present: a bytevector, perhaps empty.

**Available from:** `(uri components)`\
**Details:** [The five parts](parsing.md#the-five-parts)

### `uri-component-empty?` (predicate)

`uri-component-empty? : (Option Bytevector) -> Boolean`

Whether a part is present and empty. False for `#f`, which is absent, not
empty.

**Available from:** `(uri components)`\
**Details:** [The five parts](parsing.md#the-five-parts)

### `uri-component-present-nonempty?` (predicate)

`uri-component-present-nonempty? : (Option Bytevector) -> Boolean`

Whether a part is present and holds at least one byte.

**Available from:** `(uri components)`\
**Details:** [The five parts](parsing.md#the-five-parts)

### `uri-components=?` (procedure)

`uri-components=? : Components Components -> Boolean`

Whether two sets of parts are equal, part by part. An absent part never
equals an empty one.

**Available from:** `(uri components)`

### `uri-components-error?` (predicate)

`uri-components-error? : Any -> Boolean`

Whether the value is the condition `make-uri-components` raises for a part
that is neither a bytevector nor `#f`.

**Available from:** `(uri components)`\
**Details:** [Mistakes in your own code](errors.md#mistakes-in-your-own-code)

### `uri-components-error-detail` (accessor)

`uri-components-error-detail : ComponentsError -> String`

Which part was wrong, in words.

**Available from:** `(uri components)`\
**Details:** [Mistakes in your own code](errors.md#mistakes-in-your-own-code)

## Validating

### `uri-parse-validate` (procedure)

`uri-parse-validate : Symbol Bytevector -> Result`

Parses as `uri-parse` does, then checks every part against RFC 3986's
grammar. An invalid URI gives an error result, at the leftmost fault.

**Available from:** `(uri collect)`\
**Details:** [Parse and validate](validating.md#parse-and-validate)

### `uri-parse-result-validate` (procedure)

`uri-parse-result-validate : Result -> Result`

Checks a result you already have, such as a collector's, without parsing
again. Gives back the same result when it was already an error or is valid,
and an error result otherwise.

**Available from:** `(uri collect)`\
**Details:** [Validate a result you already have](validating.md#validate-a-result-you-already-have)

### `validate-component` (procedure)

`validate-component : Symbol Bytevector [Nat [Nat]] -> (values (Option Symbol) (Option Nat))`

Checks the characters of a `'scheme`, `'path`, `'query` or `'fragment` held
in the bytevector from `start` to `end`, by default all of it. Returns a code
and an index counted from `start`, or `#f #f` when valid. Reads nothing
outside the range. An unknown part or a range that does not fit is an
assertion violation.

**Available from:** `(uri charset)`\
**Details:** [Check one part in place](validating.md#check-one-part-in-place)

### `validate-authority` (procedure)

`validate-authority : Bytevector [Nat [Nat]] -> (values (Option Symbol) (Option Nat))`

Checks an authority's userinfo, host and port, held in the bytevector from
`start` to `end`. Returns a code and an index counted from `start`, or
`#f #f` when valid. An empty authority is valid. A range that does not fit is
an assertion violation.

**Available from:** `(uri host)`\
**Details:** [Check an authority in place](validating.md#check-an-authority-in-place)

### `authority-host-span` (procedure)

`authority-host-span : Bytevector [Nat [Nat]] -> (values Nat Nat)`

Where the host starts and ends inside an authority held from `start` to
`end`, counted from `start`. Brackets around an IPv6 address are included.
Never rejects anything: it reads delimiters only.

**Available from:** `(uri host)`\
**Details:** [Check an authority in place](validating.md#check-an-authority-in-place)

### `uri-parse-authority-form` (procedure)

`uri-parse-authority-form : Bytevector -> Result`

Splits an HTTP `CONNECT` target, `host:port`, leniently. The whole target is
the result's authority. Anything after it gives `not-authority-form`.

**Available from:** `(uri collect)`\
**Details:** [CONNECT targets](validating.md#connect-targets)

### `uri-parse-authority-form-validate` (procedure)

`uri-parse-authority-form-validate : Bytevector -> Result`

As `uri-parse-authority-form`, then holds the target to RFC 9112: no
userinfo (`userinfo-forbidden`), a valid host, and a port that is really
there (`port-required`).

**Available from:** `(uri collect)`\
**Details:** [CONNECT targets](validating.md#connect-targets)

### `uri-charset-error-codes` (constant)

`uri-charset-error-codes : (Listof Symbol)`

The codes `validate-component` can return.

**Available from:** `(uri charset)`\
**Details:** [The byte layer](errors.md#the-byte-layer)

### `uri-charset-error-code?` (predicate)

`uri-charset-error-code? : Any -> Boolean`

Whether the value is one of `uri-charset-error-codes`.

**Available from:** `(uri charset)`

### `uri-host-error-codes` (constant)

`uri-host-error-codes : (Listof Symbol)`

The codes `validate-authority` can return.

**Available from:** `(uri host)`\
**Details:** [The byte layer](errors.md#the-byte-layer)

### `uri-host-error-code?` (predicate)

`uri-host-error-code? : Any -> Boolean`

Whether the value is one of `uri-host-error-codes`.

**Available from:** `(uri host)`

### `uri-authority-form-error-codes` (constant)

`uri-authority-form-error-codes : (Listof Symbol)`

The codes only the authority-form parsers give: `not-authority-form`,
`userinfo-forbidden` and `port-required`.

**Available from:** `(uri collect)`\
**Details:** [The byte layer](errors.md#the-byte-layer)

### `uri-authority-form-error-code?` (predicate)

`uri-authority-form-error-code? : Any -> Boolean`

Whether the value is one of `uri-authority-form-error-codes`.

**Available from:** `(uri collect)`

## Resolving, normalizing and recomposing

### `resolve-components` (procedure)

`resolve-components : Components Components -> Components`

Resolves a reference's parts (the second argument) against a base's parts
(the first), strictly, as RFC 3986 section 5.2.2 says. The base needs a
scheme, and both need a path. Does not normalize.

**Available from:** `(uri resolve)`\
**Details:** [Resolving a reference](resolving.md#resolving-a-reference)

### `recompose` (procedure)

`recompose : Components -> Bytevector`

Writes the parts out as a URI: `scheme:`, `//authority`, path, `?query`,
`#fragment`. A delimiter is written when its part is present, even if empty.
Never rejects anything.

**Available from:** `(uri recompose)`\
**Details:** [Recomposing](resolving.md#recomposing)

### `normalize-components` (procedure)

`normalize-components : Components -> Components`

New parts with the scheme and host in lowercase and percent-encoding
normalized in every part. Absent parts stay absent. Does not remove dot
segments.

**Available from:** `(uri normalize)`\
**Details:** [Normalizing](resolving.md#normalizing)

### `normalize-scheme` (procedure)

`normalize-scheme : Bytevector -> Bytevector`

The scheme in lowercase, by ASCII rules only.

**Available from:** `(uri normalize)`\
**Details:** [Normalizing](resolving.md#normalizing)

### `pct-normalize` (procedure)

`pct-normalize : Bytevector -> Bytevector`

Decodes each `%XX` whose byte is unreserved, and writes the hex of every
other `%XX` in uppercase, in one pass. A malformed `%` is left as it is.

**Available from:** `(uri normalize)`\
**Details:** [Normalizing](resolving.md#normalizing)

### `remove-dot-segments` (procedure)

`remove-dot-segments : Bytevector -> Bytevector`

The path with `.` and `..` segments taken out, as RFC 3986 section 5.2.4
says.

**Available from:** `(uri path)`\
**Details:** [Paths](resolving.md#paths)

### `remove-dot-segments-trace` (procedure)

`remove-dot-segments-trace : Bytevector -> (Listof (List String Bytevector Bytevector))`

Every step of `remove-dot-segments`, as rows of `(step output input)` taken
after each step, the way the RFC writes its worked examples. The first row
is step `"1"`; the last holds the result.

**Available from:** `(uri path)`\
**Details:** [Paths](resolving.md#paths)

### `merge` (procedure)

`merge : Boolean Bytevector Bytevector -> Bytevector`

Puts a relative path (the third argument) onto a base path (the second), as
RFC 3986 section 5.2.3 says. The first argument says whether the base has an
authority; with one, an empty base path counts as `/`.

**Available from:** `(uri path)`\
**Details:** [Paths](resolving.md#paths)

## Queries and percent-encoding

### `query-pairs` (procedure)

`query-pairs : Bytevector -> (Listof (Pairof Bytevector (Option Bytevector)))`

The query's `key=value` pairs, split on `&` and the first `=`, then decoded.
A piece with no `=` has the value `#f`. Empty pieces are skipped; order and
repeats are kept. `+` is a literal `+`.

**Available from:** `(uri query)`\
**Details:** [Query pairs](queries.md#query-pairs)

### `form-pairs` (procedure)

`form-pairs : Bytevector -> (Listof (Pairof Bytevector (Option Bytevector)))`

As `query-pairs`, but `+` reads as a space, before decoding.

**Available from:** `(uri query)`\
**Details:** [Query pairs](queries.md#query-pairs)

### `pct-decode` (procedure)

`pct-decode : Bytevector -> Bytevector`

Replaces each `%XX` with its byte, once. A `%` without two hex digits stays
a `%`. Never fails.

**Available from:** `(uri percent)`\
**Details:** [Percent-decoding](queries.md#percent-decoding)

### `pct-encode` (procedure)

`pct-encode : Bytevector (Octet -> Boolean) -> Bytevector`

Keeps each byte the test accepts and writes every other byte as `%XX`, with
uppercase hex.

**Available from:** `(uri percent)`\
**Details:** [Percent-encoding](queries.md#percent-encoding)

### `unreserved-byte?` (predicate)

`unreserved-byte? : Octet -> Boolean`

Whether the byte is unreserved: a letter, a digit, `-`, `.`, `_` or `~`.

**Available from:** `(uri percent)`\
**Details:** [Percent-encoding](queries.md#percent-encoding)

### `hex-digit-value` (procedure)

`hex-digit-value : Octet -> (Option (Integer 0 15))`

The value of a hex digit, in either case; `#f` for any other byte.

**Available from:** `(uri percent)`\
**Details:** [Percent-encoding](queries.md#percent-encoding)

### `nibble->hex-digit` (procedure)

`nibble->hex-digit : (Integer 0 15) -> Octet`

The uppercase hex digit for a value from 0 to 15.

**Available from:** `(uri percent)`\
**Details:** [Percent-encoding](queries.md#percent-encoding)

## The scanner

These are for embedding the generated scanner with your own byte-machine
callbacks. `(uri collect)` does all of this for you.

### `uri-scanner-machine` (constant)

`uri-scanner-machine : Machine`

The URI scanner, generated by byte-machine from `(uri grammar)` and
committed. Hand it to byte-machine's `make-parser` with your callbacks and a
`mode` field.

**Available from:** `(generated uri-scanner)`\
**Details:** [Under the hood](parsing.md#under-the-hood)

### `uri-mode-table` (constant)

`uri-mode-table : (Listof (List Symbol Nat))`

Each mode's name and the number the scanner's `mode` field takes:
`unset` 0, `uri` 1, `relative-ref` 2, `uri-reference` 3.

**Available from:** `(uri vocabulary)`

### `uri-mode-names` (constant)

`uri-mode-names : (Listof Symbol)`

The modes' names, `unset` first.

**Available from:** `(uri vocabulary)`

### `uri-mode-value` (procedure)

`uri-mode-value : Symbol -> Nat`

A mode's number. An unknown name raises a `uri-vocabulary-error`.

**Available from:** `(uri vocabulary)`

### `uri-mode-width` (constant)

`uri-mode-width : Nat`

The width in bits of the scanner's `mode` field: 8.

**Available from:** `(uri vocabulary)`

### `uri-span-names` (constant)

`uri-span-names : (Listof Symbol)`

The scanner's spans: the five parts, plus `leading-token`, which the
`'uri-reference` mode reads before it knows whether it is a scheme or a path.

**Available from:** `(uri vocabulary)`

### `uri-span-name?` (predicate)

`uri-span-name? : Any -> Boolean`

Whether the value is one of `uri-span-names`.

**Available from:** `(uri vocabulary)`

### `uri-span-data-callback` (procedure)

`uri-span-data-callback : Symbol -> Symbol`

The name of the callback that receives a span's bytes, such as
`on-path-data`. An unknown span raises a `uri-vocabulary-error`.

**Available from:** `(uri vocabulary)`

### `uri-span-complete-callback` (procedure)

`uri-span-complete-callback : Symbol -> Symbol`

The name of the callback that fires once when a span ends, such as
`on-path-complete`. An unknown span raises a `uri-vocabulary-error`.

**Available from:** `(uri vocabulary)`

### `uri-event-callback-names` (constant)

`uri-event-callback-names : (Listof Symbol)`

The callbacks that carry no bytes: `on-scheme-confirmed` and
`on-segment-confirmed` say what a leading token was, and `on-rooted` says a
path's leading `/` must be put back.

**Available from:** `(uri vocabulary)`

### `uri-callback-names` (constant)

`uri-callback-names : (Listof Symbol)`

Every callback the scanner can call: each span's data and complete callback,
then the event callbacks.

**Available from:** `(uri vocabulary)`

### `uri-callback-name?` (predicate)

`uri-callback-name? : Any -> Boolean`

Whether the value is one of `uri-callback-names`.

**Available from:** `(uri vocabulary)`

### `uri-error-codes` (constant)

`uri-error-codes : (Listof Symbol)`

The scanner's error codes: `mode-unset`, `scheme-required`,
`scheme-forbidden` and `unexpected-eof`.

**Available from:** `(uri vocabulary)`\
**Details:** [The byte layer](errors.md#the-byte-layer)

### `uri-error-code?` (predicate)

`uri-error-code? : Any -> Boolean`

Whether the value is one of `uri-error-codes`.

**Available from:** `(uri vocabulary)`

### `uri-vocabulary-error?` (predicate)

`uri-vocabulary-error? : Any -> Boolean`

Whether the value is the condition raised for an unknown mode, span or
callback name.

**Available from:** `(uri vocabulary)`\
**Details:** [Mistakes in your own code](errors.md#mistakes-in-your-own-code)

### `uri-vocabulary-error-detail` (accessor)

`uri-vocabulary-error-detail : VocabularyError -> String`

What was unknown, in words.

**Available from:** `(uri vocabulary)`\
**Details:** [Mistakes in your own code](errors.md#mistakes-in-your-own-code)

### `make-uri-scanner-machine` (procedure)

`make-uri-scanner-machine : -> Machine`

Builds the scanner's source machine with byte-machine's graph builder. It is
used at build time, to generate `(generated uri-scanner)`, and is never on
the path a parse takes.

**Available from:** `(uri grammar)`

## Internals

### `check-range` (procedure)

`check-range : Symbol Bytevector Any Any -> unspecified`

Returns when `start` and `end` are fixnums with
`0 <= start <= end <= length`; otherwise raises an assertion violation that
names the caller. The one range rule every in-place validator shares.

**Available from:** `(uri range)`
