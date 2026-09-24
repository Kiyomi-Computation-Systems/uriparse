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

;; --- validate-component over a range (issue #21, decision 0034) ------------
;; An embedder holding a component as [start, end) of a larger bytevector (a
;; server's request-target, still in the buffer the socket filled) judges it in
;; place. The ranged verdict is the verdict on the span ALONE: nothing outside
;; [start, end) is read, and the index is relative to start.
(harness-group "validate-component over a range"
  (lambda ()
    (define (bytes s) (string->utf8 s))
    (define (verdict component bv . range)
      (call-with-values (lambda () (apply validate-component component bv range)) list))
    (harness-case "the oracle's verdict on the span alone, whatever surrounds it"
      (lambda ()
        ;; Each surrounding is hostile to one way of reading outside the span:
        ;; " " is invalid in every component (a scan from 0, or on to the
        ;; buffer's end, trips on it); "41" completes a "%" or "%4" cut off at
        ;; end (a pct guard bounded by the buffer's length accepts it); a valid
        ;; prefix moves every absolute index off the relative one.
        (let ((components '(scheme path query fragment))
              (shapes '("" "a" "abc" "%" "%4" "x%" "%AB" "%AG" "a%20b" "/a/b"
                        ":@" "?" "a b" "1a" "a.b-c+d"))
              (surroundings '(("" . "") (" " . "") ("" . " ") (" " . " ")
                              ("" . "41") ("%" . "41") ("ab" . "4 ")))
              (tried 0)
              (bad '()))
          (for-each
           (lambda (component)
             (for-each
              (lambda (s)
                (for-each
                 (lambda (around)
                   (let* ((start (bytevector-length (bytes (car around))))
                          (span (bytes s))
                          (end (+ start (bytevector-length span)))
                          (buf (bytes (string-append (car around) s (cdr around)))))
                     (set! tried (+ tried 1))
                     (unless (equal? (verdict component buf start end)
                                     (call-with-values
                                      (lambda () (oracle-scan component span)) list))
                       (set! bad (cons (list component (car around) s (cdr around))
                                       bad)))))
                 surroundings))
              shapes))
           components)
          (check-equal "every (component, shape, surrounding) was judged" tried
                       (* (length components) (length shapes) (length surroundings)))
          (check-equal "no disagreements" bad '()))))
    (harness-case "pinned: a request line, judged in place"
      (lambda ()
        ;; "GET /over/there?name=ferret HTTP/1.1": path [4,15), query [16,27).
        (let ((line (bytes "GET /over/there?name=ferret HTTP/1.1")))
          (check-equal "path span" (verdict 'path line 4 15) '(#f #f))
          (check-equal "query span" (verdict 'query line 16 27) '(#f #f))
          (check-equal "the whole line is no path" (verdict 'path line) '(invalid-pchar 3)))
        ;; RFC 9112 origin-form is absolute-path, so "//a@b:c/d" is one; a
        ;; uri-reference parse reads that "//" as an authority instead.
        (check-equal "origin-form path span"
                     (verdict 'path (bytes "GET //a@b:c/d HTTP/1.1") 4 13) '(#f #f))
        (let ((r (uri-parse-validate 'uri-reference (bytes "//a@b:c/d"))))
          (check-equal "the collector's reading of the same bytes"
                       (list (uri-parse-error-code r) (uri-parse-error-offset r))
                       '(invalid-port 6)))))
    (harness-case "pinned: the edges of the range"
      (lambda ()
        (let ((bv (bytes "/a%41")))
          (check-equal "a triple cut by end is malformed, at its %"
                       (verdict 'path bv 0 4) '(invalid-pct-encoded 2))
          (check-equal "a lone % at end" (verdict 'path bv 0 3) '(invalid-pct-encoded 2))
          (check-equal "the whole triple" (verdict 'path bv 0 5) '(#f #f)))
        (check-equal "a span ending at the buffer's end"
                     (verdict 'fragment (bytes "#x%4") 1 4) '(invalid-pct-encoded 1))
        (check-equal "the index is relative to start"
                     (verdict 'path (bytes "xx/a b") 2 6) '(invalid-pchar 2))
        (check-equal "an empty span is an empty path" (verdict 'path (bytes "a b") 1 1) '(#f #f))
        (check-equal "an empty span is no scheme" (verdict 'scheme (bytes "http") 2 2)
                     '(invalid-scheme 0))
        (check-equal "scheme: the span's first byte is the ALPHA"
                     (verdict 'scheme (bytes "1http:") 1 5) '(#f #f))
        (check-equal "scheme: a non-ALPHA first byte of the span"
                     (verdict 'scheme (bytes "a1b") 1 3) '(invalid-scheme 0))
        (check-equal "scheme: a later bad byte, relative"
                     (verdict 'scheme (bytes "xa_b") 1 4) '(invalid-scheme 1))
        (check-equal "start alone runs to the end" (verdict 'path (bytes " /a b") 1)
                     '(invalid-pchar 2))
        (check-equal "start alone, valid" (verdict 'query (bytes " a=1") 1) '(#f #f))))
    (harness-case "a range outside the bytevector is refused"
      (lambda ()
        ;; "a b": a scan that trusted a bad range would stop at the space and
        ;; answer, rather than raise. The thunk returns ONE value (the verdict
        ;; list): two values into check-raises would raise on their own and
        ;; pass whatever the range.
        (let ((bv (bytes "a b")))
          (for-each
           (lambda (range)
             (check-raises (string-append "range " (adapter-value->string range))
                           assertion-violation?
                           (lambda () (apply verdict 'path bv range))))
           '((1 0) (0 9) (4) (-1 2) (0 1.5) (x 2)))
          (check-equal "[length, length) is the empty span, not an error"
                       (verdict 'path bv 3 3) '(#f #f)))))
    (harness-case "judging a span allocates nothing that grows with its length"
      (lambda ()
        ;; The point of the range (issue #21): keeping a component as a span
        ;; must not cost a per-byte copy to judge it.
        (let* ((buf (make-bytevector 4096 97))            ; "aaaa..."
               (reps 1000)
               (allocated
                (lambda (len)
                  (validate-component 'path buf 0 len)    ; warm
                  (let ((before (adapter-bytes-allocated)))
                    (do ((i 0 (+ i 1))) ((= i reps))
                      (validate-component 'path buf 0 len))
                    (- (adapter-bytes-allocated) before)))))
          (check-equal "a 2-byte span and a 4000-byte span allocate alike"
                       (allocated 2) (allocated 4000)))))))

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
