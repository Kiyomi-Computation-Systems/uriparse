#!r6rs
;;; (uri query): a query's key/value pairs, split over its bytes.
;;;
;;; RFC 3986 gives the query no internal structure: `&` and `=` are sub-delims,
;;; ordinary bytes, and the scanner rightly returns the whole query as one
;;; component. The `key=value&...` reading is HTML's
;;; application/x-www-form-urlencoded convention. This library is that reading,
;;; as a separate split over an already-isolated query, the way (uri host)
;;; sub-splits the authority. Nothing else in the library interprets a query.
;;;
;;; SPLIT, THEN DECODE. The query is split on literal `&` and `=` first, and each
;;; piece is percent-decoded after. Decoding first would turn `%26` into a live
;;; `&`: `q=a%26b` is one pair whose value is `a&b`, not two pairs.
;;;
;;; THE RULES:
;;;   - `&` is the only separator; `;` is a byte like any other.
;;;   - Empty pieces are skipped, so `a&&b` is two pairs and an empty query none.
;;;   - A piece splits at its FIRST `=`: `a=b=c` is ("a" . "b=c").
;;;   - A piece with no `=` has an ABSENT value, #f, distinct from the empty value
;;;     of `a=`: absent is not empty, as for components.
;;;   - Order and duplicates are kept: `a=1&a=2` is two pairs, in input order.
;;; `form-pairs` also reads `+` as a space, on the raw bytes BEFORE decoding, so
;;; an encoded `%2B` stays a literal `+`. `query-pairs` leaves `+` alone: in
;;; RFC 3986 it is a sub-delim, not a space.
;;;
;;; TOTAL. Every bytevector splits; nothing is rejected. Charset is
;;; (uri charset)'s question, and a decoded value is returned as the bytes it
;;; decodes to, whatever they are: whether they are UTF-8 is the caller's
;;; question. Every returned bytevector is fresh. Pure R6RS.
(library (uri query)
  (export query-pairs form-pairs)
  (import (rnrs) (uri percent))

  (define AMPERSAND 38)                     ; #\&
  (define EQUALS 61)                        ; #\=
  (define PLUS 43)                          ; #\+
  (define SPACE 32)                         ; #\space

  ;; slice : Bytevector Nat Nat -> Bytevector, a fresh copy of [s, e).
  (define (slice bv s e)
    (let ((out (make-bytevector (fx- e s))))
      (bytevector-copy! bv s out 0 (fx- e s))
      out))

  ;; find-byte : Bytevector Nat Nat Octet -> Nat
  ;; The index of the first `b` in [s, e), or `e` when there is none.
  (define (find-byte bv s e b)
    (let loop ((i s))
      (cond ((fx=? i e) e)
            ((fx=? (bytevector-u8-ref bv i) b) i)
            (else (loop (fx+ i 1))))))

  ;; plus->space : Bytevector -> Bytevector
  ;; A fresh copy with every `+` rewritten to a space. The argument is never
  ;; written, so it does not matter whose bytes `split` hands over.
  (define (plus->space bv)
    (let ((out (bytevector-copy bv)))
      (let loop ((i 0))
        (when (fx<? i (bytevector-length out))
          (when (fx=? (bytevector-u8-ref out i) PLUS)
            (bytevector-u8-set! out i SPACE))
          (loop (fx+ i 1))))
      out))

  ;; piece : Bytevector Nat Nat (Bytevector -> Bytevector)
  ;;         -> (Pairof Bytevector (Option Bytevector))
  ;; One non-empty piece [s, e), split at its first `=`, each side decoded.
  (define (piece bv s e decode)
    (let ((eq (find-byte bv s e EQUALS)))
      (cons (decode (slice bv s eq))
            (and (fx<? eq e) (decode (slice bv (fx+ eq 1) e))))))

  ;; split : Bytevector (Bytevector -> Bytevector)
  ;;         -> (Listof (Pairof Bytevector (Option Bytevector)))
  ;; The pieces between `&`s, in order, skipping empty ones. `decode` receives
  ;; each raw key and value as a fresh slice, after the split.
  (define (split bv decode)
    (let ((n (bytevector-length bv)))
      (let loop ((s 0) (acc '()))
        (if (fx>=? s n)
            (reverse acc)
            (let ((e (find-byte bv s n AMPERSAND)))
              (loop (fx+ e 1)
                    (if (fx=? e s)
                        acc
                        (cons (piece bv s e decode) acc))))))))

  ;; query-pairs : Bytevector -> (Listof (Pairof Bytevector (Option Bytevector)))
  ;; The query's pairs, each key and value percent-decoded; `+` is literal.
  (define (query-pairs bv) (split bv pct-decode))

  ;; form-pairs : Bytevector -> (Listof (Pairof Bytevector (Option Bytevector)))
  ;; As `query-pairs`, but `+` reads as a space, before decoding.
  (define (form-pairs bv)
    (split bv (lambda (raw) (pct-decode (plus->space raw))))))
