#!r6rs
;;; conformance.abnf-differential -- the RFC 3986 conformance audit's
;;; DIFFERENTIAL. For a broad input space and each of
;;; the three modes, compare the product's verdict -- (uri-parse-ok? (uri-parse-
;;; validate mode bytes)) -- against the independent oracle's -- (oracle-recognize?
;;; mode bytes). Any input x mode where they DISAGREE is a candidate deviation, and
;;; the lane reddens naming it; agreement everywhere over the audited space is the
;;; recognizer-equivalence the "RFC 3986 compliant (validation)" claim needs.
;;;
;;; THE FOUR INPUT SOURCES.
;;;   (a) the POSITIVE corpora (§1.1.2 examples, the §5.4 base + targets + refs):
;;;       both must ACCEPT.
;;;   (b) the NEGATIVE corpora (charset, host): both must REJECT.
;;;   (c) the EXHAUSTIVE small sweep: every string of length 0..MAXLEN over a
;;;       reduced alphabet carrying the structural delimiters, in all three modes.
;;;       This densely covers the SHORT-string boundary space -- where a scheme,
;;;       an authority, a path-type, or a mode fork first turns over -- completely.
;;;   (d) the ADVERSARIAL corpus (differential-adversarial.scm): the DEEP,
;;;       STRUCTURED inputs the length bound cannot reach (full IPv6, IPv4 octet
;;;       boundaries, long pct runs, multi-segment colon paths, empty-component
;;;       combinations), each carrying its ABNF-correct verdict so the row is a
;;;       THIRD independent reading -- guarding the shared blind spot the oracle and
;;;       product could share.
;;;
;;; The sweep's bound is DISCLOSED and ASSERTED, never silently capped. Two
;;; mechanisms, because a passing `check` prints nothing: (1) the actual
;;; comparison count is checked EQUAL to an independently-computed expected
;;; total, so a silently-shrunk sweep reddens rather than passing
;;; byte-identically; and (2) an unconditional `uri-harness: coverage ...` line
;;; naming the alphabet, MAXLEN, and the compared count is emitted on every run,
;;; pass or fail.
(import (rnrs)
        (uri test harness)
        (uri test corpus)
        (uri test abnf-oracle)
        (uri collect)
        ;; the two component-oracle negative corpora. `prefix` because the two
        ;; libraries share these names, and this lane needs BOTH loaders.
        (prefix (only (uri test charset-oracle)
                      negative-load nv-mode nv-input nv-note) cs:)
        (prefix (only (uri test host-oracle)
                      negative-load nv-mode nv-input nv-note) hs:))

(define (corpus-path name)
  (string-append (adapter-environment-variable "URI_CORPUS_DIR") "/" name))
(define (charset-path name)
  (string-append (adapter-environment-variable "URI_CHARSET_DIR") "/" name))
(define (host-path name)
  (string-append (adapter-environment-variable "URI_HOST_DIR") "/" name))
(define (differential-path name)
  (string-append (adapter-environment-variable "URI_DIFFERENTIAL_DIR") "/" name))

