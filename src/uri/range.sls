#!r6rs
;;; (uri range): the [start, end) contract every ranged judge shares (decisions
;;; 0034, 0036). (uri charset)'s validate-component and (uri host)'s
;;; validate-authority / authority-host-span each judge bv[start, end) of a larger
;;; bytevector in place. This is the ONE statement of which ranges they accept, so
;;; no two judges can come to refuse different ones. PURE.
(library (uri range)
  (export check-range)
  (import (rnrs))

  ;; check-range : Symbol Bytevector Any Any -> unspecified
  ;;
  ;; Returns when start and end are fixnums with 0 <= start <= end <= the length of
  ;; bv. Otherwise raises an assertion violation whose who is `who` (the judge the
  ;; caller called), with start and end as irritants. A bad range is refused, never
  ;; clamped: a clamped range would judge bytes the caller did not name.
  (define (check-range who bv start end)
    (unless (and (fixnum? start) (fixnum? end)
                 (fx<=? 0 start) (fx<=? start end) (fx<=? end (bytevector-length bv)))
      (assertion-violation who "not a range within the bytevector" start end))))
