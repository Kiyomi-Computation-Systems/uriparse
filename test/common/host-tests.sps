#!r6rs
;;; unit.host -- the host-grammar validator. Graded three ways,
;;; like unit.charset: against the INDEPENDENT oracle (they agree on every input --
;;; a shape battery plus exhaustive dec-octet / h16 / group-count sweeps), against
;;; the negative corpus (every row rejected with the recorded code and ABSOLUTE
;;; offset, end to end through uri-parse-validate), and against the positive corpora
;;; (all accepted -- the reject-everything guard). The oracle (uri test host-oracle)
;;; and the product (uri host) are two independent readings of the same ABNF; their
;;; agreement is the check.
(import (rnrs)
        (uri test harness)
        (uri host)
        (uri collect)
        (uri components)
        (uri test host-oracle)
        (uri test corpus)
        (uri test ranged))

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

;; Authorities valid and invalid, one per fault kind: graded whole, and as a span.
(define authority-battery
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
    "[::ffff:999.1.1.1]" "[::1.2.3.256]" "[::1]x" "[::1]:8x"
    ;; IPvFuture = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
    "[vG.a]" "[v1z]" "[v.a]" "[v1.]" "[vFF.foo]" "[V2.a:b]" "[v1a.x-y~z]"))

(harness-begin "unit.host")

;; --- the core error vocabulary -------------------------------------------
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
         authority-battery)))
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

