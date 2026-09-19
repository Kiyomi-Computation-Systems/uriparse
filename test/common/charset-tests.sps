#!r6rs
;;; unit.charset -- the M3 charset validator (decision 0024). Graded three ways:
;;; against the INDEPENDENT oracle (they agree on every byte), against the
;;; negative corpus (every row rejected with the recorded code and ABSOLUTE
;;; offset, end to end through uri-parse-validate), and against the positive
;;; corpora (all accepted -- the reject-everything guard). The oracle
;;; (uri test charset-oracle) and the product (uri charset) are two independent
;;; readings of the same ABNF; their agreement is the check (decisions 0005/0012).
(import (rnrs)
        (uri test harness)
        (uri charset)
        (uri collect)
        (uri components)
        (uri test charset-oracle)
        (uri test corpus))

(define (charset-path name)
  (string-append (adapter-environment-variable "URI_CHARSET_DIR") "/" name))
(define (corpus-path name)
  (string-append (adapter-environment-variable "URI_CORPUS_DIR") "/" name))

(harness-begin "unit.charset")

;; --- the core error vocabulary (decision 0024 item 5) --------------------
(harness-group "the core error vocabulary"
  (lambda ()
    (harness-case "the five codes, named per ABNF production, out of the scanner set"
      (lambda ()
        (for-each (lambda (c) (check (symbol->string c) (uri-charset-error-code? c)))
                  '(invalid-scheme invalid-pchar invalid-query invalid-fragment
                    invalid-pct-encoded))
        (check-equal "count" (length uri-charset-error-codes) 5)
        (check-equal "a scanner code is not a charset code"
                     (uri-charset-error-code? 'scheme-required) #f)))))

;; --- agreement with the independent oracle -------------------------------
;; validate-component (src) and oracle-scan (test) must return the SAME code and
;; relative index for every input. Exhaustive over single bytes, then a battery
;; of multi-byte and pct-encoded shapes.
(harness-group "validate-component agrees with the oracle"
  (lambda ()
    (define (agree? component bv)
      (let-values (((oc oi) (oracle-scan component bv))
                   ((vc vi) (validate-component component bv)))
        (and (eq? oc vc) (equal? oi vi))))
    (harness-case "every single byte 0..255, in every component"
      (lambda ()
        (for-each
         (lambda (component)
           (let loop ((b 0))
             (when (< b 256)
               (check (string-append (symbol->string component) " byte " (number->string b))
                      (agree? component (make-bytevector 1 b)))
               (loop (+ b 1)))))
         '(scheme path query fragment))))
    (harness-case "multi-byte and pct-encoded shapes"
      (lambda ()
        (for-each
         (lambda (component)
           (for-each
            (lambda (s)
              (check (string-append (symbol->string component) " "
                                    (if (string=? s "") "(empty)" s))
                     (agree? component (string->utf8 s))))
            '("" "a" "abc" "%" "%A" "%AB" "%ab" "%AG" "%GA" "%%" "%%41" "%4"
              "a%20b" "x%2Fy" "/a/b" ":@" "?" "a b" "a?b" "1a" "+x" "ab_c"
              "a.b-c+d" "urn:x" "c=GB")))
         '(scheme path query fragment))))
    (harness-case "exhaustive pct-encoded: every %XY agrees (the two-HEXDIG path)"
      (lambda ()
        ;; The single-byte sweep never reaches the two-HEXDIG path (a lone "%"
        ;; fails the length guard first), so the validator's hex-digit-value and
        ;; the oracle's oracle-hexdig? agreeing on all 256 bytes is otherwise
        ;; unasserted. Sweep every %XY -- one accumulator check, not 65536 harness
        ;; checks. The pct scan is component-independent, so `path` covers all.
        (let ((bad '()))
          (do ((b1 0 (+ b1 1))) ((= b1 256))
            (do ((b2 0 (+ b2 1))) ((= b2 256))
              (unless (agree? 'path (u8-list->bytevector (list 37 b1 b2)))
                (set! bad (cons (list b1 b2) bad)))))
          (check-equal "no %XY disagreements over 256x256" bad '()))))))

;; --- the negative corpus: rejected, with the exact code and absolute offset --
(harness-group "the negative corpus is rejected, exactly"
  (lambda ()
    (define rows (negative-load (charset-path "negative.scm")))
    (harness-case "every row: not ok, the recorded code and ABSOLUTE offset"
      (lambda ()
        (for-each
         (lambda (v)
           (let ((r (uri-parse-validate (nv-mode v) (nv-input v))))
             (check (string-append "rejected: " (nv-note v)) (not (uri-parse-ok? r)))
             (check-equal (string-append "code: " (nv-note v))
                          (uri-parse-error-code r) (nv-code v))
             (check-equal (string-append "offset: " (nv-note v))
                          (uri-parse-error-offset r) (nv-offset v))))
         rows)))))

;; --- the positive corpora are ACCEPTED (the reject-everything guard) ------
;; A validator that rejected everything would pass the negative group; these
;; RFC-authored URIs are all charset-valid and must survive validation.
(harness-group "the positive corpora are accepted"
  (lambda ()
    (harness-case "all eight §1.1.2 examples validate ok"
      (lambda ()
        (let ((uris (corpus-load-examples (corpus-path "example-uris.scm"))))
          (check-equal "count" (length uris) 8)
          (for-each (lambda (u)
                      (check (string-append "ok: " u)
                             (uri-parse-ok? (uri-parse-validate 'uri (string->utf8 u)))))
                    uris))))
    (harness-case "all 42 §5.4 resolution targets validate ok"
      (lambda ()
        (let* ((c (corpus-load-resolution (corpus-path "resolution.scm")))
               (targets (map rv-target (resolution-vectors c))))
          (check-equal "count" (length targets) 42)
          (for-each (lambda (t)
                      (check (string-append "ok: " t)
                             (uri-parse-ok? (uri-parse-validate 'uri (string->utf8 t)))))
                    targets))))
    (harness-case "a structural error still passes straight through"
      (lambda ()
        (let ((r (uri-parse-validate 'uri (string->utf8 "foo/bar"))))
          (check "not ok" (not (uri-parse-ok? r)))
          (check-equal "scheme-required, not a charset code"
                       (uri-parse-error-code r) 'scheme-required))))))

(harness-finish)
