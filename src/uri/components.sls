#!r6rs
;;; (uri components): the seam type between the scanner and the core.
;;;
;;; Five fields -- scheme, authority, path, query, fragment -- each a bytevector
;;; OR `#f` (decision 0008 item 7). These are RFC 3986 §5.3's recomposition
;;; components and §5.2.2's resolution inputs, the granularity the pure core
;;; operates on; the scanner's finer userinfo/host/port spans are folded into
;;; `authority` by `(uri collect)`.
;;;
;;; ABSENT IS NOT EMPTY. `#f` is absent; a zero-length bytevector is present and
;;; empty. RFC 3986 §5.3 recomposes on *defined*, not on *nonempty*
;;; (`if defined(query) then append "?" + query`), and §5.2.2 branches the same
;;; way: `http://a` and `http://a?` are different URIs, and `http:/p` (no
;;; authority) and `http:///p` (an empty authority) resolve differently. A type
;;; that conflated the two could not implement §5, so this one never does, and
;;; `(uri collect)` is the only place the distinction is constructed.
;;;
;;; This library is pure R6RS and imports only `(rnrs)`. It holds bytevectors,
;;; never strings: a URI is a byte string, and staying in bytevectors keeps
;;; `(rnrs unicode)`'s length-changing case fold structurally out of reach
;;; (design §5, decision 0010).
(library (uri components)
  (export
    make-uri-components uri-components?
    uri-components-scheme uri-components-authority uri-components-path
    uri-components-query uri-components-fragment
    ;; the absent/empty distinction, as predicates over one field value
    uri-component-absent? uri-component-present?
    uri-component-empty? uri-component-present-nonempty?
    ;; structural equality that keeps absent /= empty
    uri-components=?
    ;; refusal
    uri-components-error? uri-components-error-detail)
  (import (rnrs))

  (define-condition-type &uri-components &error
    make-uri-components-error uri-components-error?
    (detail uri-components-error-detail))

  ;; A field is a bytevector or `#f` and nothing else. A string slipping in is
  ;; the plausible mistake -- the scanner delivers bytes, and a caller reaching
  ;; for `utf8->string` at the wrong seam would produce one -- and it must be
  ;; refused at construction, not discovered later when the core compares bytes
  ;; to a string and silently never matches.
  (define (check-field who name value)
    (unless (or (not value) (bytevector? value))
      (raise (condition
              (make-uri-components-error
               (string-append "the " name
                              " component must be a bytevector or #f"))
              (make-who-condition who)))))

  (define-record-type uri-components
    (fields scheme authority path query fragment)
    (protocol
     (lambda (new)
       (lambda (scheme authority path query fragment)
         (check-field 'make-uri-components "scheme" scheme)
         (check-field 'make-uri-components "authority" authority)
         (check-field 'make-uri-components "path" path)
         (check-field 'make-uri-components "query" query)
         (check-field 'make-uri-components "fragment" fragment)
         (new scheme authority path query fragment)))))

  ;; --- the absent/empty distinction, over one field value -----------------

  ;; uri-component-absent? : (Option Bytevector) -> Boolean
  (define (uri-component-absent? v) (not v))

  ;; uri-component-present? : (Option Bytevector) -> Boolean
  (define (uri-component-present? v) (bytevector? v))

  ;; uri-component-empty? : (Option Bytevector) -> Boolean
  ;; Present AND zero-length. `#f` is NOT empty -- it is absent -- so this is
  ;; false for `#f`, which is the whole point of the type.
  (define (uri-component-empty? v)
    (and (bytevector? v) (= (bytevector-length v) 0)))

  ;; uri-component-present-nonempty? : (Option Bytevector) -> Boolean
  (define (uri-component-present-nonempty? v)
    (and (bytevector? v) (> (bytevector-length v) 0)))

  ;; --- structural equality ------------------------------------------------
  ;;
  ;; Field by field, with absent (`#f`) distinct from empty (`#vu8()`): two
  ;; components are equal only where each field agrees on presence AND bytes.
  ;; `bytevector=?` is never handed `#f`, so presence is compared first.
  (define (field=? a b)
    (cond ((and (not a) (not b)) #t)
          ((and (bytevector? a) (bytevector? b)) (bytevector=? a b))
          (else #f)))

  ;; uri-components=? : Components Components -> Boolean
  (define (uri-components=? a b)
    (and (uri-components? a) (uri-components? b)
         (field=? (uri-components-scheme a)    (uri-components-scheme b))
         (field=? (uri-components-authority a) (uri-components-authority b))
         (field=? (uri-components-path a)      (uri-components-path b))
         (field=? (uri-components-query a)     (uri-components-query b))
         (field=? (uri-components-fragment a)  (uri-components-fragment b)))))
