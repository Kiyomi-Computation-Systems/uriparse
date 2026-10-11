# Errors

uriparse reports bad input in two ways:

- **`(uri easy)` raises.** A bad URI raises a `&uri-error` condition.
- **The byte layer returns.** `uri-parse` and its friends never raise for bad
  input. They return a result that says what went wrong and where.

Either way, the error has a **code**, a symbol that names what is wrong, and
an **offset** that points at where. Most codes name the rule in RFC 3986's
grammar that the input broke, in the RFC's own spelling: `invalid-pchar`
means the `pchar` rule, a path character.

## The easy layer

A `&uri-error` carries a reason, an offset and the input:

```scheme
(guard (e ((uri-error? e)
           (list (uri-error-reason e) (uri-error-offset e) (uri-error-input e))))
  (string->uri "http://a/%zz"))
;; => (invalid-pct-encoded 9 "http://a/%zz")
```

It is also an R6RS `&error`, with a `&who` naming the procedure you called
and a `&message`, so a handler that catches any error catches it too:

```scheme
(guard (e ((error? e) (condition-who e)))
  (string->uri "http://a/%zz"))
;; => string->uri
```

The offset counts characters, not bytes:

```scheme
(guard (e ((uri-error? e) (uri-error-offset e)))
  (uri-decode "é%FF"))
;; => 1
```

### Every reason

`uri-error-reasons` lists them all:

```scheme
(length uri-error-reasons)
;; => 16
```

| Reason                | Means                                              | Example                 |
|-----------------------|----------------------------------------------------|-------------------------|
| `scheme-required`     | `string->uri` got no scheme                        | `/a`                    |
| `scheme-forbidden`    | `string->relative-ref` got a scheme                | `http://a`              |
| `unexpected-eof`      | the input ended too soon: see below                |                         |
| `invalid-scheme`      | a bad character in the scheme                      | `1http://a`             |
| `invalid-userinfo`    | a bad character before the `@`                     | `http://us er@a/`       |
| `invalid-reg-name`    | a bad character in a host name                     | `http://a b/`           |
| `invalid-ip-literal`  | a bad address in `[...]`                           | `http://[::g]/`         |
| `invalid-dec-octet`   | an IPv4 number over 255 in `[...]`                 | `http://[::1.2.3.999]/` |
| `invalid-port`        | a port that is not digits                          | `http://a:8x/`          |
| `invalid-pchar`       | a bad character in the path                        | `http://a/b c`          |
| `invalid-query`       | a bad character in the query                       | `http://a?b c`          |
| `invalid-fragment`    | a bad character in the fragment                    | `http://a#b c`          |
| `invalid-pct-encoded` | a `%` not followed by two hex digits               | `http://a/%zz`          |
| `invalid-utf-8`       | decoding gave bytes that are not UTF-8             | `uri-decode` of `%FF`   |
| `base-not-absolute`   | `uri-resolve` got a base with no scheme            | base `/a`               |
| `ambiguous-components`| `components->uri` got parts that would parse back as something else | path `a:b`, no scheme |

Here is each example, run:

```scheme
(import (rnrs) (uri easy) (uri components))

(define-syntax try
  (syntax-rules ()
    ((_ label expr)
     (guard (e ((uri-error? e)
                (display label) (display " => ")
                (display (uri-error-reason e)) (display " at ")
                (display (uri-error-offset e)) (newline)))
       expr))))

(for-each (lambda (s) (try s (string->uri s)))
          '("/a" "http" "1http://a" "http://us er@a/" "http://a b/"
            "http://[::g]/" "http://[::1.2.3.999]/" "http://a:8x/"
            "http://a/b c" "http://a?b c" "http://a#b c" "http://a/%zz"))
(try "relative-ref http://a" (string->relative-ref "http://a"))
(try "decode %FF" (uri-decode "%FF"))
(try "resolve against /a" (uri-resolve "/a" "b"))
(try "path a:b" (components->uri (make-uri-components #f #f (string->utf8 "a:b") #f #f)))
```

