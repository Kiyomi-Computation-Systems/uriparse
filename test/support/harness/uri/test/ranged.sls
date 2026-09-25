#!r6rs
;;; (uri test ranged): the techniques the ranged-judge checks share (decisions
;;; 0034, 0036). unit.charset and unit.host each grade a judge over [start, end)
;;; of a larger bytevector. What keeps those checks honest lives here ONCE, so a
;;; fix to one lane's technique reaches the other:
;;;
;;;   - a judge returns TWO values, and two values into check-raises raise on
;;;     their own (an &assertion, whatever the range): `results-of` hands a check
;;;     ONE value, the list of results;
;;;   - a primitive's own bounds or fixnum check is an &assertion too, so a
;;;     refusal is identified by WHO raised it: `raised-by?`;
;;;   - a collection firing inside a measurement window adds its own bookkeeping
;;;     to that window alone, so a measure is the least of three: `least-allocation`;
;;;   - a span is placed among hostile bytes, so reading outside it shows:
;;;     `for-each-placement`.
(library (uri test ranged)
  (export results-of raised-by? least-allocation for-each-placement)
  (import (rnrs) (only (uri test harness) adapter-bytes-allocated))

  ;; results-of : (Any ... -> Any ...) Any ... -> (Listof Any)
  ;; Every value (proc arg ...) returns, as one list.
  (define (results-of proc . args)
    (call-with-values (lambda () (apply proc args)) list))

  ;; raised-by? : Symbol -> (Any -> Boolean)
  ;; A predicate true of an assertion violation whose who is `who`.
  (define (raised-by? who)
    (lambda (c)
      (and (assertion-violation? c) (who-condition? c)
           (eq? (condition-who c) who))))

  ;; least-allocation : Nat (-> Any ...) -> Nat
  ;; Bytes allocated by `reps` calls of thunk, after one warm call: the least of
  ;; three windows.
  (define (least-allocation reps thunk)
    (define (window)
      (let ((before (adapter-bytes-allocated)))
        (do ((i 0 (+ i 1))) ((= i reps))
          (thunk))
        (- (adapter-bytes-allocated) before)))
    (thunk)
    (min (window) (window) (window)))

  ;; for-each-placement :
  ;;   (Listof (Pairof String String)) String
  ;;   ((Pairof String String) Bytevector Nat Nat -> Any) -> unspecified
  ;; For each surrounding (prefix . suffix), calls (proc around buf start end):
  ;; buf is prefix ++ s ++ suffix as UTF-8, and [start, end) holds exactly s.
  (define (for-each-placement surroundings s proc)
    (for-each
     (lambda (around)
       (let* ((start (bytevector-length (string->utf8 (car around))))
              (end (+ start (bytevector-length (string->utf8 s)))))
         (proc around (string->utf8 (string-append (car around) s (cdr around)))
               start end)))
     surroundings)))
