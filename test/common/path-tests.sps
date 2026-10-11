#!r6rs
;;; unit.path -- the two §5.2 path routines: remove-dot-segments (§5.2.4) and
;;; merge (§5.2.3), the mechanics `(uri resolve)` (§5.2.2) is built on.
;;;
;;; remove-dot-segments is graded TWO ways. Its final result is pinned on stress
;;; vectors derived from the RFC (independently of this code). And its full STEP
;;; TRACE is graded against the committed §5.2.4 corpus (dot-segments.scm) --
;;; buffer states after every named step -- because the RFC gives the two worked
;;; examples as traces, "not only as the two end results: the end result of the
;;; first is reachable by several wrong algorithms and the trace is not"
;;; (PROVENANCE). A resolver that reaches "/a/g" by the wrong 2A/2B/2C/2D/2E
;;; sequence still reddens.
;;;
;;; merge is pinned on the six RFC-derived branch vectors: both branches, the
;;; empty-base-path authority case, and the no-slash base-path edge.
(import (rnrs)
        (uri test harness)
        (uri test corpus)
        (uri path))

;; `a` builds a bytevector from an ASCII string; `s` reads one back. A path is
;; bytes; the ASCII spelling is the reader's convenience, and the
;; corpus rows are strings, so the trace comparison reads bytevectors back out.
(define (a str) (string->utf8 str))
(define (s bv) (utf8->string bv))
(define (bytes . lst) (u8-list->bytevector lst))

(define (corpus-path name)
  (string-append (adapter-environment-variable "URI_CORPUS_DIR") "/" name))

(harness-begin "unit.path")

;;; --- remove-dot-segments: the §5.2.4 result on RFC-derived stress vectors ----
;;; Each expected output is worked by hand from §5.2.4's case table, chosen to
;;; press on a load-bearing distinction the two committed traces do not reach.
(harness-group "remove-dot-segments result"
  (lambda ()
    (harness-case "no dot-segments: the path is copied through"
      (lambda ()
        (check-equal "empty"      (remove-dot-segments (a ""))        (a ""))
        (check-equal "/a/b/c"     (remove-dot-segments (a "/a/b/c"))  (a "/a/b/c"))
        (check-equal "a/b/c"      (remove-dot-segments (a "a/b/c"))   (a "a/b/c"))))

    ;; 2C must tolerate an empty output buffer: "/../" pops nothing (the RFC's
    ;; "(if any)") and still rewrites the input to "/", so the result is "/", not
    ;; "" and not an underflow.
    (harness-case "a leading up-level on a rooted path pops what it can, no more"
      (lambda ()
        (check-equal "/../"   (remove-dot-segments (a "/../"))   (a "/"))
        (check-equal "/.."    (remove-dot-segments (a "/.."))    (a "/"))
        (check-equal "/a/.."  (remove-dot-segments (a "/a/.."))  (a "/"))))

    ;; 2B: "/./" and a complete "/." both collapse to "/".
    (harness-case "a same-level dot-segment collapses"
      (lambda ()
        (check-equal "/."      (remove-dot-segments (a "/."))      (a "/"))
        (check-equal "a/./b"   (remove-dot-segments (a "a/./b"))   (a "a/b"))
        (check-equal "/a/./b"  (remove-dot-segments (a "/a/./b"))  (a "/a/b"))))

    ;; 2A vs 2D: a leading "../" or "./" is stripped and NOT emitted (2A, output
    ;; untouched); a bare "." or ".." is the whole input and is dropped (2D).
    (harness-case "leading relative dot-segments are discarded, not emitted"
      (lambda ()
        (check-equal "../g"   (remove-dot-segments (a "../g"))   (a "g"))
        (check-equal "./g"    (remove-dot-segments (a "./g"))    (a "g"))
        (check-equal "."      (remove-dot-segments (a "."))      (a ""))
        (check-equal ".."     (remove-dot-segments (a ".."))     (a ""))))

    ;; The "complete path segment" qualifier: "/.foo" and "/..bar" are ordinary
    ;; dot-PREFIXED segments, moved verbatim by 2E -- never mistaken for "/./"
    ;; or "/../".
    (harness-case "a dot-prefixed filename is a segment, not a dot-segment"
      (lambda ()
        (check-equal "/.foo"    (remove-dot-segments (a "/.foo"))    (a "/.foo"))
        (check-equal "/..bar"   (remove-dot-segments (a "/..bar"))   (a "/..bar"))
        (check-equal "..g"      (remove-dot-segments (a "..g"))      (a "..g"))))

    ;; Total over ANY byte string: a NUL and a high byte are
    ;; ordinary segment bytes, moved by 2E, and a real dot-segment beside them
    ;; is still removed -- the function neither raises nor mishandles non-ASCII.
    ;; /<NUL>/.. -> the <NUL> segment is emitted, then "/.." pops it -> "/".
    (harness-case "non-ASCII bytes are ordinary path content, never a crash"
      (lambda ()
        (check-equal "/<NUL>/.. -> /"
                     (remove-dot-segments (bytes 47 0 47 46 46)) (bytes 47))
        (check-equal "0xFF in a segment is moved verbatim"
                     (remove-dot-segments (bytes 255 46 46 120)) (bytes 255 46 46 120))))))

