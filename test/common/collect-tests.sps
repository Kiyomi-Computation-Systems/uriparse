#!r6rs
;;; unit.collect -- the shell that turns the scanner's callbacks into a
;;; five-field uri-components. It is judged on the ASSEMBLY: the verdict-based
;;; scheme and path stitching (mode 3), the on-rooted slash (decision 0018), and
;;; the absent-vs-empty distinction carried into the component fields. The
;;; scanner itself is judged in unit.grammar; here the spans are trusted and the
;;; question is whether collect reads the signals and joins the bytes correctly.
(import (rnrs)
        (uri test harness)
        (uri collect)
        (uri components)
        (uri vocabulary)
        (uri test corpus))

(define (sb s) (and s (string->utf8 s)))          ; expected field: string | #f
(define (want scheme authority path query fragment)
  (make-uri-components (sb scheme) (sb authority) (sb path) (sb query) (sb fragment)))

(define (parse mode-sym str) (uri-parse mode-sym (string->utf8 str)))

;; Feed one byte at a time through the streaming interface, so a span crossing a
;; feed boundary delivers several fragments -- the case the one-shot never hits.
(define (drip mode-sym str)
  (let ((c (make-uri-collector mode-sym)) (bv (string->utf8 str)))
    (let loop ((i 0))
      (when (< i (bytevector-length bv)) (uri-collect-feed! c bv i (+ i 1)) (loop (+ i 1))))
    (uri-collect-finish! c)))

(harness-begin "unit.collect")

