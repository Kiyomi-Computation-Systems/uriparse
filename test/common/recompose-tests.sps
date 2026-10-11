#!r6rs
;;; unit.recompose -- RFC 3986 §5.3 component recomposition: five-field
;;; `uri-components` back to a URI-reference bytevector.
;;;
;;; The load-bearing rule is DEFINED, not nonempty: a delimiter
;;; is emitted whenever its component is present, even empty. So the sharp cases
;;; here are the absent (`#f`) vs present-empty (`#vu8()`) pairs that the §5.4
;;; corpus does not reach -- an empty-but-present authority (`http://`), an
;;; empty-but-present query (`...?`), an empty-but-present fragment (`...#`) --
;;; alongside the six §5.3 vectors derived from the RFC independently of this
;;; code.
(import (rnrs)
        (uri test harness)
        (uri components)
        (uri recompose))

(define (a str) (string->utf8 str))
;; comp : build components from bytevector-or-#f fields; `(a "x")` for present,
;; #f for absent. Recompose is judged as bytes against `(a "...")`.
(define (comp scheme authority path query fragment)
  (make-uri-components scheme authority path query fragment))

(harness-begin "unit.recompose")

;;; --- the six §5.3 vectors, derived from the RFC (each a §5.4 target) --------
(harness-group "the RFC §5.3 vectors"
  (lambda ()
    (harness-case "scheme + authority + path"
      (lambda ()
        (check-equal "http://a/b/c/g"
                     (recompose (comp (a "http") (a "a") (a "/b/c/g") #f #f))
                     (a "http://a/b/c/g"))))
    (harness-case "scheme + opaque path, NO authority -> no //"
      (lambda ()
        (check-equal "g:h"
                     (recompose (comp (a "g") #f (a "h") #f #f))
                     (a "g:h"))))
    (harness-case "a defined query emits ?"
      (lambda ()
        (check-equal "http://a/b/c/d;p?y"
                     (recompose (comp (a "http") (a "a") (a "/b/c/d;p") (a "y") #f))
                     (a "http://a/b/c/d;p?y"))))
    (harness-case "an empty present path adds nothing and no trailing slash"
      (lambda ()
        (check-equal "http://g (path present, empty)"
                     (recompose (comp (a "http") (a "g") (a "") #f #f))
                     (a "http://g"))))
    (harness-case "all five components present"
      (lambda ()
        (check-equal "http://a/b/c/d;p?q#s"
                     (recompose (comp (a "http") (a "a") (a "/b/c/d;p") (a "q") (a "s")))
                     (a "http://a/b/c/d;p?q#s"))))
    ;; The decisive #f-vs-"" authority case: same scheme and path, but an ABSENT
    ;; authority gives `http:g` (scheme + opaque path), not `http://g`.
    (harness-case "an absent authority suppresses the // (http:g not http://g)"
      (lambda ()
        (check-equal "http:g"
                     (recompose (comp (a "http") #f (a "g") #f #f))
                     (a "http:g"))))))

;;; --- absent vs present-empty, the distinction §5.3 turns on -----------------
(harness-group "defined, not nonempty"
  (lambda ()
    ;; authority "" (present, empty) still emits //; #f suppresses it. This is
    ;; the pair `http://` vs `http:`, both with an empty path.
    (harness-case "an empty-but-present authority still emits //"
      (lambda ()
        (check-equal "http:// (authority present, empty)"
                     (recompose (comp (a "http") (a "") (a "") #f #f))
                     (a "http://"))
        (check-equal "http: (authority absent)"
                     (recompose (comp (a "http") #f (a "") #f #f))
                     (a "http:"))))
    ;; query "" (present, empty) still emits ?; #f suppresses it. `http://a?`
    ;; and `http://a` are different URIs.
    (harness-case "an empty-but-present query still emits ?"
      (lambda ()
        (check-equal "http://a? (query present, empty)"
                     (recompose (comp (a "http") (a "a") (a "") (a "") #f))
                     (a "http://a?"))
        (check-equal "http://a (query absent)"
                     (recompose (comp (a "http") (a "a") (a "") #f #f))
                     (a "http://a"))))
    ;; fragment "" (present, empty) still emits #.
    (harness-case "an empty-but-present fragment still emits #"
      (lambda ()
        (check-equal "http://a#"
                     (recompose (comp (a "http") (a "a") (a "") #f (a "")))
                     (a "http://a#"))))
    ;; A relative reference: no scheme, no authority -- just a path (and maybe a
    ;; query/fragment). The path is emitted with no leading delimiter.
    (harness-case "a bare relative path recomposes to itself"
      (lambda ()
        (check-equal "a/b/c"
                     (recompose (comp #f #f (a "a/b/c") #f #f))
                     (a "a/b/c"))
        (check-equal "a/b?k=v#f"
                     (recompose (comp #f #f (a "a/b") (a "k=v") (a "f")))
                     (a "a/b?k=v#f"))))))

(harness-finish)
