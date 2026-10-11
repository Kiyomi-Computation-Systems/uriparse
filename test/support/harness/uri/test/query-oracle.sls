#!r6rs
;;; (uri test query-oracle): the query key/value split, derived from its rules
;;; INDEPENDENTLY of the src library it grades.
;;;
;;; ORACLE DISCIPLINE. `(uri query)` is graded against this library, so it is
;;; written from the split's rules, not from the product, and shares none of its
;;; code: it imports only `(rnrs)` (not `(uri percent)`), works over LISTS of
;;; octets where the product indexes bytevectors, and decodes `%XX` with its own
;;; hex reading. Two implementations of one property that agree on every input
;;; of a swept space are the check; the hand-derived vector table, which both
;;; must satisfy, is the third reading that guards a blind spot they could share.
;;;
;;; THE RULES, in the order they apply:
;;;   1. split on `&` only, and drop every empty piece;
;;;   2. split each piece at its FIRST `=`: the key is before it, the value after
;;;      it, and a piece with no `=` has an absent value (#f);
;;;   3. form reading only: every `+` in the raw key and value becomes a space;
;;;   4. percent-decode the key and the value: a `%` followed by two hex digits is
;;;      that octet, and any other `%` is itself.
;;;
;;; PURE.
(library (uri test query-oracle)
  (export oracle-query-pairs oracle-form-pairs)
  (import (rnrs))

  (define AMP (char->integer #\&))
  (define EQ (char->integer #\=))
  (define PLUS (char->integer #\+))
  (define SPACE (char->integer #\space))
  (define PCT (char->integer #\%))

  ;; split-on : Octet (Listof Octet) -> (Listof (Listof Octet))
  ;; Every run between occurrences of `sep`, empty runs included.
  (define (split-on sep octets)
    (let loop ((rest octets) (run '()) (runs '()))
      (cond ((null? rest) (reverse (cons (reverse run) runs)))
            ((= (car rest) sep) (loop (cdr rest) '() (cons (reverse run) runs)))
            (else (loop (cdr rest) (cons (car rest) run) runs)))))

  ;; at-first : Octet (Listof Octet) -> (values (Listof Octet) (Option (Listof Octet)))
  ;; The octets before the first `sep`, and those after it, or #f when there is none.
  (define (at-first sep octets)
    (let loop ((rest octets) (before '()))
      (cond ((null? rest) (values (reverse before) #f))
            ((= (car rest) sep) (values (reverse before) (cdr rest)))
            (else (loop (cdr rest) (cons (car rest) before))))))

  ;; hex : Octet -> (Option (Integer 0 15)), from the ASCII ranges 0-9, A-F, a-f.
  (define (hex o)
    (cond ((and (>= o (char->integer #\0)) (<= o (char->integer #\9)))
           (- o (char->integer #\0)))
          ((and (>= o (char->integer #\A)) (<= o (char->integer #\F)))
           (+ 10 (- o (char->integer #\A))))
          ((and (>= o (char->integer #\a)) (<= o (char->integer #\f)))
           (+ 10 (- o (char->integer #\a))))
          (else #f)))

  ;; decode : (Listof Octet) -> (Listof Octet)
  (define (decode octets)
    (cond ((null? octets) '())
          ((and (= (car octets) PCT)
                (pair? (cdr octets)) (pair? (cddr octets))
                (hex (cadr octets)) (hex (caddr octets)))
           (cons (+ (* 16 (hex (cadr octets))) (hex (caddr octets)))
                 (decode (cdddr octets))))
          (else (cons (car octets) (decode (cdr octets))))))

  (define (plus->space octets)
    (map (lambda (o) (if (= o PLUS) SPACE o)) octets))

  ;; pairs : Bytevector Boolean -> (Listof (Pairof Bytevector (Option Bytevector)))
  (define (pairs bv form?)
    (let ((prep (lambda (octets)
                  (u8-list->bytevector (decode (if form? (plus->space octets) octets))))))
      (map (lambda (piece)
             (let-values (((key value) (at-first EQ piece)))
               (cons (prep key) (and value (prep value)))))
           (filter pair? (split-on AMP (bytevector->u8-list bv))))))

  ;; oracle-query-pairs : Bytevector -> (Listof (Pairof Bytevector (Option Bytevector)))
  (define (oracle-query-pairs bv) (pairs bv #f))

  ;; oracle-form-pairs : Bytevector -> (Listof (Pairof Bytevector (Option Bytevector)))
  (define (oracle-form-pairs bv) (pairs bv #t)))