(define MODES '(uri relative-ref uri-reference))

;; --- the two verdicts and their comparison -------------------------------
(define (product-accepts? mode bv) (uri-parse-ok? (uri-parse-validate mode bv)))
(define (oracle-accepts? mode bv) (oracle-recognize? mode bv))
(define (agree? mode bv) (eq? (oracle-accepts? mode bv) (product-accepts? mode bv)))

;; a readable rendering of a byte string: printable ASCII verbatim, else \xHH.
(define (bytes->display bv)
  (let-values (((p get) (open-string-output-port)))
    (let loop ((i 0))
      (if (fx=? i (bytevector-length bv))
          (get)
          (let ((b (bytevector-u8-ref bv i)))
            (if (and (fx>=? b 32) (fx<? b 127))
                (put-char p (integer->char b))
                (begin (put-string p "\\x")
                       (put-string p (number->string b 16))))
            (loop (fx+ i 1)))))))

(define (disagreement-note mode bv)
  (string-append "mode=" (symbol->string mode)
                 " input=[" (bytes->display bv) "]"
                 " oracle=" (if (oracle-accepts? mode bv) "ACCEPT" "reject")
                 " product=" (if (product-accepts? mode bv) "ACCEPT" "reject")))

(harness-begin "conformance.abnf-differential")

;; --- (a) positives: both accept ------------------------------------------
(harness-group "positives: product and oracle both accept"
  (lambda ()
    (define examples (corpus-load-examples (corpus-path "example-uris.scm")))
    (define res (corpus-load-resolution (corpus-path "resolution.scm")))
    (define base (resolution-base res))
    (define rows (resolution-vectors res))
    (define (both-accept label mode s)
      (let ((bv (string->utf8 s)))
        (check (string-append "oracle accepts " label) (oracle-accepts? mode bv))
        (check (string-append "product accepts " label) (product-accepts? mode bv))))
    ;; A loader that returned a well-formed-but-empty corpus would make the cases
    ;; below pass with zero checks; assert the sources are populated first.
    (harness-case "the positive corpora loaded non-empty"
      (lambda ()
        (check "§1.1.2 examples non-empty" (> (length examples) 0))
        (check "§5.4 vectors non-empty" (> (length rows) 0))))
    (harness-case "§1.1.2 examples (uri and uri-reference)"
      (lambda ()
        (for-each (lambda (u)
                    (both-accept (string-append "uri " u) 'uri u)
                    (both-accept (string-append "uri-ref " u) 'uri-reference u))
                  examples)))
    (harness-case "§5.4 base and targets (uri)"
      (lambda ()
        (both-accept (string-append "base " base) 'uri base)
        (for-each (lambda (r) (both-accept (string-append "target " (rv-target r))
                                           'uri (rv-target r)))
                  rows)))
    (harness-case "§5.4 references (uri-reference)"
      (lambda ()
        (for-each (lambda (r) (both-accept (string-append "ref [" (rv-reference r) "]")
                                           'uri-reference (rv-reference r)))
                  rows)))))

;; --- (b) negatives: both reject ------------------------------------------
;; The charset and host corpora are whole inputs (a mode + the bytes) the ABNF
;; rejects. Both the product and the whole-URI oracle must reject each.
(harness-group "negatives: product and oracle both reject"
  (lambda ()
    (define (both-reject label mode bv)
      (check (string-append "oracle rejects " label) (not (oracle-accepts? mode bv)))
      (check (string-append "product rejects " label) (not (product-accepts? mode bv))))
    (harness-case "charset negative corpus"
      (lambda ()
        (let ((rows (cs:negative-load (charset-path "negative.scm"))))
          (check "charset negative corpus non-empty" (> (length rows) 0))
          (for-each (lambda (v) (both-reject (cs:nv-note v) (cs:nv-mode v) (cs:nv-input v)))
                    rows))))
    (harness-case "host negative corpus"
      (lambda ()
        (let ((rows (hs:negative-load (host-path "negative.scm"))))
          (check "host negative corpus non-empty" (> (length rows) 0))
          (for-each (lambda (v) (both-reject (hs:nv-note v) (hs:nv-mode v) (hs:nv-input v)))
                    rows))))))

;; --- (c) the exhaustive small sweep --------------------------------------
;;
;; Reduced alphabet: a letter, a digit, a sub-delim, and the
;; structural delimiters ": / ? # [ ] @ % .". Twelve bytes; a and 1 double as
;; HEXDIG so pct-encoding is exercised at its boundary. Every string of length
;; 0..MAXLEN over this alphabet is fed to both, in all three modes.
(define ALPHABET (map char->integer (string->list "a1;.:/?#[]@%")))
(define MAXLEN 5)

;; The number of input x mode pairs a full sweep MUST compare: 3 modes times the
;; count of words of every length 0..MAXLEN over the alphabet (sum of |A|^k). Derived
;; here, independently of the loop, so the loop's own tally can be asserted against
;; it -- a silently-capped sweep then reddens instead of passing byte-identically.
(define EXPECTED-COMPARISONS
  (* (length MODES)
     (let loop ((k 0) (sum 0))
       (if (fx>? k MAXLEN) sum
           (loop (fx+ k 1) (+ sum (expt (length ALPHABET) k)))))))

;; enumerate every length-`len` word over ALPHABET, calling `on-word` on a shared
;; buffer (read synchronously, so no per-word copy; a disagreement copies before
;; recording).
(define (sweep-length len on-word)
  (let ((buf (make-bytevector len 0)))
    (let rec ((i 0))
      (if (fx=? i len)
          (on-word buf)
          (let aloop ((as ALPHABET))
            (unless (null? as)
              (bytevector-u8-set! buf i (car as))
              (rec (fx+ i 1))
              (aloop (cdr as))))))))

(define (copy-bytes bv)
  (let ((out (make-bytevector (bytevector-length bv))))
    (bytevector-copy! bv 0 out 0 (bytevector-length bv))
    out))

(harness-group "the exhaustive small sweep: product and oracle agree"
  (lambda ()
    (harness-case "every length-0..MAXLEN word over the reduced alphabet, all modes"
      (lambda ()
        (let ((compared 0) (disagreements '()))
          (do ((len 0 (fx+ len 1))) ((fx>? len MAXLEN))
            (sweep-length len
              (lambda (buf)
                (for-each
                 (lambda (mode)
                   (set! compared (fx+ compared 1))
                   (unless (agree? mode buf)
                     (set! disagreements
                           (cons (disagreement-note mode (copy-bytes buf)) disagreements))))
                 MODES))))
          ;; DISCLOSE the coverage unconditionally (a passing check prints nothing).
          (display (string-append
                    "uri-harness: coverage sweep=exhaustive alphabet="
                    (number->string (length ALPHABET))
                    " maxlen=" (number->string MAXLEN)
                    " modes=" (number->string (length MODES))
                    " compared=" (number->string compared)))
          (newline)
          (adapter-flush-output)
          ;; ASSERT the sweep compared the whole space -- a silent cap reddens here.
          (check-equal "the sweep compared the full length-0..MAXLEN space"
                       compared EXPECTED-COMPARISONS)
          (if (null? disagreements)
              (check "no product/oracle disagreement over the swept space" #t)
              (for-each (lambda (d) (check-fail "SWEEP DISAGREEMENT" d))
                        (reverse disagreements))))))))

;; --- (d) the adversarial corpus ------------------------------------------
;;
;; Deep structured inputs the length bound cannot reach, each with its ABNF-correct
;; verdict. A row is (mode input expect note): expect is `accept` or `reject`;
;; input is a STRING or a #vu8(...) bytevector. Checked THREE ways: oracle vs ABNF,
;; product vs ABNF (so a shared oracle/product blind spot still reddens against the
;; hand verdict), and -- implied by those two -- oracle vs product.
(define (adversarial-load path)
  (let ((p (open-file-input-port path (file-options) (buffer-mode block)
                                 (native-transcoder))))
    (let loop ((acc '()))
      (let ((d (get-datum p)))
        (if (eof-object? d)
            (begin (close-port p) (reverse acc))
            (loop (cons d acc)))))))

(define (adversarial-rows data)
  (let loop ((ds data))
    (cond ((null? ds) (error 'adversarial-rows "no (cases ...) form"))
          ((and (pair? (car ds)) (eq? (caar ds) 'cases)) (cdar ds))
          (else (loop (cdr ds))))))

(define (row-bytes x)
  (cond ((string? x) (string->utf8 x))
        ((bytevector? x) x)
        (else (error 'row-bytes "input is neither string nor bytevector"))))

(harness-group "the adversarial corpus: product, oracle, and the ABNF verdict agree"
  (lambda ()
    (define rows (adversarial-rows
                  (adversarial-load (differential-path "adversarial.scm"))))
    (harness-case "every adversarial row: oracle and product match the ABNF verdict"
      (lambda ()
        (for-each
         (lambda (row)
           (let* ((mode (car row)) (bv (row-bytes (cadr row)))
                  (expect-accept (eq? (caddr row) 'accept))
                  (note (cadddr row)))
             (check-equal (string-append "oracle: " note)
                          (oracle-accepts? mode bv) expect-accept)
             (check-equal (string-append "product: " note)
                          (product-accepts? mode bv) expect-accept)))
         rows)))
    (harness-case "the corpus covers both verdicts (no one-sided set)"
      (lambda ()
        (define (count v) (length (filter (lambda (r) (eq? (caddr r) v)) rows)))
        (check-equal "has accept rows" (> (count 'accept) 0) #t)
        (check-equal "has reject rows" (> (count 'reject) 0) #t)))))

(harness-finish)
