#!r6rs
;;; unit.collect -- the shell that turns the scanner's callbacks into a
;;; five-field uri-components. It is judged on the ASSEMBLY: the verdict-based
;;; scheme and path stitching (mode 3), the on-rooted slash, and
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

;;; --- the copy discipline -------------------------------------------------
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

;;; --- absent is not empty, at the COMPONENT level -------------------------
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

;;; --- the offset seam -----------------------------------------------------
;;; Each present component's ABSOLUTE start offset, so a core charset validator's
;;; component-relative index rebases to an input offset. Witnessed here against
;;; hand-counted offsets before it is trusted -- especially the three path
;;; shapes, whose base is NOT the raw path-span mark (a rooted "/" was dropped, a
;;; mode-3 leading token was stitched on).
(harness-group "offsets"
  (lambda ()
    (define (off mode s c) (uri-parse-component-offset (parse mode s) c))
    (harness-case "the components of a full absolute URI"
      (lambda ()
        (check-equal "scheme@0"    (off 'uri "http://a/b/c/d;p?q" 'scheme) 0)
        (check-equal "authority@7" (off 'uri "http://a/b/c/d;p?q" 'authority) 7)
        (check-equal "path@8"      (off 'uri "http://a/b/c/d;p?q" 'path) 8)
        (check-equal "query@17"    (off 'uri "http://a/b/c/d;p?q" 'query) 17)
        (check-equal "no fragment" (off 'uri "http://a/b/c/d;p?q" 'fragment) #f)))
    (harness-case "an empty path, then a fragment"
      (lambda ()
        (check-equal "empty path@8" (off 'uri "http://a#x" 'path) 8)
        (check-equal "fragment@9"   (off 'uri "http://a#x" 'fragment) 9)))
    (harness-case "a rooted path begins at the dropped slash, one before its span"
      (lambda ()
        (check-equal "rooted path@5" (off 'uri "http:/p" 'path) 5)
        (check-equal "no authority"  (off 'uri "http:/p" 'authority) #f)))
    (harness-case "an empty authority's absolute path is NOT rooted (the // owned the slash)"
      (lambda ()
        (check-equal "empty authority@7" (off 'uri "http:///p" 'authority) 7)
        (check-equal "abs path@7"        (off 'uri "http:///p" 'path) 7)))
    (harness-case "a rootless path"
      (lambda ()
        (check-equal "rootless path@7" (off 'uri "mailto:fred@ex.com" 'path) 7)))
    (harness-case "mode-3 verdicts rebase onto the leading token"
      (lambda ()
        (check-equal "scheme verdict scheme@0" (off 'uri-reference "g:h" 'scheme) 0)
        (check-equal "scheme verdict path@2"   (off 'uri-reference "g:h" 'path) 2)
        (check-equal "segment verdict path@0"  (off 'uri-reference "g/h" 'path) 0)))
    (harness-case "a relative reference: rooted path and a relative authority"
      (lambda ()
        (check-equal "rel rooted path@0" (off 'relative-ref "/b/c?q" 'path) 0)
        (check-equal "rel query@5"       (off 'relative-ref "/b/c?q" 'query) 5)
        (check-equal "rel authority@2"   (off 'relative-ref "//h/p" 'authority) 2)
        (check-equal "rel path@3"        (off 'relative-ref "//h/p" 'path) 3)))
    (harness-case "offsets are absolute, so a byte-at-a-time feed gives the same"
      (lambda ()
        (define (doff mode s c) (uri-parse-component-offset (drip mode s) c))
        (check-equal "drip path@8"    (doff 'uri "http://a/b/c/d;p?q" 'path) 8)
        (check-equal "drip query@17"  (doff 'uri "http://a/b/c/d;p?q" 'query) 17)
        (check-equal "drip rooted@5"  (doff 'uri "http:/p" 'path) 5)))))

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

;;; --- the section 1.1.2 example URIs parse --------------------------------
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

;;; --- collector reuse: reset! ---------------------------------------------
;;; A collector reset to its just-constructed state must reparse EXACTLY as a
;;; fresh one -- clearing the span table, the offset table and the verdict flags,
;;; and preserving the embedder-chosen mode (parser-reset! restores the merged
;;; field-initials, so a reused collector does not fall back to unset). These are
;;; the properties a per-connection server depends on.
(harness-group "collector reuse (reset!)"
  (lambda ()
    (define (reuse mode a b)     ; parse a, reset, parse b -> the result of b
      (let ((c (make-uri-collector mode)) (ba (string->utf8 a)) (bb (string->utf8 b)))
        (uri-collect-feed! c ba 0 (bytevector-length ba)) (uri-collect-finish! c)
        (uri-collector-reset! c)
        (uri-collect-feed! c bb 0 (bytevector-length bb)) (uri-collect-finish! c)))
    (harness-case "reset-and-reparse equals a fresh collector -- components AND offsets"
      (lambda ()
        (define (offsets r)   ; the five component offsets, so a stale offsets table reddens
          (map (lambda (c) (uri-parse-component-offset r c))
               '(scheme authority path query fragment)))
        (for-each
         (lambda (row)
           (let* ((mode (car row)) (a (cadr row)) (b (caddr row))
                  (got (reuse mode a b)) (fresh (parse mode b)))
             (check (string-append "ok: " b) (uri-parse-ok? got))
             (check (string-append "reuse==fresh components: " b)
                    (uri-components=? (uri-parse-components got) (uri-parse-components fresh)))
             (check (string-append "reuse==fresh offsets: " b)
                    (equal? (offsets got) (offsets fresh)))))
         ;; The rooted? and verdict resets are OBSERVABLE THROUGH THE OFFSET SEAM
         ;; (path-offset reads both), so the offset check above witnesses them:
         ;;   - http:/p -> http://a/x : a stale rooted? corrupts the second path.
         ;;   - g/h -> /p : g/h fires the SEGMENT verdict; /p is a rooted path with
         ;;     NO leading token, so it fires no verdict -- a stale 'segment would
         ;;     steer path-offset to the cleared leading-token slot (#f) instead of 0.
         '((uri          "http://a/b?q#f" "http://h/x")
           (relative-ref "//a/b?q"        "p/q")
           (uri-reference "g:h"           "//host/path")   ; scheme-verdict then authority
           (uri          "http:/p"        "http://a/x")    ; ROOTED then non-rooted (rooted? reset)
           (uri-reference "g/h"           "/p")            ; SEGMENT-verdict then a no-token rooted path (verdict reset)
           (uri-reference "g:h"           "a/b")))))        ; scheme-verdict then segment-verdict
    (harness-case "no stale span leaks across a reset (query/fragment cleared)"
      (lambda ()
        (let ((got (reuse 'uri "http://a/p?q=1#top" "http://a/x")))   ; had query+fragment; b has neither
          (check "ok" (uri-parse-ok? got))
          (check "query absent, not the stale q=1"
                 (uri-component-absent? (uri-components-query (uri-parse-components got))))
          (check "fragment absent, not the stale top"
                 (uri-component-absent? (uri-components-fragment (uri-parse-components got)))))))
    (harness-case "the embedder-chosen mode survives the reset"
      (lambda ()
        (let ((got (reuse 'relative-ref "//h/a" "b/c")))   ; if mode were lost, "b/c" refuses mode-unset
          (check "ok, not mode-unset" (uri-parse-ok? got))
          (check "reuse==fresh"
                 (uri-components=? (uri-parse-components got)
                                   (uri-parse-components (parse 'relative-ref "b/c")))))))
    (harness-case "reset after an ERROR result, then reuse"
      (lambda ()
        (let ((c (make-uri-collector 'uri)) (bad (string->utf8 "nocolon")) (ok (string->utf8 "http://h/x")))
          (uri-collect-feed! c bad 0 (bytevector-length bad))
          (check "the bad parse errors" (not (uri-parse-ok? (uri-collect-finish! c))))
          (uri-collector-reset! c)
          (uri-collect-feed! c ok 0 (bytevector-length ok))
          (check "reuse after error == fresh"
                 (uri-components=? (uri-parse-components (uri-collect-finish! c))
                                   (uri-parse-components (parse 'uri "http://h/x")))))))))

;;; --- validation over a parse result --------------------------------------
;;; `uri-parse-result-validate` lifts the post-parse judgement out of
;;; `uri-parse-validate` and names it, so a REUSED collector's `uri-collect-finish!`
;;; result reaches the SAME audited recognizer (the audited charset and host
;;; validators) without a re-parse. Pinned here in layers:
;;;   - the DELEGATION: `uri-parse-validate` routes its judgement through
;;;     `uri-parse-result-validate` (a version that stopped delegating diverges);
;;;   - the REUSE PATH (the point of both entry points): a validated RESET-reused collector's result
;;;     equals the one-shot -- this actually calls `uri-collector-reset!` and so also
;;;     witnesses that the offset seam survives a reset;
;;;   - the IDENTITY semantics: a valid or already-errored result returns UNCHANGED (eq?).
;;; The two equivalence checks route BOTH their sides through the same `validate-result`,
;;; so they cannot catch a bug INSIDE it (a wrong code or offset is produced on both sides
;;; and cancels). The checks with teeth for the judgement itself are therefore the two
;;; INDEPENDENT hardcoded expectations below -- one per arm of `validate-result` (the
;;; charset arm and the authority/host arm), each with its ABSOLUTE offset rebased through
;;; the seam (a property no check verifies is not pinned).
(harness-group "validation over a parse result (uri-parse-result-validate)"
  (lambda ()
    (define (offsets r)                    ; the five component offsets, so a rebased offset reddens
      (map (lambda (c) (uri-parse-component-offset r c))
           '(scheme authority path query fragment)))
    (define (result=? a b)                 ; ok-for-ok, components+offsets or code+offset
      (and (eq? (uri-parse-ok? a) (uri-parse-ok? b))
           (if (uri-parse-ok? a)
               (and (uri-components=? (uri-parse-components a) (uri-parse-components b))
                    (equal? (offsets a) (offsets b)))
               (and (eq? (uri-parse-error-code a) (uri-parse-error-code b))
                    (equal? (uri-parse-error-offset a) (uri-parse-error-offset b))))))
    ;; A stateful throwaway per mode -- authority + query + fragment (and a scheme verdict
    ;; for uri-reference) -- so the reset below must clear REAL span/offset/verdict state
    ;; before `str` is parsed on the same collector.
    (define throwaway '((uri           . "http://a/p?q=1#top")
                        (relative-ref  . "//h/a?q#f")
                        (uri-reference . "g:h?q#f")))
    (define (reuse-validate mode str)      ; parse a throwaway, RESET, then parse+validate `str`
      (let ((c (make-uri-collector mode))
            (p (string->utf8 (cdr (assq mode throwaway))))
            (bv (string->utf8 str)))
        (uri-collect-feed! c p 0 (bytevector-length p)) (uri-collect-finish! c)
        (uri-collector-reset! c)           ; the reuse path -- NOT a fresh collector
        (uri-collect-feed! c bv 0 (bytevector-length bv))
        (uri-parse-result-validate (uri-collect-finish! c))))
    ;; A spread of inputs: valid, charset-invalid, authority-invalid, and structural-error,
    ;; across all three modes. The equivalence checks compare product to product, so they
    ;; hold whatever exact code/offset each input yields -- they guard DIVERGENCE between the
    ;; entry points, not the judgement's absolute correctness (the hardcoded cases do that).
    (define cases
      '((uri           . "http://a/b/c/d;p?q")   ; valid, full absolute
        (uri           . "http://a/b^c")          ; charset: ^ is not a pchar
        (uri           . "http://[a@b]/p")        ; authority: '@' splits userinfo/host, userinfo invalid
        (uri           . "foo/bar")               ; structural: scheme-required (never assembles)
        (relative-ref  . "/b/c?q")                ; valid rooted
        (relative-ref  . "a/b^c")                 ; charset: ^ in a later segment
        (relative-ref  . "g:h")                   ; structural: scheme-forbidden
        (uri-reference . "http://a/b?q#f")        ; valid full via the URI arm
        (uri-reference . "g:h")                   ; valid, verdict scheme
        (uri-reference . "g^h")))                 ; charset: verdict segment, ^ in the path
    (harness-case "delegation: uri-parse-validate routes its judgement through uri-parse-result-validate"
      ;; Guards THE DELEGATION only -- both sides share validate-result, so a bug inside it
      ;; cancels. A uri-parse-validate that stopped delegating (or split the parse) diverges.
      (lambda ()
        (for-each
         (lambda (row)
           (let* ((mode (car row)) (str (cdr row)) (bv (string->utf8 str)))
             (check (string-append (symbol->string mode) " " str)
                    (result=? (uri-parse-validate mode bv)
                              (uri-parse-result-validate (uri-parse mode bv))))))
         cases)))
    (harness-case "the point: a validated RESET-reused collector result == the one-shot (the per-connection reuse path)"
      ;; Genuinely resets and reuses a collector, then validates its finish! result. A
      ;; reset! that corrupted the span or offset seam would diverge from the one-shot here.
      (lambda ()
        (for-each
         (lambda (row)
           (let* ((mode (car row)) (str (cdr row)))
             (check (string-append (symbol->string mode) " " str)
                    (result=? (reuse-validate mode str)
                              (uri-parse-validate mode (string->utf8 str))))))
         cases)))
    (harness-case "a valid result comes back UNCHANGED -- the argument itself (eq?)"
      (lambda ()
        (let ((r (uri-parse 'uri (string->utf8 "http://a/b/c/d;p?q"))))
          (check "the parse is ok" (uri-parse-ok? r))
          (check "eq? -- no copy, no new record" (eq? r (uri-parse-result-validate r))))))
    (harness-case "a structural error passes straight through -- the argument itself (eq?)"
      (lambda ()
        (let ((r (uri-parse 'uri (string->utf8 "foo/bar"))))   ; scheme-required, components #f
          (check "the parse errored" (not (uri-parse-ok? r)))
          (check "eq? -- an error result is not re-judged" (eq? r (uri-parse-result-validate r)))
          (check-equal "still scheme-required" (uri-parse-error-code (uri-parse-result-validate r))
                       'scheme-required))))
    ;; --- the two independent hardcoded pins (one per arm of validate-result) ----------
    ;; These are the checks that pin the JUDGEMENT itself against a constant, on BOTH the
    ;; fresh and (for the charset arm) the reset-reused paths -- the equivalence checks
    ;; above cannot, since both their sides share the code under test.
    (harness-case "the charset arm: a bad pchar, pinned on the fresh AND the reset-reused paths"
      (lambda ()
        ;; path "/b^c" starts at offset 8 (after "http://a"); ^ is its byte 2 -> absolute 10.
        (let ((fresh  (uri-parse-result-validate (uri-parse 'uri (string->utf8 "http://a/b^c"))))
              (reused (reuse-validate 'uri "http://a/b^c")))
          (check "fresh: the lenient parse is ok (uri-parse stays a splitter)"
                 (uri-parse-ok? (uri-parse 'uri (string->utf8 "http://a/b^c"))))
          (check "fresh: NOT ok after validation" (not (uri-parse-ok? fresh)))
          (check-equal "fresh: the charset code, named per production"
                       (uri-parse-error-code fresh) 'invalid-pchar)
          (check-equal "fresh: the ABSOLUTE offset of the bad byte, through the seam"
                       (uri-parse-error-offset fresh) 10)
          (check "reused: NOT ok after validation" (not (uri-parse-ok? reused)))
          (check-equal "reused: same code" (uri-parse-error-code reused) 'invalid-pchar)
          (check-equal "reused: same ABSOLUTE offset -- the seam survives reset!"
                       (uri-parse-error-offset reused) 10))))
    (harness-case "the authority/host arm: a non-numeric port, rebased through the authority offset"
      (lambda ()
        ;; authority "h:x" starts at offset 7; the bad port byte x is its index 2 -> absolute 9.
        ;; This is validate-result's OTHER branch (validate-authority), pinned by a constant so
        ;; a broken authority-arm rebasing cannot pass silently (it did before this case existed).
        (let ((r (uri-parse-result-validate (uri-parse 'uri (string->utf8 "http://h:x/p")))))
          (check "NOT ok after validation" (not (uri-parse-ok? r)))
          (check-equal "the host-grammar code (the validate-authority arm)"
                       (uri-parse-error-code r) 'invalid-port)
          (check-equal "the ABSOLUTE offset, rebased through the authority seam"
                       (uri-parse-error-offset r) 9))))))

(harness-finish)
