#!r6rs
;;; unit.corpus -- the reading machinery, judged before any URI is parsed.
;;;
;;; Decision 0005 makes RFC 3986's own vectors the anchor of the resolution
;;; layer, which puts the READING of them on the critical path: a loader that
;;; is one row off makes every later comparison wrong, and the failure reads as
;;; a parser defect. M1 has no parser, so these lanes judge the loader, the
;;; ratchet and the comparator on the committed corpus and on hand-built
;;; inputs, and nothing else.
(import (rnrs)
        (uri test harness)
        (uri test corpus)
        (uri test ratchet))

(define (corpus-path name)
  (string-append (adapter-environment-variable "URI_CORPUS_DIR") "/" name))

(harness-begin "unit.corpus")

(harness-group "resolution"
  (lambda ()
    (define c (corpus-load-resolution (corpus-path "resolution.scm")))

    (harness-case "the base is the one section 5.4 declares"
      (lambda ()
        (check-equal "base" (resolution-base c) "http://a/b/c/d;p?q")))

    ;; 23 + 19. The count is asserted on THIS side too, not only in the
    ;; extractor: the extractor proves the RFC still says what it said, and
    ;; this proves the loader still reads all of what it wrote.
    (harness-case "every vector in the file is loaded"
      (lambda ()
        (check-equal "total" (length (resolution-vectors c)) 42)
        (check-equal "5.4.1"
                     (length (filter (lambda (v) (equal? (rv-section v) "5.4.1"))
                                     (resolution-vectors c)))
                     23)
        (check-equal "5.4.2"
                     (length (filter (lambda (v) (equal? (rv-section v) "5.4.2"))
                                     (resolution-vectors c)))
                     19)))

    ;; An id collision would make one row unreachable while every count still
    ;; agreed -- the same defect the harness treats as an error rather than a
    ;; failure for its own case ids.
    (harness-case "ids are unique"
      (lambda ()
        (let loop ((vs (resolution-vectors c)) (seen '()))
          (cond ((null? vs) (check "no duplicate id" #t))
                ((member (rv-id (car vs)) seen)
                 (check-fail "duplicate id" (rv-id (car vs))))
                (else (loop (cdr vs) (cons (rv-id (car vs)) seen)))))))

    (harness-case "a vector carries its section, reference and target"
      (lambda ()
        (let ((v (resolution-ref c "5.4.1/g")))
          (check "found" (and v #t))
          (check-equal "section"   (rv-section v)   "5.4.1")
          (check-equal "reference" (rv-reference v) "g")
          (check-equal "target"    (rv-target v)    "http://a/b/c/g"))))

    ;; The empty reference is a real vector of section 5.4.1 ("" resolves to
    ;; the base). A loader that skipped blank fields would drop it and still
    ;; look healthy, so it is named here rather than left to the count.
    (harness-case "the empty reference is a vector, not a blank line"
      (lambda ()
        (let ((v (resolution-ref c "5.4.1/")))
          (check "found" (and v #t))
          (check-equal "reference" (rv-reference v) "")
          (check-equal "target"    (rv-target v)    "http://a/b/c/d;p?q"))))

    ;; Decision 0015 item 2 rejects erratum 4547. If the corpus is ever edited
    ;; to adopt it, this is what says so.
    (harness-case "excess dot-segments resolve as published, not as erratum 4547"
      (lambda ()
        (check-equal "../../../g"
                     (rv-target (resolution-ref c "5.4.2/../../../g"))
                     "http://a/g")
        (check-equal "../../../../g"
                     (rv-target (resolution-ref c "5.4.2/../../../../g"))
                     "http://a/g")))

    (harness-case "the loader refuses a malformed row"
      (lambda ()
        (check-raises "not a three-element row"
                      corpus-error?
                      (lambda () (corpus-parse-resolution (list (list (quote base) "b")
                                                     (list (quote vectors) (list "5.4.1" "g"))))))))))

(harness-group "dot-segments"
  (lambda ()
    (define steps (corpus-load-dot-segments (corpus-path "dot-segments.scm")))

    (harness-case "both traces load, step for step"
      (lambda ()
        (check-equal "rows" (length steps) 13)
        (check-equal "trace 1" (length (filter (lambda (s) (= (ds-trace s) 1)) steps)) 8)
        (check-equal "trace 2" (length (filter (lambda (s) (= (ds-trace s) 2)) steps)) 5)))

    ;; The column reading, asserted from this side. Step 1's single field is
    ;; the INPUT buffer and the output buffer is empty; a reader that split on
    ;; whitespace inverts exactly this row and nothing else notices.
    (harness-case "step 1 initialises the input buffer, not the output buffer"
      (lambda ()
        (let ((s (car steps)))
          (check-equal "step"   (ds-step s)   "1")
          (check-equal "output" (ds-output s) "")
          (check-equal "input"  (ds-input s)  "/a/b/c/./../../g"))))

    (harness-case "a trace's last row carries the result and an empty input"
      (lambda ()
        (let ((last-of-1 (list-ref steps 7)))
          (check-equal "step"   (ds-step last-of-1)   "2E")
          (check-equal "output" (ds-output last-of-1) "/a/g")
          (check-equal "input"  (ds-input last-of-1)  ""))))))

(harness-group "example-uris"
  (lambda ()
    (define uris (corpus-load-examples (corpus-path "example-uris.scm")))
    (harness-case "eight schemes load"
      (lambda ()
        (check-equal "count" (length uris) 8)
        (check "urn is among them"
               (harness-member? "urn:oasis:names:specification:docbook:dtd:xml:4.1.2" uris))
        (check "the ldap example keeps its IPv6 literal"
               (harness-member? "ldap://[2001:db8::7]/c=GB?objectClass?one" uris))))))

;;; --- the comparator -----------------------------------------------------
;;;
;;; Two strings in, #f or a diagnostic out. It is the whole of what a lane over
;;; the corpus asserts, so it is judged on hand-built inputs before it is
;;; trusted over the committed one.
(harness-group "comparator"
  (lambda ()
    (harness-case "agreement is #f, not a truthy 'ok'"
      (lambda ()
        (check-equal "same" (compare-target "5.4.1/g" "http://a/b/c/g" "http://a/b/c/g") #f)))

    (harness-case "a difference names the id, the expectation and the actual"
      (lambda ()
        (let ((d (compare-target "5.4.1/g" "http://a/b/c/g" "http://a/b/c/X")))
          (check "a diagnostic" (string? d))
          (check "names the id"       (harness-string-contains? d "5.4.1/g"))
          (check "names the expected" (harness-string-contains? d "http://a/b/c/g"))
          (check "names the actual"   (harness-string-contains? d "http://a/b/c/X")))))

    ;; Absent is not empty -- decision 0008's distinction, which reaches the
    ;; comparator because a resolver that returned nothing at all would
    ;; otherwise compare equal to one that returned "".
    (harness-case "no result is not the same as an empty result"
      (lambda ()
        (check "#f actual is a difference" (string? (compare-target "x" "" #f)))
        (check-equal "empty equals empty"  (compare-target "x" "" "") #f)))))

;;; --- the ratchet --------------------------------------------------------
;;;
;;; Decision 0005 and the sibling's decision 0008 item 6 both require a TWO-WAY
;;; gate. A manifest that only fails when a passing vector breaks is a TODO
;;; list: it lets a vector start passing unnoticed, which is how a milestone's
;;; exit criterion stops being falsifiable.
(harness-group "ratchet"
  (lambda ()
    (define r (ratchet-parse '("passing  5.4.1/g" "not-yet  5.4.1/g:h")))

    (harness-case "a manifest reads as a status per id"
      (lambda ()
        (check-equal "count"  (length (ratchet-entries r)) 2)
        (check-equal "first"  (ratchet-status r "5.4.1/g") 'passing)
        (check-equal "second" (ratchet-status r "5.4.1/g:h") 'not-yet)
        (check-equal "absent" (ratchet-status r "5.4.1/nope") #f)))

    (harness-case "a passing entry that fails is a violation"
      (lambda ()
        (let ((v (ratchet-violations r '(("5.4.1/g" . #f) ("5.4.1/g:h" . "diff")))))
          (check-equal "none" v '()))))

    (harness-case "a passing entry that FAILS is caught"
      (lambda ()
        (let ((v (ratchet-violations r '(("5.4.1/g" . "diff") ("5.4.1/g:h" . "diff")))))
          (check-equal "one violation" (length v) 1)
          (check "names the regression"
                 (harness-string-contains? (car v) "5.4.1/g")))))

    ;; The direction a one-way ratchet misses.
    (harness-case "a not-yet entry that PASSES is caught"
      (lambda ()
        (let ((v (ratchet-violations r '(("5.4.1/g" . #f) ("5.4.1/g:h" . #f)))))
          (check-equal "one violation" (length v) 1)
          (check "names the unrecorded pass"
                 (harness-string-contains? (car v) "5.4.1/g:h")))))

    (harness-case "an id with no manifest row is a violation, not a skip"
      (lambda ()
        (let ((v (ratchet-violations r '(("5.4.1/g" . #f) ("5.4.1/g:h" . "diff")
                                         ("5.4.1/orphan" . #f)))))
          (check-equal "one violation" (length v) 1)
          (check "names the orphan"
                 (harness-string-contains? (car v) "orphan")))))

    (harness-case "a manifest row with no vector is a violation too"
      (lambda ()
        (let ((v (ratchet-violations r '(("5.4.1/g" . #f)))))
          (check-equal "one violation" (length v) 1)
          (check "names the stale row"
                 (harness-string-contains? (car v) "5.4.1/g:h")))))

    (harness-case "an unknown status word is refused"
      (lambda ()
        (check-raises "bogus status" ratchet-error?
                      (lambda () (ratchet-parse '("maybe  5.4.1/g"))))))

    (harness-case "comments and blank lines are not entries"
      (lambda ()
        (let ((r2 (ratchet-parse '("# a comment" "" "passing  5.4.1/g"))))
          (check-equal "count" (length (ratchet-entries r2)) 1))))))

;;; M1's exit criterion, said once as a case: every vector in the committed
;;; corpus has a status, and the two sets are the same set.
(harness-group "m1-exit"
  (lambda ()
    (harness-case "every corpus vector has a ratchet status and vice versa"
      (lambda ()
        (let* ((c (corpus-load-resolution (corpus-path "resolution.scm")))
               (r (ratchet-load (adapter-environment-variable "URI_RATCHET_FILE")))
               (ids (map rv-id (resolution-vectors c)))
               (missing (filter (lambda (id) (not (ratchet-status r id))) ids))
               (stale (filter (lambda (e) (not (harness-member? (ratchet-entry-id e) ids)))
                              (ratchet-entries r))))
          (check-equal "vectors with no status" missing '())
          (check-equal "statuses with no vector" (map ratchet-entry-id stale) '())
          (check-equal "counts agree"
                       (length (ratchet-entries r)) (length ids)))))))

(harness-finish)
