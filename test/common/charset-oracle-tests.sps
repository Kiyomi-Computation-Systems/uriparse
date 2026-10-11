#!r6rs
;;; unit.charset-oracle -- the charset oracle and its negative corpus, judged
;;; independently of the src validator.
;;;
;;; Two artifacts are gated against each other here:
;;; (uri test charset-oracle), a reading of RFC 3986's component charsets derived
;;; from the ABNF independently of the src validator; and
;;; the hand-derived negative corpus. The corpus is CROSS-CHECKED against the
;;; oracle -- a row whose (component, code, offset) the oracle disagrees with
;;; reddens -- so neither can drift from the ABNF unnoticed (oracle discipline).
;;; The src (uri charset) validator is graded against BOTH in unit.charset.
(import (rnrs)
        (uri test harness)
        (uri test charset-oracle))

(define (charset-path name)
  (string-append (adapter-environment-variable "URI_CHARSET_DIR") "/" name))

(define (scan component s)
  (call-with-values (lambda () (oracle-scan component (string->utf8 s)))
    (lambda (code index) (cons code index))))

(harness-begin "unit.charset-oracle")

;; The oracle's own byte sets, pinned so a mutation to them is caught here and
;; not only downstream where it would read as a validator defect.
(harness-group "the ABNF byte sets"
  (lambda ()
    (harness-case "unreserved is ALPHA / DIGIT / - . _ ~ and nothing else"
      (lambda ()
        (check "A" (oracle-unreserved? #x41))
        (check "z" (oracle-unreserved? #x7A))
        (check "0" (oracle-unreserved? #x30))
        (check "-" (oracle-unreserved? #x2D))
        (check "~" (oracle-unreserved? #x7E))
        (check-equal "space is not unreserved" (oracle-unreserved? #x20) #f)
        (check-equal "% is not unreserved" (oracle-unreserved? #x25) #f)))
    (harness-case "sub-delims is the eleven, and : is not one"
      (lambda ()
        (for-each (lambda (b)
                    (check (string-append "sub-delim " (number->string b))
                           (oracle-sub-delim? b)))
                  '(#x21 #x24 #x26 #x27 #x28 #x29 #x2A #x2B #x2C #x3B #x3D))
        (check-equal ": is not a sub-delim" (oracle-sub-delim? #x3A) #f)))
    (harness-case "HEXDIG admits both cases; G/g do not"
      (lambda ()
        (check "9" (oracle-hexdig? #x39))
        (check "F" (oracle-hexdig? #x46))
        (check "f" (oracle-hexdig? #x66))
        (check-equal "G is not HEXDIG" (oracle-hexdig? #x47) #f)
        (check-equal "g is not HEXDIG" (oracle-hexdig? #x67) #f)))))

;; The reference validator, on knowns: clean components, and the exact code +
;; component-relative index for a fault of each kind.
(harness-group "oracle-scan"
  (lambda ()
    (harness-case "valid components scan clean"
      (lambda ()
        (check-equal "scheme http"   (scan 'scheme "http")      '(#f . #f))
        (check-equal "path pchars"   (scan 'path "/a:b@c/d")    '(#f . #f))
        (check-equal "path %20"      (scan 'path "/a%20b")      '(#f . #f))
        (check-equal "query ? and /" (scan 'query "a=1&b=2/?")  '(#f . #f))
        (check-equal "fragment %2F"  (scan 'fragment "x%2Fy")   '(#f . #f))))
    (harness-case "faults name the code and the relative index"
      (lambda ()
        (check-equal "empty scheme"    (scan 'scheme "")      '(invalid-scheme . 0))
        (check-equal "digit-first"     (scan 'scheme "1a")    '(invalid-scheme . 0))
        (check-equal "scheme _"        (scan 'scheme "ab_c")  '(invalid-scheme . 2))
        (check-equal "path space"      (scan 'path "/a b")    '(invalid-pchar . 2))
        (check-equal "bad first hex"   (scan 'path "/%g0")    '(invalid-pct-encoded . 1))
        (check-equal "trailing %"      (scan 'path "/a%")     '(invalid-pct-encoded . 2))))))

;; The corpus, cross-checked against the oracle: one check per row, plus the
;; per-production floors that keep the set from silently shrinking.
(harness-group "the negative corpus"
  (lambda ()
    (define rows (negative-load (charset-path "negative.scm")))
    (harness-case "every row is consistent with the oracle"
      (lambda ()
        (for-each
         (lambda (v)
           (let ((diag (negative-cross-check v)))
             (if diag
                 (check-fail (symbol->string (nv-code v)) diag)
                 (check (nv-note v) #t))))
         rows)))
    (harness-case "per-production coverage floors hold"
      (lambda ()
        (define (count code)
          (length (filter (lambda (v) (eq? (nv-code v) code)) rows)))
        (check-equal "scheme floor >= 3"   (>= (count 'invalid-scheme) 3) #t)
        (check-equal "pchar floor >= 3"    (>= (count 'invalid-pchar) 3) #t)
        (check-equal "pct floor >= 3"      (>= (count 'invalid-pct-encoded) 3) #t)
        (check-equal "query floor >= 1"    (>= (count 'invalid-query) 1) #t)
        (check-equal "fragment floor >= 1" (>= (count 'invalid-fragment) 1) #t)))))

(harness-finish)
