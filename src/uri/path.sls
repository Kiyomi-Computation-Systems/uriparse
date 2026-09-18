#!r6rs
;;; (uri path): the two path routines RFC 3986 §5.2 resolution refers to, as
;;; pure functions over path bytevectors (decision 0010).
;;;
;;;   remove-dot-segments  §5.2.4  interpret and remove "." and ".." segments
;;;   merge                §5.2.3  splice a relative reference onto a base path
;;;
;;; A path is opaque bytes here: `/` is not in `pchar`, so segmentation is a
;;; total function of the path bytes and belongs in the core (design §3.1). No
;;; scanner, no components -- these two functions are what `(uri resolve)`
;;; (§5.2.2) calls, and they operate on the `path` bytevector alone.
;;;
;;; TOTAL, and non-validating (decision 0011): every byte string is a path; a
;;; malformed one is simply moved through §5.2.4's case E like any other segment.
;;; No `(rnrs unicode)`; `/` and `.` are ASCII bytes.
;;;
;;; remove-dot-segments : Bytevector -> Bytevector
;;; remove-dot-segments-trace : Bytevector -> (List (List String Bytevector Bytevector))
;;; merge : Boolean Bytevector Bytevector -> Bytevector
(library (uri path)
  (export remove-dot-segments remove-dot-segments-trace merge)
  (import (rnrs))

  (define SLASH 47)                         ; #\/
  (define DOT 46)                           ; #\.

  (define empty-bv (make-bytevector 0))
  (define slash-bv (let ((b (make-bytevector 1))) (bytevector-u8-set! b 0 SLASH) b))

  ;; The four literal prefixes §5.2.4 tests for, built once.
  (define (bytes . lst) (u8-list->bytevector lst))
  (define dotslash-bv        (bytes DOT SLASH))            ; "./"
  (define dotdotslash-bv     (bytes DOT DOT SLASH))        ; "../"
  (define slashdot-bv        (bytes SLASH DOT))            ; "/."
  (define slashdotslash-bv   (bytes SLASH DOT SLASH))      ; "/./"
  (define slashdotdot-bv     (bytes SLASH DOT DOT))        ; "/.."
  (define slashdotdotslash-bv(bytes SLASH DOT DOT SLASH))  ; "/../"
  (define dot-bv             (bytes DOT))                  ; "."
  (define dotdot-bv          (bytes DOT DOT))              ; ".."

  ;; bv-prefix? : Bytevector Bytevector -> Boolean
  ;; Does `bv` begin with the whole of `pat`?
  (define (bv-prefix? bv pat)
    (let ((n (bytevector-length bv)) (m (bytevector-length pat)))
      (and (fx>=? n m)
           (let loop ((i 0))
             (or (fx=? i m)
                 (and (fx=? (bytevector-u8-ref bv i) (bytevector-u8-ref pat i))
                      (loop (fx+ i 1))))))))

  ;; bv-drop : Bytevector Fixnum -> Bytevector
  ;; A fresh copy of `bv` from index `k` to the end.
  (define (bv-drop bv k)
    (let* ((n (bytevector-length bv)) (out (make-bytevector (fx- n k))))
      (let loop ((i k))
        (if (fx<? i n)
            (begin (bytevector-u8-set! out (fx- i k) (bytevector-u8-ref bv i))
                   (loop (fx+ i 1)))
            out))))

  ;; bv-take : Bytevector Fixnum -> Bytevector
  ;; A fresh copy of `bv` from 0 up to (not including) index `k`.
  (define (bv-take bv k)
    (let ((out (make-bytevector k)))
      (let loop ((i 0))
        (if (fx<? i k)
            (begin (bytevector-u8-set! out i (bytevector-u8-ref bv i))
                   (loop (fx+ i 1)))
            out))))

  ;; bv-append : Bytevector Bytevector -> Bytevector
  (define (bv-append a b)
    (let* ((na (bytevector-length a)) (nb (bytevector-length b))
           (out (make-bytevector (fx+ na nb))))
      (bytevector-copy! a 0 out 0 na)
      (bytevector-copy! b 0 out na nb)
      out))

  ;; next-slash : Bytevector Fixnum -> Fixnum
  ;; The index of the first `/` at or after `from`, or the length if none.
  (define (next-slash bv from)
    (let ((n (bytevector-length bv)))
      (let loop ((i from))
        (cond ((fx=? i n) n)
              ((fx=? (bytevector-u8-ref bv i) SLASH) i)
              (else (loop (fx+ i 1)))))))

  ;; last-slash : Bytevector -> Fixnum
  ;; The index of the last `/`, or -1 if there is none.
  (define (last-slash bv)
    (let loop ((i (fx- (bytevector-length bv) 1)))
      (cond ((fx<? i 0) -1)
            ((fx=? (bytevector-u8-ref bv i) SLASH) i)
            (else (loop (fx- i 1))))))

  ;; drop-last-segment : Bytevector -> Bytevector
  ;; §5.2.4 case 2C's output action: remove the last segment and its preceding
  ;; `/` -- i.e. everything from the rightmost `/` onward. With no `/` ("if any"),
  ;; the whole buffer goes.
  (define (drop-last-segment out)
    (let ((k (last-slash out)))
      (if (fx<? k 0) empty-bv (bv-take out k))))

  ;; take-first-segment : Bytevector -> (values Bytevector Bytevector)
  ;; §5.2.4 case E: the first segment (its leading `/`, if any, then bytes up to
  ;; but not including the next `/` or the end) and the remainder. Searching from
  ;; index 1 skips a leading `/` so it is kept with the segment, not treated as
  ;; the terminator of an empty one.
  (define (take-first-segment in)
    (let ((k (next-slash in 1)))
      (values (bv-take in k) (bv-drop in k))))

  ;; step : Bytevector Bytevector -> (values String Bytevector Bytevector)
  ;; One iteration of §5.2.4's loop over (output, input): the case label and the
  ;; two buffers after it. The order is the RFC's -- A before B before C before D
  ;; before E -- and the "complete path segment" qualifier on B's "/." and C's
  ;; "/.." is enforced by matching them only as the whole input (a trailing `/`
  ;; makes them the "/./" and "/../" forms instead). Replacing "/./" with "/" is
  ;; a two-byte drop and "/../" with "/" a three-byte drop, because the prefix's
  ;; trailing `/` becomes the result's leading one.
  (define (step out in)
    (cond
     ;; A: "../" or "./" -> drop the prefix (no output change)
     ((bv-prefix? in dotdotslash-bv) (values "2A" out (bv-drop in 3)))
     ((bv-prefix? in dotslash-bv)    (values "2A" out (bv-drop in 2)))
     ;; B: "/./" or a complete "/." -> replace prefix with "/"
     ((bv-prefix? in slashdotslash-bv) (values "2B" out (bv-drop in 2)))
     ((bytevector=? in slashdot-bv)    (values "2B" out slash-bv))
     ;; C: "/../" or a complete "/.." -> replace with "/", pop a segment off output
     ((bv-prefix? in slashdotdotslash-bv)
      (values "2C" (drop-last-segment out) (bv-drop in 3)))
     ((bytevector=? in slashdotdot-bv)
      (values "2C" (drop-last-segment out) slash-bv))
     ;; D: the input is exactly "." or ".." -> drop it
     ((bytevector=? in dot-bv)    (values "2D" out empty-bv))
     ((bytevector=? in dotdot-bv) (values "2D" out empty-bv))
     ;; E: move the first segment from input to output
     (else (let-values (((seg rest) (take-first-segment in)))
             (values "2E" (bv-append out seg) rest)))))

  ;; remove-dot-segments-trace : Bytevector -> (List (List String Bytevector Bytevector))
  ;; The full §5.2.4 run as the RFC's worked examples present it: one row per
  ;; step, each `(label output input)` giving the buffers AFTER that step. The
  ;; first row is step "1" (initialisation: empty output, the whole path as
  ;; input); the last carries the result and an empty input. This is what the
  ;; §5.2.4 step-trace corpus grades, so a wrong algorithm that stumbles onto the
  ;; right end result by the wrong steps still reddens.
  (define (remove-dot-segments-trace path)
    (let loop ((out empty-bv) (in path) (rows (list (list "1" empty-bv path))))
      (if (fx=? (bytevector-length in) 0)
          (reverse rows)
          (let-values (((label out* in*) (step out in)))
            (loop out* in* (cons (list label out* in*) rows))))))

  ;; remove-dot-segments : Bytevector -> Bytevector
  ;; §5.2.4's result: the output buffer once the input is exhausted. The
  ;; consumer-facing entry; `(uri resolve)` calls this.
  (define (remove-dot-segments path)
    (let loop ((out empty-bv) (in path))
      (if (fx=? (bytevector-length in) 0)
          out
          (let-values (((label out* in*) (step out in)))
            (loop out* in*)))))

  ;; merge : Boolean Bytevector Bytevector -> Bytevector
  ;; §5.2.3, splicing a relative reference's path onto the base path. Two
  ;; branches, exactly as the RFC writes them:
  ;;   (a) base has a defined authority AND an empty path -> "/" ++ ref-path;
  ;;   (b) otherwise -> (base path up to and including its rightmost "/") ++
  ;;       ref-path, or just ref-path when the base path has no "/".
  ;; `base-has-authority?` is whether the base's authority component is DEFINED
  ;; (decision 0008: present, even if empty) -- the caller reads it off the base
  ;; components, since a bare path cannot carry that fact.
  (define (merge base-has-authority? base-path ref-path)
    (if (and base-has-authority? (fx=? (bytevector-length base-path) 0))
        (bv-append slash-bv ref-path)
        (let ((k (last-slash base-path)))
          (if (fx<? k 0)
              ref-path
              (bv-append (bv-take base-path (fx+ k 1)) ref-path))))))