```text
/a => scheme-required at 0
http => scheme-required at 4
1http://a => invalid-scheme at 0
http://us er@a/ => invalid-userinfo at 9
http://a b/ => invalid-reg-name at 8
http://[::g]/ => invalid-ip-literal at 7
http://[::1.2.3.999]/ => invalid-dec-octet at 7
http://a:8x/ => invalid-port at 10
http://a/b c => invalid-pchar at 10
http://a?b c => invalid-query at 10
http://a#b c => invalid-fragment at 10
http://a/%zz => invalid-pct-encoded at 9
relative-ref http://a => scheme-forbidden at 4
decode %FF => invalid-utf-8 at 0
resolve against /a => base-not-absolute at 0
path a:b => ambiguous-components at 0
```

A fault inside `[...]` is reported at the `[`. `base-not-absolute` and
`ambiguous-components` point at 0: the whole input is at fault.

`http` has no `:`, so it has no scheme, and the error is `scheme-required`
at the end of the input. That is how a URI that stops short usually fails.
`unexpected-eof` is the code byte-machine gives any scanner for input that
ends partway through something; uriparse's scanner lets input end wherever
a part can, so you meet the other codes instead.

### Wrong arguments

Passing the wrong type, such as a number where a string belongs, is a
programming mistake, not bad input. It raises an R6RS assertion violation
that names the procedure:

```scheme
(guard (e ((assertion-violation? e) (condition-who e)))
  (string->uri 42))
;; => string->uri
```

## The byte layer

A result from `uri-parse`, `uri-parse-validate` or the authority-form parsers
carries the code and a byte offset into your input:

```scheme
(uri-parse-error-code (uri-parse 'relative-ref (string->utf8 "http://a")))
;; => scheme-forbidden
(uri-parse-error-offset (uri-parse 'relative-ref (string->utf8 "http://a")))
;; => 4
```

The codes come in four groups, each with a list and a predicate.

**The scanner's**, from splitting the URI, in `(uri vocabulary)`:

```scheme
uri-error-codes
;; => (mode-unset scheme-required scheme-forbidden unexpected-eof)
```

`mode-unset` means no mode was chosen. You only meet it if you drive the
scanner yourself: `(uri collect)` always sets one.

**The character checks'**, from validating a scheme, path, query or fragment,
in `(uri charset)`:

```scheme
uri-charset-error-codes
;; => (invalid-scheme invalid-pchar invalid-query invalid-fragment invalid-pct-encoded)
```

**The authority checks'**, from validating userinfo, host and port, in
`(uri host)`:

```scheme
uri-host-error-codes
;; => (invalid-userinfo invalid-reg-name invalid-ip-literal invalid-dec-octet invalid-port invalid-pct-encoded)
```

**The authority-form's**, from a `CONNECT` target, in `(uri collect)`:

```scheme
uri-authority-form-error-codes
;; => (not-authority-form userinfo-forbidden port-required)
```

`invalid-pct-encoded` is in two groups, because a bad `%` can be in any part.
The predicates ask whether a symbol is in a group:

```scheme
(uri-error-code? 'unexpected-eof)
;; => #t
(uri-charset-error-code? 'invalid-port)
;; => #f
(uri-host-error-code? 'invalid-port)
;; => #t
(uri-authority-form-error-code? 'port-required)
;; => #t
```

`validate-component` and `validate-authority` return a code from their group
and an index counted from the `start` you gave them, not from the start of
the input. See [Validating](validating.md#check-one-part-in-place).

## Mistakes in your own code

These raise, because they are bugs in the calling program, not bad input.

A part of `make-uri-components` that is not a bytevector or `#f`, such as a
string, raises a `uri-components-error`:

```scheme
(guard (e ((uri-components-error? e) (uri-components-error-detail e)))
  (make-uri-components "http" #f (string->utf8 "/") #f #f))
;; => "the scheme component must be a bytevector or #f"
```

A mode that does not exist raises a `uri-vocabulary-error`:

```scheme
(guard (e ((uri-vocabulary-error? e) (uri-vocabulary-error-detail e)))
  (uri-parse 'url (string->utf8 "http://a")))
;; => "no URI parse mode named url"
```

A `start` and `end` that do not fit the bytevector raise an assertion
violation, rather than checking some other range:

```scheme
(guard (e ((assertion-violation? e) (condition-who e)))
  (validate-component 'path (string->utf8 "/a") 0 9))
;; => validate-component
```
