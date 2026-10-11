#!r6rs
;;; unit.host-oracle -- the host-grammar oracle and its negative corpus, judged
;;; independently of the src validator.
;;;
;;; Two artifacts are gated against each other here:
;;; (uri test host-oracle), a reading of RFC 3986 §3.2's authority grammar derived
;;; from the ABNF independently of the src (uri host) validator; and
;;; the hand-derived negative corpus. The corpus is CROSS-CHECKED against
;;; the oracle -- a row whose (component, code, absolute-offset) the oracle
;;; disagrees with reddens -- so neither can drift from the ABNF unnoticed (oracle
;;; discipline). The src (uri host) validator is graded against BOTH in unit.host.
(import (rnrs)
        (uri test harness)
        (uri test host-oracle))

(define (host-path name)
  (string-append (adapter-environment-variable "URI_HOST_DIR") "/" name))

;; scan an authority given as a STRING; returns (cons code relative-index).
(define (scan s)
  (call-with-values (lambda () (oracle-scan-authority (string->utf8 s)))
    (lambda (code index) (cons code index))))

(harness-begin "unit.host-oracle")

;; The oracle's own byte sets, pinned so a mutation to them is caught here and not
;; only downstream where it would read as a validator defect.
(harness-group "the ABNF byte sets"
  (lambda ()
    (harness-case "unreserved is ALPHA / DIGIT / - . _ ~ and nothing else"
      (lambda ()
        (check "A" (oracle-unreserved? #x41))
        (check "0" (oracle-unreserved? #x30))
        (check "~" (oracle-unreserved? #x7E))
        (check-equal "space is not unreserved" (oracle-unreserved? #x20) #f)
        (check-equal "@ is not unreserved" (oracle-unreserved? #x40) #f)))
    (harness-case "userinfo admits \":\"; reg-name does not"
      (lambda ()
        (check "userinfo :" (oracle-userinfo-literal? #x3A))
        (check-equal "reg-name : is not a literal" (oracle-reg-name-literal? #x3A) #f)
        (check-equal "userinfo @ is not a literal" (oracle-userinfo-literal? #x40) #f)))
    (harness-case "HEXDIG admits both cases; G/g do not"
      (lambda ()
        (check "F" (oracle-hexdig? #x46))
        (check "f" (oracle-hexdig? #x66))
        (check-equal "G is not HEXDIG" (oracle-hexdig? #x47) #f)))))

;; The reference validator on knowns: valid authorities scan clean (incl. the
;; ordered-union tail -- a dotted quad is a reg-name -- and the IPv6 counter), and
;; each fault names its code and authority-relative index.
(harness-group "oracle-scan-authority"
  (lambda ()
    (harness-case "valid authorities scan clean"
      (lambda ()
        (check-equal "userinfo"   (scan "user@host")            '(#f . #f))
        (check-equal "host:port"  (scan "host:80")              '(#f . #f))
        (check-equal "reg-name"   (scan "example.com")          '(#f . #f))
        (check-equal "empty auth" (scan "")                     '(#f . #f))
        (check-equal "empty host" (scan "user@")                '(#f . #f))
        (check-equal "empty port" (scan "host:")               '(#f . #f))))
    (harness-case "a dotted quad is a valid reg-name (first-match-wins)"
      (lambda ()
        ;; §3.2.2: IPv4address is tried, and 999.1.1.1 fails it, but reg-name
        ;; admits digits and dots -- so it is a VALID host, not invalid-dec-octet.
        (check-equal "1.2.3.4"     (scan "1.2.3.4")             '(#f . #f))
        (check-equal "999.1.1.1"   (scan "999.1.1.1")           '(#f . #f))))
    (harness-case "IPv6 literals: the counting model accepts the valid shapes"
      (lambda ()
        (check-equal "8 groups"    (scan "[1:2:3:4:5:6:7:8]")   '(#f . #f))
        (check-equal "compressed"  (scan "[2001:db8::1]")       '(#f . #f))
        (check-equal "just ::"     (scan "[::]")                '(#f . #f))
        (check-equal "1::"         (scan "[1::]")               '(#f . #f))
        (check-equal "ipv4 tail"   (scan "[1:2:3:4:5:6:1.2.3.4]") '(#f . #f))
        (check-equal "mapped v4"   (scan "[::ffff:192.168.0.1]") '(#f . #f))))
    (harness-case "faults name the code and the authority-relative index"
      (lambda ()
        (check-equal "userinfo space" (scan "us er@h")         '(invalid-userinfo . 2))
        (check-equal "userinfo <"     (scan "a<b@h")           '(invalid-userinfo . 1))
        (check-equal "userinfo %"     (scan "a%z@h")           '(invalid-pct-encoded . 1))
        (check-equal "reg-name space" (scan "h st")            '(invalid-reg-name . 1))
        (check-equal "second @"       (scan "a@b@c")           '(invalid-reg-name . 3))
        (check-equal "reg-name %"     (scan "h%g")             '(invalid-pct-encoded . 1))
        (check-equal "port letter"    (scan "h:8x")            '(invalid-port . 3))))
    (harness-case "IP-literal faults report at the \"[\", dec-octet only in brackets"
      (lambda ()
        (check-equal "unterminated"  (scan "[::1")             '(invalid-ip-literal . 0))
        (check-equal "not ipv6"      (scan "[xyz]")            '(invalid-ip-literal . 0))
        (check-equal "nine groups"   (scan "[1:2:3:4:5:6:7:8:9]") '(invalid-ip-literal . 0))
        (check-equal "h16 too long"  (scan "[12345::1]")       '(invalid-ip-literal . 0))
        (check-equal "empty literal" (scan "[]")               '(invalid-ip-literal . 0))
        (check-equal "dec-octet 999" (scan "[::ffff:999.1.1.1]") '(invalid-dec-octet . 0))
        (check-equal "dec-octet 256" (scan "[::1.2.3.256]")    '(invalid-dec-octet . 0))))))

;; The corpus, cross-checked against the oracle: one check per row, plus the
;; per-production floors that keep the set from silently shrinking.
(harness-group "the negative corpus"
  (lambda ()
    (define rows (negative-load (host-path "negative.scm")))
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
        (check-equal "userinfo floor >= 2"   (>= (count 'invalid-userinfo) 2) #t)
        (check-equal "reg-name floor >= 3"   (>= (count 'invalid-reg-name) 3) #t)
        (check-equal "port floor >= 2"       (>= (count 'invalid-port) 2) #t)
        (check-equal "ip-literal floor >= 3" (>= (count 'invalid-ip-literal) 3) #t)
        (check-equal "dec-octet floor >= 1"  (>= (count 'invalid-dec-octet) 1) #t)
        (check-equal "pct floor >= 2"        (>= (count 'invalid-pct-encoded) 2) #t)))))

(harness-finish)
