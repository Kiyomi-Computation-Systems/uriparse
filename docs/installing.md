# Installing

## What you need

- [Chez Scheme](https://cisco.github.io/ChezScheme/) 10.4.1 or newer. The
  libraries are plain R6RS, but Chez is the only Scheme they are tested on.
- [byte-machine](https://github.com/Kiyomi-Computation-Systems/byte-machine),
  the runtime the generated URI scanner runs on. It comes along as a git
  submodule.

## Get the code

Clone with the submodule:

```sh
git clone --recurse-submodules https://github.com/Kiyomi-Computation-Systems/uriparse.git
```

If you cloned without it, fetch it now:

```sh
git submodule update --init
```

There is nothing to build. The libraries are source files in two folders:

| Folder                    | Holds                                    |
|---------------------------|------------------------------------------|
| `src/`                    | uriparse: `(uri ...)` and `(generated uri-scanner)` |
| `vendor/byte-machine/src` | byte-machine's runtime                   |

## Tell Chez where they are

Chez finds libraries through its library path. Put both folders on it, with
`--libdirs`:

```sh
scheme --libdirs "src:vendor/byte-machine/src" --program hello.sps
```

or with `CHEZSCHEMELIBDIRS`:

```sh
export CHEZSCHEMELIBDIRS="/path/to/uriparse/src:/path/to/uriparse/vendor/byte-machine/src:"
```

The trailing `:` keeps Chez's own default path after yours. On Windows the
separator is `;`, not `:`.

## A first program

Save this as `hello.sps`:

```scheme
(import (rnrs) (uri easy))

(define u (string->uri "https://example.com:8443/docs/start?lang=en#intro"))

(display (uri-scheme u)) (newline)
(display (uri-host u)) (newline)
(display (uri-port u)) (newline)
(display (uri-path-segments u)) (newline)
(display (uri-fragment u)) (newline)
```

Run it with the `scheme` command above. It prints:

```text
https
example.com
8443
(docs start)
intro
```

## Which library to import

Most programs need only `(uri easy)`. The rest are for working in bytes.

| Import             | For                                                    |
|--------------------|--------------------------------------------------------|
| `(uri easy)`       | URIs as strings: parse, read, resolve, compare         |
| `(uri collect)`    | parse and validate bytes, at once or in chunks         |
| `(uri components)` | the five parts a byte-level parse gives back           |
| `(uri charset)`    | check one part's characters                            |
| `(uri host)`       | check an authority; find its host                      |
| `(uri resolve)`    | resolve a reference against a base                     |
| `(uri recompose)`  | turn parts back into a URI                             |
| `(uri normalize)`  | normalize case and percent-encoding                    |
| `(uri path)`       | remove `.` and `..`; merge paths                       |
| `(uri query)`      | split a query into `key=value` pairs                   |
| `(uri percent)`    | percent-encode and decode bytes                        |

The [API reference](reference.md#modules) lists every library, including
the few you will not need.
