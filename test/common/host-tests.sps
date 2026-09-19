#!r6rs
;;; unit.host -- the M4 host-grammar validator (decision 0025). Graded three ways,
;;; like unit.charset: against the INDEPENDENT oracle (they agree on every input --
;;; a shape battery plus exhaustive dec-octet / h16 / group-count sweeps), against
;;; the negative corpus (every row rejected with the recorded code and ABSOLUTE
;;; offset, end to end through uri-parse-validate), and against the positive corpora
;;; (all accepted -- the reject-everything guard). The oracle (uri test host-oracle)
;;; and the product (uri host) are two independent readings of the same ABNF; their
;;; agreement is the check (decisions 0005 / 0012 / 0025).
(import (rnrs)
        (uri test harness)
        (uri host)
        (uri collect)
        (uri components)
        (uri test host-oracle)
        (uri test corpus))

(define (host-path name)
  (string-append (adapter-environment-variable "URI_HOST_DIR") "/" name))
(define (corpus-path name)
  (string-append (adapter-environment-variable "URI_CORPUS_DIR") "/" name))

;; validate-authority (src) and oracle-scan-authority (test) must return the SAME
;; code and relative index for every authority bytevector.
(define (agree? bv)
  (let-values (((oc oi) (oracle-scan-authority bv))
               ((vc vi) (validate-authority bv)))
    (and (eq? oc vc) (equal? oi vi))))
(define (agree-s? s) (agree? (string->utf8 s)))

(harness-begin "unit.host")

;; --- the core error vocabulary (decision 0025 item 6) --------------------
(harness-group "the core host error vocabulary"
  (lambda ()
    (harness-case "the six codes, named per ABNF production, out of the scanner set"
      (lambda ()
        (for-each (lambda (c) (check (symbol->string c) (uri-host-error-code? c)))
                  '(invalid-userinfo invalid-reg-name invalid-ip-literal
                    invalid-dec-octet invalid-port invalid-pct-encoded))
        (check-equal "count" (length uri-host-error-codes) 6)
        (check-equal "a scanner code is not a host code"
                     (uri-host-error-code? 'scheme-required) #f)))))

;; --- agreement with the independent oracle -------------------------------
(harness-group "validate-authority agrees with the oracle"
  (lambda ()
    (harness-case "a battery of shapes -- valid and every fault kind"
      (lambda ()
        (for-each
         (lambda (s) (check (if (string=? s "") "(empty)" s) (agree-s? s)))
         '(;; valid
           "" "host" "example.com" "user@host" "user:pass@host" "host:80" "host:"
           "192.168.0.1" "999.1.1.1" "[::1]" "[::]" "[2001:db8::1]"
           "[1:2:3:4:5:6:7:8]" "[1:2:3:4:5:6:1.2.3.4]" "[::ffff:192.168.0.1]"
           "[v1.a]" "user:pass@[::1]:443" "@host" "sub.dom.example"
           ;; the "::" total boundary: with "::" the pieces total <= 7
           "[1:2:3:4:5:6:7::]" "[1:2:3:4:5:6::8]" "[::1]:80"
           "[1:2:3:4:5:6:7:8::]" "[1:2:3:4:5:6:7::8]"
           ;; faults across userinfo / reg-name / port / ip-literal / dec-octet
           "us er@h" "a<b@h" "a%z@h" "h st" "a@b@c" "h%g" "h:8x" "h:a" "h: "
           "[::1" "[xyz]" "[]" "[12345::1]" "[1:2:3:4:5:6:7:8:9]" "[:1]" "[1:]"
           "[::ffff:999.1.1.1]" "[::1.2.3.256]" "[vG.a]" "[::1]x" "[::1]:8x")))
      )
    (harness-case "exhaustive dec-octet sweep: bracketed hits the range, bare stays reg-name"
      (lambda ()
        ;; 0..300 as the last octet: inside "[...]" the 255/256 edge bites
        ;; (invalid-dec-octet); bare it is always a valid reg-name. One accumulator
        ;; check, not 600 harness checks.
        (let ((bad '()))
          (do ((v 0 (+ v 1))) ((= v 301))
            (let ((n (number->string v)))
              (unless (agree-s? (string-append "[::1.2.3." n "]"))
                (set! bad (cons (list 'bracket v) bad)))
              (unless (agree-s? (string-append n ".1.1.1"))
                (set! bad (cons (list 'bare v) bad)))))
          (check-equal "no dec-octet disagreements over 0..300" bad '()))))
    (harness-case "exhaustive h16 length sweep: 1-4 HEXDIG valid, 5+ invalid"
      (lambda ()
        (let ((bad '()))
          (do ((len 1 (+ len 1))) ((= len 8))
            (let ((h (make-string len #\a)))
              (unless (agree-s? (string-append "[" h "::1]"))
                (set! bad (cons len bad)))))
          (check-equal "no h16-length disagreements over 1..7" bad '()))))
    (harness-case "exhaustive group-count sweep: eight pieces valid, else invalid"
      (lambda ()
        (let ((bad '()))
          (do ((k 1 (+ k 1))) ((= k 11))
            ;; k h16 groups "1", no "::" -> valid only at k = 8
            (let loop ((i 1) (acc "1"))
              (if (= i k)
                  (unless (agree-s? (string-append "[" acc "]"))
                    (set! bad (cons k bad)))
                  (loop (+ i 1) (string-append acc ":1")))))
          (check-equal "no group-count disagreements over 1..10" bad '()))))))

;; --- the negative corpus: rejected, with the exact code and absolute offset --
(harness-group "the negative corpus is rejected, exactly"
  (lambda ()
    (define rows (negative-load (host-path "negative.scm")))
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
(harness-group "the positive corpora are accepted"
  (lambda ()
    (harness-case "all eight §1.1.2 examples validate ok (incl. the ldap IPv6 host)"
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
    (harness-case "explicit valid authorities validate ok"
      (lambda ()
        (for-each
         (lambda (u)
           (check (string-append "ok: " u)
                  (uri-parse-ok? (uri-parse-validate 'uri (string->utf8 u)))))
         '("http://user:pass@[::1]:8080/p" "http://[2001:db8::1]"
           "http://192.168.0.1:80/" "http://example.com" "http:///p"
           "http://user@host" "ldap://[2001:db8::7]/c=GB"))))
    (harness-case "a structural error still passes straight through"
      (lambda ()
        (let ((r (uri-parse-validate 'uri (string->utf8 "foo/bar"))))
          (check "not ok" (not (uri-parse-ok? r)))
          (check-equal "scheme-required, not a host code"
                       (uri-parse-error-code r) 'scheme-required))))))

(harness-finish)
