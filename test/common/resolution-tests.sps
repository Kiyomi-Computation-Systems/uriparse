#!r6rs
;;; conformance.resolution -- RFC 3986 §5.4, the normative resolution gate.
;;;
;;; This is the ONE normative corpus this project has, and all 42 rows must
;;; pass. Each row resolves a
;;; reference against the base §5.4 declares (http://a/b/c/d;p?q); the expected
;;; target is the RFC's own published string. The pipeline under test is the
;;; whole resolution stack end to end: `(uri collect)` parses the base (mode
;;; `uri`) and the reference (mode `uri-reference`), `(uri resolve)` transforms
;;; per §5.2.2 (strict), and `(uri recompose)` renders the target per §5.3 --
;;; then the recomposed bytes are compared BYTE-EXACT to the corpus string
;;; (recompose-and-compare-strings keeps the corpus a pure string
;;; oracle, no parser in the grading path for the expected value).
;;;
;;; The gate is TWO-WAY (the ratchet): every row is marked
;;; `passing` in ratchet.txt, so a row that fails is a regression AND a row
;;; marked `not-yet` that passes is a violation too. The
;;; gate passes when `ratchet-violations` is empty over all 42.
(import (rnrs)
        (uri test harness)
        (uri test corpus)
        (uri test ratchet)
        (uri components)
        (uri collect)
        (uri path)
        (uri normalize)
        (uri resolve)
        (uri recompose))

(define (corpus-path name)
  (string-append (adapter-environment-variable "URI_CORPUS_DIR") "/" name))

(define resolution
  (corpus-load-resolution (corpus-path "resolution.scm")))

;; The base, parsed once as an absolute URI.
(define base-result (uri-parse 'uri (string->utf8 (resolution-base resolution))))
(define base-components (uri-parse-components base-result))

;; target-of : String -> (Option String)
;; Parse the reference as a URI-reference (mode 3), resolve it against the base,
;; recompose the target, and read the bytes back as a string. #f if the
;; reference does not parse -- which `compare-target` reports as a difference,
;; never as an equal-to-empty.
(define (target-of reference)
  (let ((pr (uri-parse 'uri-reference (string->utf8 reference))))
    (and (uri-parse-ok? pr)
         (utf8->string
          (recompose (resolve-components base-components (uri-parse-components pr)))))))

(harness-begin "conformance.resolution")

;; A sanity check that the base itself parses into the components §5.4 assumes;
;; if this is wrong, every row would fail and read as a resolver defect.
(harness-group "the base parses as §5.4 declares"
  (lambda ()
    (harness-case "http://a/b/c/d;p?q splits correctly"
      (lambda ()
        (check "base parses" (uri-parse-ok? base-result))
        (check-equal "scheme"   (uri-components-scheme base-components)    (string->utf8 "http"))
        (check-equal "authority"(uri-components-authority base-components) (string->utf8 "a"))
        (check-equal "path"     (uri-components-path base-components)      (string->utf8 "/b/c/d;p"))
        (check-equal "query"    (uri-components-query base-components)     (string->utf8 "q"))
        (check "no fragment"    (not (uri-components-fragment base-components)))))))

;;; --- every §5.4 row resolves to its published target ------------------------
(harness-group "§5.4 reference resolution examples"
  (lambda ()
    (for-each
     (lambda (v)
       (harness-case (string-append (rv-id v) " -> " (rv-target v))
         (lambda ()
           (let ((diff (compare-target (rv-id v) (rv-target v) (target-of (rv-reference v)))))
             (check (string-append (rv-id v) " resolves as published")
                    (not diff))
             (when diff (check-fail (rv-id v) diff))))))
     (resolution-vectors resolution))))

;;; --- the two-way ratchet: all 42 passing, nothing else moving ---------------
(harness-group "the ratchet holds at 42/42"
  (lambda ()
    (define r (ratchet-load (adapter-environment-variable "URI_RATCHET_FILE")))
    ;; The actual result per id: #f on agreement, a diagnostic on difference.
    (define results
      (map (lambda (v)
             (cons (rv-id v)
                   (compare-target (rv-id v) (rv-target v) (target-of (rv-reference v)))))
           (resolution-vectors resolution)))

    (harness-case "no ratchet violations (no regression, no unrecorded pass)"
      (lambda ()
        (let ((violations (ratchet-violations r results)))
          (check-equal "violations" violations '()))))

    (harness-case "every row is recorded passing"
      (lambda ()
        (check-equal "count" (length (ratchet-entries r)) 42)
        (for-each
         (lambda (e)
           (check (string-append (ratchet-entry-id e) " passing")
                  (eq? (ratchet-status r (ratchet-entry-id e)) 'passing)))
         (ratchet-entries r))))))

;;; --- the normalize-then-resolve ordering, made a live property --------------
;;; §6.2.2.2 normalization decodes `%2E` to a literal `.`, so `pct-normalize`
;;; MANUFACTURES dot-segments; §5.2.4 remove-dot-segments only acts on literal
;;; `.`/`..`. So normalize-BEFORE-resolve applies an encoded `../`, while
;;; resolving a RAW path leaves it encoded and inert. The order is
;;; security-relevant, and here it is pinned rather than only documented:
;;; unit.normalize pins the normalize half (pct-normalize `/a/%2E%2E/b` ->
;;; `/a/../b`), and this is the resolve half.
(harness-group "normalize-before-resolve neutralizes encoded traversal"
  (lambda ()
    (harness-case "normalized first, the encoded ../ is applied"
      (lambda ()
        (check-equal "/a/%2E%2E/b normalized then dot-removed -> /b"
                     (remove-dot-segments (pct-normalize (string->utf8 "/a/%2E%2E/b")))
                     (string->utf8 "/b"))))
    (harness-case "resolved raw, the encoded ../ stays inert"
      (lambda ()
        (check-equal "/a/%2E%2E/b dot-removed raw -> unchanged"
                     (remove-dot-segments (string->utf8 "/a/%2E%2E/b"))
                     (string->utf8 "/a/%2E%2E/b"))))))

(harness-finish)
