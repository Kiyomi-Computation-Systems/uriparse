#!r6rs
;;; unit.authority-form -- the RFC 9112 §3.2.3 authority-form pair. Two entry
;;; points on (uri collect): uri-parse-authority-form (LENIENT, a sibling of
;;; uri-parse) and uri-parse-authority-form-validate (STRICT). Graded against
;;; the hand-derived corpus -- each row's LENIENT and STRICT verdict, exact code
;;; + ABSOLUTE offset in the caller's coordinates -- plus direct assertions on
;;; the -2 splice re-map, the error vocabulary, and the lenient/strict
;;; divergence (the whole reason for the pair). The host grammar itself is
;;; guarded by unit.host (graded three ways); this lane guards the
;;; authority-form policy.
(import (rnrs)
        (uri test harness)
        (uri collect)
        (uri components))

(define (af-path name)
  (string-append (adapter-environment-variable "URI_AUTHORITY_FORM_DIR") "/" name))

;; Read the single (authority-form ROW ...) form; ROW = (input lenient strict note).
;; A missing tag is a corpus defect, not an empty corpus -- it raises.
(define (load-corpus path)
  (let ((p (open-file-input-port path (file-options) (buffer-mode block)
                                 (native-transcoder))))
    (let ((datum (get-datum p)))
      (close-port p)
      (if (and (pair? datum) (eq? (car datum) 'authority-form))
          (cdr datum)
          (assertion-violation 'load-corpus "not an (authority-form ...) form" datum)))))

(define (row-input r)   (string->utf8 (car r)))
(define (row-lenient r) (cadr r))
(define (row-strict r)  (caddr r))
(define (row-note r)    (cadddr r))

;; Expect is `ok`, or (code offset). check the result against it.
(define (check-result label expect r)
  (if (eq? expect 'ok)
      (check (string-append "ok: " label) (uri-parse-ok? r))
      (begin
        (check (string-append "rejected: " label) (not (uri-parse-ok? r)))
        (check-equal (string-append "code: " label) (uri-parse-error-code r) (car expect))
        (check-equal (string-append "offset: " label) (uri-parse-error-offset r) (cadr expect)))))

(harness-begin "unit.authority-form")

;; --- the RFC 9112 authority-form error vocabulary --------------------
(harness-group "the authority-form error vocabulary"
  (lambda ()
    (harness-case "three codes, named per §3.2.3, predicate exact"
      (lambda ()
        (for-each (lambda (c) (check (symbol->string c) (uri-authority-form-error-code? c)))
                  '(not-authority-form userinfo-forbidden port-required))
        (check-equal "count" (length uri-authority-form-error-codes) 3)
        (check "a scanner code is not an authority-form code"
               (not (uri-authority-form-error-code? 'scheme-required)))
        (check "a host code is not an authority-form code"
               (not (uri-authority-form-error-code? 'invalid-reg-name)))))))

;; --- the corpus: both entry points, exact code + absolute offset ----------
(harness-group "the corpus grades both entry points, exactly"
  (lambda ()
    (define rows (load-corpus (af-path "corpus.scm")))
    (harness-case "every row: lenient AND strict verdict, code + ABSOLUTE offset"
      (lambda ()
        (for-each
         (lambda (r)
           (let ((bv (row-input r)) (note (row-note r)))
             (check-result (string-append "lenient -- " note) (row-lenient r)
                           (uri-parse-authority-form bv))
             (check-result (string-append "strict -- " note) (row-strict r)
                           (uri-parse-authority-form-validate bv))))
         rows)))
    (harness-case "coverage floor: the classes stay present"
      (lambda ()
        (check "at least 17 rows" (>= (length rows) 17))))))

;; --- the "//" splice re-maps offsets by exactly -2 -------------------------
(harness-group "the // splice re-maps offsets by exactly -2"
  (lambda ()
    (harness-case "a valid target: authority at 0, components are the target itself"
      (lambda ()
        (let* ((r (uri-parse-authority-form (string->utf8 "example.com:443")))
               (c (uri-parse-components r)))
          (check "ok" (uri-parse-ok? r))
          (check-equal "authority offset is 0" (uri-parse-component-offset r 'authority) 0)
          (check-equal "authority bytes" (utf8->string (uri-components-authority c))
                       "example.com:443")
          (check-equal "path present and empty" (bytevector-length (uri-components-path c)) 0)
          (check "query absent" (not (uri-components-query c)))
          (check "fragment absent" (not (uri-components-fragment c))))))
    (harness-case "an IPv6 target keeps the brackets and the port, authority at 0"
      (lambda ()
        (let* ((r (uri-parse-authority-form (string->utf8 "[2001:db8::1]:8080")))
               (c (uri-parse-components r)))
          (check-equal "authority bytes" (utf8->string (uri-components-authority c))
                       "[2001:db8::1]:8080")
          (check-equal "authority offset is 0"
                       (uri-parse-component-offset r 'authority) 0))))))

;; --- the lenient/strict divergence (the whole reason for the pair) --------
(harness-group "lenient accepts what strict rejects"
  (lambda ()
    (harness-case "userinfo: lenient ok, strict userinfo-forbidden"
      (lambda ()
        (check "lenient ok"
               (uri-parse-ok? (uri-parse-authority-form (string->utf8 "user@host:443"))))
        (let ((r (uri-parse-authority-form-validate (string->utf8 "user@host:443"))))
          (check "strict rejects" (not (uri-parse-ok? r)))
          (check-equal "code" (uri-parse-error-code r) 'userinfo-forbidden))))
    (harness-case "empty port host: lenient ok, strict port-required (RFC 3986 vs 9112)"
      (lambda ()
        (check "lenient ok"
               (uri-parse-ok? (uri-parse-authority-form (string->utf8 "host:"))))
        (let ((r (uri-parse-authority-form-validate (string->utf8 "host:"))))
          (check "strict rejects" (not (uri-parse-ok? r)))
          (check-equal "code" (uri-parse-error-code r) 'port-required))))))

(harness-finish)