;;; --- remove-dot-segments: the §5.2.4 corpus, graded step for step -----------
(harness-group "remove-dot-segments trace"
  (lambda ()
    (define all (corpus-load-dot-segments (corpus-path "dot-segments.scm")))
    (define (rows-of n) (filter (lambda (r) (= (ds-trace r) n)) all))

    ;; check-trace : String (List Ds) -> void
    ;; Run the trace on the path the corpus's own step-1 row carries, then assert
    ;; every produced (label output input) triple equals the corresponding corpus
    ;; row. The path is read from the corpus, not hardcoded, so this stays graded
    ;; against the committed vectors.
    (define (check-trace label rows)
      (let* ((path (ds-input (car rows)))          ; step 1's input is the path
             (got (remove-dot-segments-trace (a path))))
        (check-equal (string-append label " row count")
                     (length got) (length rows))
        (let loop ((g got) (r rows) (i 0))
          (when (and (pair? g) (pair? r))
            (let ((gr (car g)) (rr (car r))
                  (tag (string-append label " #" (number->string i))))
              (check-equal (string-append tag " step") (car gr)        (ds-step rr))
              (check-equal (string-append tag " out")  (s (cadr gr))   (ds-output rr))
              (check-equal (string-append tag " in")   (s (caddr gr))  (ds-input rr)))
            (loop (cdr g) (cdr r) (+ i 1))))))

    (harness-case "trace 1 (/a/b/c/./../../g) reproduces every step"
      (lambda () (check-trace "trace 1" (rows-of 1))))

    (harness-case "trace 2 (mid/content=5/../6) reproduces every step"
      (lambda () (check-trace "trace 2" (rows-of 2))))

    ;; The two committed traces only ever fire "1"/"2E"/"2B"/"2C", so 2A and 2D
    ;; -- whose RESULT behaviour is pinned above -- have their trace LABELS
    ;; graded here: mislabelling the case a wrong-but-verifiable resolver picks
    ;; must redden, which is the whole point of grading the trace and not only
    ;; the end result. "../g" fires 2A then 2E; "." fires 2D alone.
    (harness-case "2A and 2D are labelled correctly in the trace"
      (lambda ()
        ;; both spellings of each case, so neither code branch's label floats
        ;; free: "../g" and "./g" fire 2A; "." and ".." fire 2D.
        (check-equal "../g label sequence"
                     (map car (remove-dot-segments-trace (a "../g")))
                     (list "1" "2A" "2E"))
        (check-equal "./g label sequence"
                     (map car (remove-dot-segments-trace (a "./g")))
                     (list "1" "2A" "2E"))
        (check-equal ". label sequence"
                     (map car (remove-dot-segments-trace (a ".")))
                     (list "1" "2D"))
        (check-equal ".. label sequence"
                     (map car (remove-dot-segments-trace (a "..")))
                     (list "1" "2D"))))

    ;; The result the RFC prints for each worked example, said once more as the
    ;; consumer-facing entry, so the two are pinned to agree.
    (harness-case "the result equals the trace's last output buffer"
      (lambda ()
        (check-equal "trace 1 result"
                     (remove-dot-segments (a "/a/b/c/./../../g")) (a "/a/g"))
        (check-equal "trace 2 result"
                     (remove-dot-segments (a "mid/content=5/../6")) (a "mid/6"))))))

;;; --- merge: §5.2.3, the six RFC-derived branch vectors ----------------------
;;; base-has-authority? is the base authority being DEFINED, not
;;; nonempty -- the caller reads it off the base components.
(harness-group "merge"
  (lambda ()
    ;; Branch (b), the §5.4 base (authority "a", path "/b/c/d;p"): the last
    ;; segment "d;p" is dropped whole, the trailing "/" kept, the reference
    ;; appended verbatim.
    (harness-case "branch b splices onto all-but-the-last base segment"
      (lambda ()
        (check-equal "g -> /b/c/g"
                     (merge #t (a "/b/c/d;p") (a "g"))   (a "/b/c/g"))
        (check-equal "g/ keeps its trailing slash"
                     (merge #t (a "/b/c/d;p") (a "g/"))  (a "/b/c/g/"))
        (check-equal ";x is an ordinary new segment"
                     (merge #t (a "/b/c/d;p") (a ";x"))  (a "/b/c/;x"))
        (check-equal "empty reference yields the base prefix"
                     (merge #t (a "/b/c/d;p") (a ""))    (a "/b/c/"))))

    ;; Branch (a): a defined authority with an EMPTY base path is the only case
    ;; that synthesises a leading "/". http://a + "g" resolves through "/g".
    (harness-case "branch a roots the reference when the base path is empty"
      (lambda ()
        (check-equal "authority + empty path + g -> /g"
                     (merge #t (a "") (a "g"))  (a "/g"))))

    ;; Branch (b), no-slash edge: a slashless base path is excluded ENTIRELY, so
    ;; merge returns exactly the reference path.
    (harness-case "a slashless base path is dropped whole"
      (lambda ()
        (check-equal "mid + g -> g (no authority)"
                     (merge #f (a "mid") (a "g"))  (a "g"))
        ;; branch (a) needs an EMPTY base path, so a defined authority over a
        ;; slashless NON-empty base path still takes branch (b): same answer.
        (check-equal "mid + g -> g (authority present, base non-empty)"
                     (merge #t (a "mid") (a "g"))  (a "g"))))

    ;; Absent vs empty at the branch boundary: with NO authority, an empty base
    ;; path takes branch (b) (no "/" -> prefix ""), not branch (a).
    (harness-case "empty base path without authority does not root"
      (lambda ()
        (check-equal "no authority + empty path + g -> g"
                     (merge #f (a "") (a "g"))  (a "g"))))))

(harness-finish)
