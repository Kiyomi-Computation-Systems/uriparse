#!r6rs
;;; (uri recompose): RFC 3986 §5.3 component recomposition -- the five-field
;;; `uri-components` back to a URI-reference bytevector.
;;;
;;; This is the last step of §5.2.2 reference resolution (a resolved target is
;;; returned "by recomposing ... using the algorithm of Section 5.3"), which is
;;; why it lives beside `(uri resolve)`. It is also the renderer the
;;; parse/recompose round-trip property runs through.
;;;
;;; DEFINED, NOT NONEMPTY. §5.3 guards each delimiter on
;;; `defined()`, so a component that is present-but-empty still emits its
;;; separator: an empty-but-present authority still emits `//` (`http://` vs
;;; `http:`), an empty-but-present query still emits `?` (`http://a?` vs
;;; `http://a`). A `uri-components` field carries that distinction as bytevector
;;; (defined) vs `#f` (undefined), so a plain truthy test on the field IS the
;;; §5.3 `defined()` test. The path is emitted whenever
;;; present -- it always is, for components the scanner produces -- and may be
;;; empty; a `#f` path (which the scanner never emits) is skipped
;;; rather than crashing, so recompose is total where `(uri resolve)`, which
;;; assumes a present path per §5.2.2, is not.
;;;
;;; recompose : Components -> Bytevector
(library (uri recompose)
  (export recompose)
  (import (rnrs)
          (uri components))

  (define COLON 58)                         ; #\:
  (define SLASH 47)                         ; #\/
  (define QUESTION 63)                      ; #\?
  (define HASH 35)                          ; #\#

  ;; recompose : Components -> Bytevector
  ;; §5.3, in the RFC's order: scheme ":" | "//" authority | path | "?" query |
  ;; "#" fragment. Each optional part is guarded by the field being defined (a
  ;; bytevector, not `#f`); the path is always appended. Total: it never rejects.
  (define (recompose c)
    (let ((scheme    (uri-components-scheme c))
          (authority (uri-components-authority c))
          (path      (uri-components-path c))
          (query     (uri-components-query c))
          (fragment  (uri-components-fragment c)))
      (call-with-bytevector-output-port
       (lambda (out)
         (when scheme
           (put-bytevector out scheme)
           (put-u8 out COLON))
         (when authority
           (put-u8 out SLASH) (put-u8 out SLASH)
           (put-bytevector out authority))
         (when path
           (put-bytevector out path))
         (when query
           (put-u8 out QUESTION)
           (put-bytevector out query))
         (when fragment
           (put-u8 out HASH)
           (put-bytevector out fragment)))))))
