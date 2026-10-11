#!r6rs
;;; (uri test charset-oracle): the RFC 3986 component charsets, derived from the
;;; ABNF INDEPENDENTLY of any src validator, plus the reader for the negative
;;; corpus and the cross-check that ties the two together.
;;;
;;; ORACLE DISCIPLINE. This library is the reference against which
;;; `(uri charset)` is graded, so it is written from RFC 3986 Appendix A
;;; (test/conformance/rfc3986/rfc3986.abnf) and RFC 5234 Appendix B, NOT from the
;;; src validator. `oracle-scan`
;;; is a second, deliberately naive implementation of exactly the property the
;;; product must have, and two implementations of one property that agree on
;;; every byte are the check.
;;;
;;; SCOPE: scheme, path, query, fragment, and pct-encoded. PORT and every
;;; authority-interior charset (userinfo, host, reg-name, IP-literal) belong to
;;; the host oracle -- this one treats the authority as one opaque span -- so it
;;; names no authority production.
;;;
;;; PURE, except `negative-load`, the one procedure that touches a port.
(library (uri test charset-oracle)
  (export
    ;; the ABNF byte sets (RFC 5234 B.1 + RFC 3986 §2.2, §2.3, §3.3)
    oracle-alpha? oracle-digit? oracle-hexdig?
    oracle-unreserved? oracle-sub-delim? oracle-pchar-literal?
    ;; per-component literal-byte tests (pct-encoded handled by the scan)
    oracle-component-literal?
    ;; the reference validator: component + bytes -> (values code index) | (#f #f)
    oracle-scan
    ;; the negative corpus
    negative-load negative-parse
    nv? nv-mode nv-input nv-component nv-code nv-offset nv-note
    ;; the cross-check: corpus row vs oracle, #f when consistent
    negative-cross-check
    charset-oracle-error? charset-oracle-error-detail)
  (import (rnrs))

  (define-condition-type &charset-oracle &error
    make-charset-oracle-error charset-oracle-error?
    (detail charset-oracle-error-detail))

  (define (refuse who detail)
    (raise (condition (make-charset-oracle-error detail)
                      (make-who-condition who)
                      (make-message-condition detail))))

  ;; --- the byte sets, from the ABNF ---------------------------------------
  ;; Byte values, because the parser is byte-level. RFC 5234 B.1
  ;; leaves ALPHA/DIGIT/HEXDIG to be supplied; HEXDIG admits lower-case here
  ;; because RFC 3986 §6.2.2.1 treats "%3a" and "%3A" as the same octet and the
  ;; parser is non-normalising -- both are valid pct-encoded.
  (define (oracle-alpha? b) (or (and (fx<=? #x41 b) (fx<=? b #x5A))    ; A-Z
                                (and (fx<=? #x61 b) (fx<=? b #x7A))))  ; a-z
  (define (oracle-digit? b) (and (fx<=? #x30 b) (fx<=? b #x39)))       ; 0-9
  (define (oracle-hexdig? b) (or (oracle-digit? b)
                                 (and (fx<=? #x41 b) (fx<=? b #x46))    ; A-F
                                 (and (fx<=? #x61 b) (fx<=? b #x66))))  ; a-f

  ;; unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
  (define (oracle-unreserved? b)
    (or (oracle-alpha? b) (oracle-digit? b)
        (fx=? b #x2D) (fx=? b #x2E) (fx=? b #x5F) (fx=? b #x7E)))

  ;; sub-delims = "!" "$" "&" "'" "(" ")" "*" "+" "," ";" "="
  (define (oracle-sub-delim? b)
    (memv b '(#x21 #x24 #x26 #x27 #x28 #x29 #x2A #x2B #x2C #x3B #x3D)))

  ;; pchar minus pct-encoded: unreserved / sub-delims / ":" / "@"
  (define (oracle-pchar-literal? b)
    (or (oracle-unreserved? b) (oracle-sub-delim? b)
        (fx=? b #x3A) (fx=? b #x40)))

  ;; The literal (non-"%") bytes each component admits. First-byte rules
  ;; (scheme's leading ALPHA) are the scan's, not this per-byte test.
  ;;   scheme rest = ALPHA / DIGIT / "+" / "-" / "."
  ;;   path        = pchar / "/"
  ;;   query, frag = pchar / "/" / "?"
  (define (oracle-component-literal? component b)
    (case component
      ((scheme) (or (oracle-alpha? b) (oracle-digit? b)
                    (fx=? b #x2B) (fx=? b #x2D) (fx=? b #x2E)))
      ((path)   (or (oracle-pchar-literal? b) (fx=? b #x2F)))
      ((query fragment) (or (oracle-pchar-literal? b)
                            (fx=? b #x2F) (fx=? b #x3F)))
      (else (refuse 'oracle-component-literal?
                    (string-append "no charset component named "
                                   (symbol->string component))))))

  ;; --- the reference validator --------------------------------------------
  ;;
  ;; oracle-scan : Symbol Bytevector -> (values (Option Symbol) (Option Nat))
  ;;
  ;; #f #f when every byte is valid; else the error code and the COMPONENT-
  ;; RELATIVE index of the first offending position. A malformed pct-encoded is
  ;; reported at the "%" (the byte that opens the production that fails), which
  ;; is why its index is distinct from a stray literal's. scheme adds the leading
  ;; -ALPHA rule: an empty scheme, or a first byte that is not ALPHA, fails at 0.
  (define (oracle-scan component bv)
    (define n (bytevector-length bv))
    (define (byte i) (bytevector-u8-ref bv i))
    (case component
      ;; scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
      ((scheme)
       (cond ((fx=? n 0) (values 'invalid-scheme 0))            ; needs a leading ALPHA
             ((not (oracle-alpha? (byte 0))) (values 'invalid-scheme 0))
             (else
              (let loop ((i 1))
                (cond ((fx=? i n) (values #f #f))
                      ((oracle-component-literal? 'scheme (byte i)) (loop (fx+ i 1)))
                      (else (values 'invalid-scheme i)))))))
      ;; path / query / fragment: literal bytes, or "%" HEXDIG HEXDIG
      ((path query fragment)
       (let ((code (case component
                     ((path) 'invalid-pchar)
                     ((query) 'invalid-query)
                     ((fragment) 'invalid-fragment))))
         (let loop ((i 0))
           (cond ((fx=? i n) (values #f #f))
                 ((fx=? (byte i) #x25)                           ; "%"
                  (if (and (fx<? (fx+ i 2) n)
                           (oracle-hexdig? (byte (fx+ i 1)))
                           (oracle-hexdig? (byte (fx+ i 2))))
                      (loop (fx+ i 3))
                      (values 'invalid-pct-encoded i)))          ; report at the "%"
                 ((oracle-component-literal? component (byte i)) (loop (fx+ i 1)))
                 (else (values code i))))))
      (else (refuse 'oracle-scan
                    (string-append "no charset component named "
                                   (symbol->string component))))))

  ;; --- the negative corpus -------------------------
  ;;
  ;; A row is (mode input component code offset note). `input` is a STRING (its
  ;; UTF-8 bytes, convenient for the ASCII cases) or a BYTEVECTOR (exact bytes,
  ;; for the > 0x7F and control-byte cases a string cannot carry). `offset` is
  ;; ABSOLUTE in the input -- the contract `(uri charset)` reports.
  (define-record-type nv (fields mode input component code offset note))

  (define (row->bytes x who)
    (cond ((string? x) (string->utf8 x))
          ((bytevector? x) x)
          (else (refuse who "input is neither a string nor a bytevector"))))

  (define (negative-parse data)
    (map (lambda (row)
           (unless (and (list? row) (= (length row) 6))
             (refuse 'negative-parse
                     "a row is not (mode input component code offset note)"))
           (let ((mode (car row)) (input (cadr row)) (component (caddr row))
                 (code (cadddr row)) (offset (car (cddddr row)))
                 (note (cadr (cddddr row))))
             (unless (symbol? mode) (refuse 'negative-parse "mode is not a symbol"))
             (unless (symbol? component) (refuse 'negative-parse "component is not a symbol"))
             (unless (symbol? code) (refuse 'negative-parse "code is not a symbol"))
             (unless (and (integer? offset) (exact? offset) (>= offset 0))
               (refuse 'negative-parse "offset is not an exact non-negative integer"))
             (unless (string? note) (refuse 'negative-parse "note is not a string"))
             (make-nv mode (row->bytes input 'negative-parse) component code offset note)))
         (let loop ((ds data))
           (cond ((null? ds) (refuse 'negative-parse "no (negatives ...) form"))
                 ((and (pair? (car ds)) (eq? (caar ds) 'negatives)) (cdar ds))
                 (else (loop (cdr ds)))))))

  (define (negative-load path)
    (let ((p (open-file-input-port path (file-options) (buffer-mode block)
                                   (native-transcoder))))
      (let loop ((acc '()))
        (let ((d (get-datum p)))
          (if (eof-object? d)
              (begin (close-port p) (negative-parse (reverse acc)))
              (loop (cons d acc)))))))

  ;; --- the cross-check --------------------------------------------
  ;;
  ;; negative-cross-check : Nv -> (Option String)
  ;;
  ;; #f when the row is consistent with the oracle; else a diagnostic. The check
  ;; cannot ask the shell for the component start, so it verifies, from the raw
  ;; input and the oracle alone:
  ;;   (1) the byte AT the recorded absolute offset is genuinely offending for
  ;;       the named code -- an invalid literal, or a "%" that opens a malformed
  ;;       pct-encoded; and
  ;;   (2) the recorded code is the one the reference validator raises for the
  ;;       named component. Whether that offset is the FIRST such position is
  ;;       judged against the validator's own reported offset, not here.
  (define (negative-cross-check v)
    (define bv (nv-input v))
    (define n (bytevector-length bv))
    (define off (nv-offset v))
    (define code (nv-code v))
    (define component (nv-component v))
    (define (say . parts) (apply string-append parts))
    (cond
     ((>= off n)
      (say "offset " (number->string off) " is past the end of a "
           (number->string n) "-byte input"))
     ;; The code must name a component that admits its production, checked FIRST
     ;; -- so neither branch below is reached with an out-of-scope component (a
     ;; pct-encoded row named on a scheme, a literal code on an unknown symbol).
     ((not (code-matches-component? code component))
      (say "code " (symbol->string code) " does not name component "
           (symbol->string component)))
     ((eq? code 'invalid-pct-encoded)
      (let ((b (bytevector-u8-ref bv off)))
        (cond ((not (fx=? b #x25))
               (say "invalid-pct-encoded at " (number->string off)
                    " but that byte is not \"%\""))
              ((and (fx<? (fx+ off 2) n)
                    (oracle-hexdig? (bytevector-u8-ref bv (fx+ off 1)))
                    (oracle-hexdig? (bytevector-u8-ref bv (fx+ off 2))))
               (say "invalid-pct-encoded at " (number->string off)
                    " but \"%\" is followed by two HEXDIG"))
              (else #f))))
     (else                             ; a literal-byte code; the guard above passed
      (let ((b (bytevector-u8-ref bv off)))
        ;; scheme's byte 0 is judged by the leading-ALPHA rule.
        (if (if (and (eq? component 'scheme) (= off 0))
                (oracle-alpha? b)
                (oracle-component-literal? component b))
            (say (symbol->string code) " at " (number->string off)
                 " but that byte is valid for " (symbol->string component))
            #f)))))

  ;; code-matches-component? : does the error code name a component that admits
  ;; the production it refers to? pct-encoded is admitted by path/query/fragment.
  (define (code-matches-component? code component)
    (case code
      ((invalid-scheme) (eq? component 'scheme))
      ((invalid-pchar) (eq? component 'path))
      ((invalid-query) (eq? component 'query))
      ((invalid-fragment) (eq? component 'fragment))
      ((invalid-pct-encoded) (and (memq component '(path query fragment)) #t))
      (else #f))))