;;; --- the components, across the assembly cases --------------------------
;;;
;;; Each row: (mode uri scheme authority path query fragment). A field is a
;;; string (present, "" empty) or #f (absent). These are the COMPONENTS, so
;;; mode-3 stitching and the rooted slash are already applied.
(define oracle
  '((uri           "http://a/b/c/d;p?q" "http" "a"                "/b/c/d;p" "q" #f)
    (uri           "http://a"           "http" "a"                ""         #f  #f)   ; path empty
    (uri           "http://a?"          "http" "a"                ""         ""  #f)   ; query empty
    (uri           "http://a#x"         "http" "a"                ""         #f  "x")
    (uri           "http:///p"          "http" ""                "/p"       #f  #f)   ; authority EMPTY
    (uri           "http:/p"            "http" #f                 "/p"       #f  #f)   ; authority ABSENT, rooted
    (uri           "mailto:fred@ex.com" "mailto" #f               "fred@ex.com" #f #f) ; rootless, no authority
    (relative-ref  "/b/c/d;p?q"         #f     #f                 "/b/c/d;p" "q" #f)   ; rooted
    (relative-ref  "g"                  #f     #f                 "g"        #f  #f)
    (relative-ref  "//h/p"              #f     "h"                "/p"       #f  #f)
    (relative-ref  ""                   #f     #f                 ""         #f  #f)   ; empty ref, empty path
    (uri-reference "g:h"                "g"    #f                 "h"        #f  #f)   ; verdict scheme
    (uri-reference "g/h"                #f     #f                 "g/h"      #f  #f)   ; verdict segment, stitched
    (uri-reference "g?q"                #f     #f                 "g"        "q" #f)   ; segment + query
    (uri-reference "/p"                 #f     #f                 "/p"       #f  #f)   ; rooted, no leading token
    (uri-reference "http://a/b?q#f"     "http" "a"                "/b"       "q" "f")))

(harness-group "components"
  (lambda ()
    (for-each
     (lambda (row)
       (let ((mode (list-ref row 0)) (uri (list-ref row 1)))
         (harness-case (if (string=? uri "") "(empty)" uri)
           (lambda ()
             (let ((r (parse mode uri)))
               (check "ok" (uri-parse-ok? r))
               (when (uri-parse-ok? r)
                 (check "components match"
                        (uri-components=? (uri-parse-components r)
                                          (apply want (list-tail row 2))))))))))
     oracle)))

;;; --- chunk-invariance: the same components however the bytes arrive ------
(harness-group "chunk-invariance"
  (lambda ()
    (for-each
     (lambda (row)
       (let ((mode (list-ref row 0)) (uri (list-ref row 1)))
         (harness-case (string-append (symbol->string mode) " "
                                      (if (string=? uri "") "(empty)" uri))
           (lambda ()
             (let ((whole (parse mode uri)) (piece (drip mode uri)))
               (check "both ok" (and (uri-parse-ok? whole) (uri-parse-ok? piece)))
               (when (and (uri-parse-ok? whole) (uri-parse-ok? piece))
                 (check "same components"
                        (uri-components=? (uri-parse-components whole)
                                          (uri-parse-components piece)))))))))
     oracle)))

;;; --- the copy discipline (design §2, decision 0018 item 4) ---------------
;;; A delivered span range is valid only for the dynamic extent of the callback,
;;; so collect MUST copy each fragment. Feeding through a buffer that is refilled
;;; between feeds is the case that tells a copy from a retained reference: a
;;; non-copying collect would read the mutated bytes and corrupt the earlier
;;; component.
(harness-group "copy-discipline"
  (lambda ()
    (harness-case "a fragment is copied, not a reference into a reused feed buffer"
      (lambda ()
        (let ((c (make-uri-collector 'uri))
              (buf (make-bytevector 5)))
          (bytevector-copy! (string->utf8 "http:") 0 buf 0 5)  ; feed 1
          (uri-collect-feed! c buf 0 5)
          (bytevector-copy! (string->utf8 "//a/p") 0 buf 0 5)  ; refill the SAME buffer
          (uri-collect-feed! c buf 0 5)
          (let ((r (uri-collect-finish! c)))
            (check "ok" (uri-parse-ok? r))
            ;; "http://a/p": scheme must still read "http", not the mutated "//a/"
            (check "components survive the buffer reuse"
                   (uri-components=? (uri-parse-components r)
                                     (want "http" "a" "/p" #f #f)))))))))

;;; --- absent is not empty, at the COMPONENT level (decision 0008) ---------
(harness-group "absent-is-not-empty"
  (lambda ()
    (define (auth str mode) (uri-components-authority (uri-parse-components (parse mode str))))
    (define (query str) (uri-components-query (uri-parse-components (parse 'uri str))))
    (define (frag str) (uri-components-fragment (uri-parse-components (parse 'uri str))))
    (harness-case "empty authority is #vu8(), absent authority is #f"
      (lambda ()
        (check "///p empty"  (uri-component-empty?  (auth "http:///p" 'uri)))
        (check "/p absent"   (uri-component-absent? (auth "http:/p"   'uri)))
        (check "http:// empty (eof)"        (uri-component-empty? (auth "http://" 'uri)))
        (check "// empty (eof, rel)"        (uri-component-empty? (auth "//" 'relative-ref)))))
    (harness-case "empty query is #vu8(), absent query is #f"
      (lambda ()
        (check "a? empty"    (uri-component-empty?  (query "http://a?")))
        (check "a absent"    (uri-component-absent? (query "http://a")))))
    (harness-case "empty fragment is #vu8(), absent fragment is #f"
      (lambda ()
        (check "a# empty"    (uri-component-empty?  (frag "http://a#")))
        (check "a absent"    (uri-component-absent? (frag "http://a")))))
    (harness-case "path is always present, never #f"
      (lambda ()
        (check "//h path present" (uri-component-present?
                                   (uri-components-path (uri-parse-components (parse 'relative-ref "//h")))))
        (check "empty ref path present" (uri-component-present?
                                         (uri-components-path (uri-parse-components (parse 'relative-ref "")))))))))

;;; --- errors surface, they do not assemble -------------------------------
(harness-group "errors"
  (lambda ()
    (harness-case "an unset mode refuses at offset 0"
      (lambda ()
        (let ((r (parse 'unset "http://a")))
          (check "not ok" (not (uri-parse-ok? r)))
          (check-equal "code" (uri-parse-error-code r) 'mode-unset)
          (check-equal "offset" (uri-parse-error-offset r) 0)
          (check "no components" (not (uri-parse-components r))))))
    (harness-case "a colon in a relative-ref's first segment is scheme-forbidden"
      (lambda ()
        (let ((r (parse 'relative-ref "g:h")))
          (check "not ok" (not (uri-parse-ok? r)))
          (check-equal "code" (uri-parse-error-code r) 'scheme-forbidden)
          (check-equal "offset" (uri-parse-error-offset r) 1))))
    (harness-case "a uri with no scheme is scheme-required, with no components"
      (lambda ()
        (let ((r (parse 'uri "foo/bar")))
          (check "not ok" (not (uri-parse-ok? r)))
          (check-equal "code" (uri-parse-error-code r) 'scheme-required)
          (check-equal "offset" (uri-parse-error-offset r) 3)
          (check "no components" (not (uri-parse-components r))))))
    (harness-case "an unknown mode name is refused by the vocabulary"
      (lambda ()
        (check-raises "bogus mode" uri-vocabulary-error?
                      (lambda () (uri-parse 'whatwg (string->utf8 "x"))))))))

;;; --- the section 1.1.2 example URIs parse (decision 0005 item 3) ---------
;;; They carry no expected decomposition, so all a lane may assert is that each
;;; parses into components -- across eight schemes, the smoke set for
;;; path-rootless the corpus was chosen for.
(harness-group "example-uris"
  (lambda ()
    (define dir (adapter-environment-variable "URI_CORPUS_DIR"))
    (define uris (corpus-load-examples (string-append dir "/example-uris.scm")))
    (harness-case "all eight parse into components"
      (lambda ()
        (check-equal "count" (length uris) 8)
        (for-each
         (lambda (u)
           (let ((r (uri-parse 'uri (string->utf8 u))))
             (check (string-append "parses: " u) (uri-parse-ok? r))
             (check (string-append "has a path: " u)
                    (uri-component-present? (uri-components-path (uri-parse-components r))))))
         uris)))))

(harness-finish)
