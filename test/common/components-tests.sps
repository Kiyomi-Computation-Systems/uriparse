#!r6rs
;;; unit.components -- the seam type, and the one distinction it exists to keep:
;;; absent is not empty (decision 0008 item 7). Pure values in, booleans out;
;;; no scanner, no core.
(import (rnrs)
        (uri test harness)
        (uri components))

;; Shorthands: `bv` builds a bytevector from bytes, `E` is the empty one.
(define (bv . bytes) (u8-list->bytevector bytes))
(define E (make-bytevector 0))

(harness-begin "unit.components")

(harness-group "construction"
  (lambda ()
    (harness-case "the five fields are read back as given"
      (lambda ()
        (let ((c (make-uri-components (bv 104 116 116 112) ; "http"
                                      (bv 97)              ; "a"
                                      (bv 47 112)          ; "/p"
                                      (bv 113)             ; "q"
                                      #f)))
          (check "is a components" (uri-components? c))
          (check-equal "scheme"    (uri-components-scheme c)    (bv 104 116 116 112))
          (check-equal "authority" (uri-components-authority c) (bv 97))
          (check-equal "path"      (uri-components-path c)      (bv 47 112))
          (check-equal "query"     (uri-components-query c)     (bv 113))
          (check-equal "fragment"  (uri-components-fragment c)  #f))))

    (harness-case "#f is a legal field value in every position"
      (lambda ()
        (let ((c (make-uri-components #f #f (bv) #f #f)))
          (check "constructed" (uri-components? c))
          (check-equal "path is present-empty" (uri-components-path c) E))))

    ;; The scanner delivers bytes; a caller who reached for utf8->string at the
    ;; wrong seam would hand a string here, and it must be refused at
    ;; construction rather than discovered when the core compares bytes to a
    ;; string and silently never matches.
    (harness-case "a string field is refused"
      (lambda ()
        (check-raises "string path" uri-components-error?
                      (lambda () (make-uri-components #f #f "/p" #f #f)))))

    (harness-case "a non-bytevector, non-#f field is refused"
      (lambda ()
        (check-raises "number scheme" uri-components-error?
                      (lambda () (make-uri-components 65 #f (bv) #f #f)))))))

(harness-group "absent-is-not-empty"
  (lambda ()
    (harness-case "absent means #f, and nothing else"
      (lambda ()
        (check "absent"          (uri-component-absent? #f))
        (check "empty not absent" (not (uri-component-absent? E)))
        (check "bytes not absent" (not (uri-component-absent? (bv 97))))))

    (harness-case "present means a bytevector, empty or not"
      (lambda ()
        (check "empty present"  (uri-component-present? E))
        (check "bytes present"  (uri-component-present? (bv 97)))
        (check "absent absent"  (not (uri-component-present? #f)))))

    (harness-case "empty is present-and-zero-length, never #f"
      (lambda ()
        (check "empty is empty"     (uri-component-empty? E))
        (check "#f is NOT empty"    (not (uri-component-empty? #f)))
        (check "bytes not empty"    (not (uri-component-empty? (bv 97))))))

    (harness-case "present-nonempty is the third case"
      (lambda ()
        (check "bytes"        (uri-component-present-nonempty? (bv 97)))
        (check "empty is not" (not (uri-component-present-nonempty? E)))
        (check "#f is not"    (not (uri-component-present-nonempty? #f)))))

    ;; The three states are exhaustive and disjoint over any field value.
    (harness-case "absent, empty and present-nonempty partition every value"
      (lambda ()
        (for-each
         (lambda (v)
           (let ((flags (list (uri-component-absent? v)
                              (uri-component-empty? v)
                              (uri-component-present-nonempty? v))))
             (check-equal (string-append "exactly one of three for "
                                         (if v "a bytevector" "#f"))
                          (length (filter (lambda (x) x) flags)) 1)))
         (list #f E (bv 97) (bv 0)))))))

(harness-group "equality"
  (lambda ()
    (harness-case "equal fields are equal"
      (lambda ()
        (check "same"
               (uri-components=? (make-uri-components (bv 104) #f (bv 47) #f #f)
                                 (make-uri-components (bv 104) #f (bv 47) #f #f)))))

    ;; THE DISTINCTION, at the type level: a URI whose query is absent is not
    ;; equal to one whose query is empty. `http://a` /= `http://a?`.
    (harness-case "absent query is not equal to empty query"
      (lambda ()
        (let ((absent (make-uri-components (bv 104) (bv 97) (bv) #f  #f))
              (empty  (make-uri-components (bv 104) (bv 97) (bv) E   #f)))
          (check "absent /= empty" (not (uri-components=? absent empty))))))

    ;; The authority version of the same distinction: `http:/p` /= `http:///p`.
    (harness-case "absent authority is not equal to empty authority"
      (lambda ()
        (let ((no-auth  (make-uri-components (bv 104) #f (bv 47 112) #f #f))
              (empty-auth (make-uri-components (bv 104) E (bv 47 112) #f #f)))
          (check "no-authority /= empty-authority"
                 (not (uri-components=? no-auth empty-auth))))))

    (harness-case "differing bytes are not equal"
      (lambda ()
        (check "different path"
               (not (uri-components=? (make-uri-components #f #f (bv 47 97) #f #f)
                                      (make-uri-components #f #f (bv 47 98) #f #f))))))

    ;; Every field is compared, not just the middle three. `http:x` /= `a:x`
    ;; and `x#a` /= `x#b`, so a resolver or recomposer that agreed on scheme or
    ;; fragment while they differ is caught here rather than at M6/M7.
    (harness-case "scheme and fragment are compared too"
      (lambda ()
        (check "scheme differs"
               (not (uri-components=? (make-uri-components (bv 104) #f (bv 120) #f #f)
                                      (make-uri-components (bv 97)  #f (bv 120) #f #f))))
        (check "fragment differs"
               (not (uri-components=? (make-uri-components #f #f (bv 120) #f (bv 97))
                                      (make-uri-components #f #f (bv 120) #f (bv 98)))))))

    (harness-case "a non-components compares false, it does not raise"
      (lambda ()
        (check "not a components"
               (not (uri-components=? (make-uri-components #f #f (bv) #f #f) 'nope)))))))

(harness-finish)