;; --- over a range ----------------------------------------------------------
;; A server holding a Host header value as [start, end) of its line judges it in
;; place. As for validate-component: the verdict is the verdict on
;; the span ALONE, nothing outside it is read, and every number returned -- the
;; fault index, the host bounds -- is relative to start.
(harness-group "validate-authority and authority-host-span over a range"
  (lambda ()
    (define (bytes s) (string->utf8 s))
    (define (fault bv . range) (apply results-of validate-authority bv range))
    (define (host-bounds bv . range) (apply results-of authority-host-span bv range))
    ;; Each surrounding is hostile to one way of reading outside the span: " " is
    ;; invalid in every part; a leading "@" or "[" re-splits a scan from 0; a
    ;; trailing "]", "@x", "x:" or " :1" completes a delimiter search bounded by
    ;; the buffer instead of end (" :1" also makes the stretch up to it invalid);
    ;; a trailing "[" opens a literal right after an empty host that ends at end;
    ;; "41" completes a "%" or "%4" cut at end.
    (define surroundings
      '(("" . "") (" " . "") ("" . " ") ("@" . "") ("[" . "") ("" . "]")
        ("" . "@x") ("" . "x:") ("" . " :1") ("" . "[") ("" . "41") ("ab@" . ":1")))
    ;; The host's [start, end) within an authority, derived by hand from the split
    ;; after the first "@" (or at 0), to the closing "]"
    ;; inclusive for an IP-literal (to the end if unterminated), else to the first
    ;; ":" after it, else to the end.
    (define host-span-pins
      '(("" 0 0) ("host" 0 4) ("user@host" 5 9) ("user:pass@host:80" 10 14)
        ("host:80" 0 4) ("host:" 0 4) ("[::1]" 0 5) ("[::1]:80" 0 5)
        ("u@[::1]:443" 2 7) ("[::1" 0 4) ("user@" 5 5) ("@host" 1 5)
        ("a@b@c" 2 5) ("[v1.a]:8" 0 6) ("h:8:9" 0 1)))
    (harness-case "validate-authority: the oracle's verdict on the span alone, whatever surrounds it"
      (lambda ()
        (let ((bad '()))
          (for-each
           (lambda (s)
             (for-each-placement surroundings s
              (lambda (around buf start end)
                (unless (equal? (fault buf start end)
                                (results-of oracle-scan-authority (bytes s)))
                  (set! bad (cons (list around s) bad))))))
           (append authority-battery '("h%4" "h%" "u%4@h" "%" "[" "user@")))
          (check-equal "no disagreements" bad '()))))
    (harness-case "authority-host-span: the pinned bounds, whole and as a span"
      (lambda ()
        (for-each
         (lambda (pin)
           (check-equal (string-append "whole: " (car pin))
                        (host-bounds (bytes (car pin))) (cdr pin)))
         host-span-pins)
        (let ((bad '()))
          (for-each
           (lambda (pin)
             (for-each-placement surroundings (car pin)
              (lambda (around buf start end)
                (unless (equal? (host-bounds buf start end) (cdr pin))
                  (set! bad (cons (list around (car pin)) bad))))))
           host-span-pins)
          (check-equal "every span has its pinned bounds, relative to start" bad '()))))
    (harness-case "pinned: Host header values, judged in place"
      (lambda ()
        ;; (line start end fault host-bounds); "Host: " is 6 bytes.
        (for-each
         (lambda (row)
           (let ((line (bytes (car row))) (s (cadr row)) (e (caddr row)))
             (check-equal (string-append "fault: " (car row))
                          (fault line s e) (list-ref row 3))
             (check-equal (string-append "host: " (car row))
                          (host-bounds line s e) (list-ref row 4))))
         '(("Host: example.com:8080\r\n" 6 22 (#f #f) (0 11))
           ("Host: [::1]:8080\r\n" 6 16 (#f #f) (0 5))
           ("Host: x\r\n" 6 7 (#f #f) (0 1))
           ("Host: h st\r\n" 6 10 (invalid-reg-name 1) (0 4))
           ("Host: x:8x\r\n" 6 10 (invalid-port 3) (0 1))
           ;; a valid authority: refusing the userinfo is the server's rule
           ("Host: u@h\r\n" 6 9 (#f #f) (2 3))
           ;; the "]" past end does not close the literal
           ("Host: [::1]\r\n" 6 10 (invalid-ip-literal 0) (0 4))
           ("Host: h%41\r\n" 6 9 (invalid-pct-encoded 1) (0 3))))
        (check-equal "the whole line is no authority"
                     (fault (bytes "Host: x\r\n")) '(invalid-port 5))
        (check-equal "start alone runs to the end" (fault (bytes " x:8x") 1) '(invalid-port 3))
        (check-equal "start alone, host bounds" (host-bounds (bytes " u@h:1") 1) '(2 3))))
    (harness-case "a range outside the bytevector is refused, by the procedure called"
      (lambda ()
        ;; ONE value out of each thunk, and the raise must name the procedure
        ;; called (see (uri test ranged) for why each).
        (let ((bv (bytes "a b")))
          (for-each
           (lambda (range)
             (check-raises (string-append "validate-authority "
                                          (adapter-value->string range))
                           (raised-by? 'validate-authority)
                           (lambda () (apply fault bv range)))
             (check-raises (string-append "authority-host-span "
                                          (adapter-value->string range))
                           (raised-by? 'authority-host-span)
                           (lambda () (apply host-bounds bv range))))
           '((1 0) (0 9) (4) (-1 2) (0 1.5) (x 2)))
          (check-equal "[length, length) is the empty authority" (fault bv 3 3) '(#f #f))
          (check-equal "[length, length) has the empty host" (host-bounds bv 3 3) '(0 0)))))
    (harness-case "judging a span allocates nothing that grows with its length"
      (lambda ()
        ;; Each shape at two lengths, as the value span of a "Host: ...\r\n" line.
        (define (allocated f value)
          (let ((line (bytes (string-append "Host: " value "\r\n")))
                (e (+ 6 (bytevector-length (bytes value)))))
            (least-allocation 1000 (lambda () (f line 6 e)))))
        (define (long n) (make-string n #\a))
        (for-each
         (lambda (f name)
           (for-each
            (lambda (shape)   ; (label short long)
              (check-equal (string-append name ", " (car shape)
                                          ": a short and a 4000-byte value allocate alike")
                           (allocated f (cadr shape)) (allocated f (caddr shape))))
            (list (list "reg-name" "a" (long 4000))
                  (list "IPvFuture" "[v1.a]" (string-append "[v1." (long 4000) "]"))
                  (list "userinfo, host, port" "u@h:80"
                        (string-append (long 4000) "@h:80")))))
         (list validate-authority authority-host-span)
         '("validate-authority" "authority-host-span"))))))

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
           "http://user@host" "ldap://[2001:db8::7]/c=GB"
           "http://[vFF.foo]/p" "http://[v1a.x-y~z]"))))
    (harness-case "a structural error still passes straight through"
      (lambda ()
        (let ((r (uri-parse-validate 'uri (string->utf8 "foo/bar"))))
          (check "not ok" (not (uri-parse-ok? r)))
          (check-equal "scheme-required, not a host code"
                       (uri-parse-error-code r) 'scheme-required))))))

(harness-finish)
