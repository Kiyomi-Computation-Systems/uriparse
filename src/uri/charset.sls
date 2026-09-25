#!r6rs
;;; (uri charset): RFC 3986 charset validation of the split components (M3,
;;; decision 0024). v0.1 SPLIT a URI without judging its bytes; this library is
;;; the judge, for the components the core holds whole: scheme, path, query,
;;; fragment, and the pct-encoded triples within them. PORT and every
;;; authority-interior charset (userinfo, host, reg-name, IP-literal) are M4's --
;;; the authority is one opaque span until then (decision 0024 item 2).
;;;
;;; PURE, and non-normative about STRUCTURE: it judges only the bytes of a
;;; component, never where the delimiters fell (that is the scanner's, and its
;;; structural errors are distinct codes at the same byte -- decision 0009 item
;;; 4). It reuses (uri percent)'s §2.3 unreserved test and hex primitive rather
;;; than re-deriving them, so the validator and the codec cannot disagree about
;;; what a byte is. It is written INDEPENDENTLY of the test-side oracle
;;; (uri test charset-oracle); the two agree on every byte, and that agreement is
;;; the check (decisions 0005, 0012).
(library (uri charset)
  (export uri-charset-error-codes uri-charset-error-code?
          validate-component)
  (import (rnrs) (uri percent))

  ;; The CORE error vocabulary (decision 0024 item 5): each names the ABNF
  ;; production that failed, in the RFC's own spelling (0009 item 1), and lives
  ;; here with the core, NOT in the scanner's (uri vocabulary) table.
  (define uri-charset-error-codes
    '(invalid-scheme invalid-pchar invalid-query invalid-fragment
      invalid-pct-encoded))

  (define (uri-charset-error-code? x) (and (memq x uri-charset-error-codes) #t))

  ;; --- byte constants (ASCII; a URI's structural octets are ASCII) ---------
  (define PERCENT 37)                                   ; %
  (define UP-A 65) (define UP-Z 90) (define LO-A 97) (define LO-Z 122)
  (define ZERO 48) (define NINE 57)
  (define PLUS 43) (define HYPHEN 45) (define DOT 46)   ; scheme's extra three
  (define SLASH 47) (define QUESTION 63)                ; path/query extras
  (define COLON 58) (define AT 64)                      ; pchar's extra two

  (define (alpha? b) (or (and (fx>=? b UP-A) (fx<=? b UP-Z))
                         (and (fx>=? b LO-A) (fx<=? b LO-Z))))
  (define (digit? b) (and (fx>=? b ZERO) (fx<=? b NINE)))

  ;; sub-delims = "!" "$" "&" "'" "(" ")" "*" "+" "," ";" "="
  (define (sub-delim? b)
    (or (fx=? b 33) (fx=? b 36) (fx=? b 38) (fx=? b 39) (fx=? b 40) (fx=? b 41)
        (fx=? b 42) (fx=? b 43) (fx=? b 44) (fx=? b 59) (fx=? b 61)))

  ;; pchar minus pct-encoded = unreserved / sub-delims / ":" / "@"
  (define (pchar-literal? b)
    (or (unreserved-byte? b) (sub-delim? b) (fx=? b COLON) (fx=? b AT)))

  ;; The literal (non-"%") bytes each component admits.
  (define (scheme-rest? b)                              ; ALPHA / DIGIT / + - .
    (or (alpha? b) (digit? b) (fx=? b PLUS) (fx=? b HYPHEN) (fx=? b DOT)))
  (define (path-literal? b) (or (pchar-literal? b) (fx=? b SLASH)))
  (define (query/fragment-literal? b)
    (or (pchar-literal? b) (fx=? b SLASH) (fx=? b QUESTION)))

  ;; --- the validator -------------------------------------------------------
  ;;
  ;; validate-component : Symbol Bytevector [Nat [Nat]] -> (values (Option Symbol) (Option Nat))
  ;;
  ;; #f #f when every byte of the component is valid; else the core error code
  ;; and the COMPONENT-RELATIVE index of the first offending position. A
  ;; malformed pct-encoded is reported at the "%" that opens it. The shell
  ;; ((uri collect)) rebases the index to an absolute input offset (0024 item 3).
  ;;
  ;; The component is bv[start, end), by default the whole bytevector, so an
  ;; embedder can judge a span of a larger buffer in place without copying it
  ;; (decision 0034). Nothing outside [start, end) is read: a "%" whose HEXDIGs
  ;; lie past end is malformed. The index is relative to start. A range that is
  ;; not within the bytevector is an assertion violation. An unknown component
  ;; is named first, before the range or the bytevector is looked at.
  (define validate-component
    (case-lambda
      ((component bv)
       (let ((judge (judge-of component)))
         (judge bv 0 (bytevector-length bv))))       ; the whole: a range by construction
      ((component bv start)
       (let ((judge (judge-of component)))
         (judge-range judge bv start (bytevector-length bv))))
      ((component bv start end)
       (let ((judge (judge-of component)))
         (judge-range judge bv start end)))))

  (define (judge-of component)
    (case component
      ((scheme)   validate-scheme)
      ((path)     validate-path)
      ((query)    validate-query)
      ((fragment) validate-fragment)
      (else (assertion-violation 'validate-component
                                 "not an M3-validated component" component))))

  (define (judge-range judge bv start end)
    (unless (and (fixnum? start) (fixnum? end)
                 (fx<=? 0 start) (fx<=? start end) (fx<=? end (bytevector-length bv)))
      (assertion-violation 'validate-component
                           "not a range within the bytevector" start end))
    (judge bv start end))

  (define (validate-path bv s e) (validate-content 'invalid-pchar path-literal? bv s e))
  (define (validate-query bv s e)
    (validate-content 'invalid-query query/fragment-literal? bv s e))
  (define (validate-fragment bv s e)
    (validate-content 'invalid-fragment query/fragment-literal? bv s e))

  ;; scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." ): non-empty, ALPHA first.
  (define (validate-scheme bv s e)
    (cond ((fx=? s e) (values 'invalid-scheme 0))
          ((not (alpha? (bytevector-u8-ref bv s))) (values 'invalid-scheme 0))
          (else
           (let loop ((i (fx+ s 1)))
             (cond ((fx=? i e) (values #f #f))
                   ((scheme-rest? (bytevector-u8-ref bv i)) (loop (fx+ i 1)))
                   (else (values 'invalid-scheme (fx- i s))))))))

  ;; path / query / fragment: a literal byte, or "%" HEXDIG HEXDIG.
  (define (validate-content code literal? bv s e)
    (let loop ((i s))
      (cond ((fx=? i e) (values #f #f))
            ((fx=? (bytevector-u8-ref bv i) PERCENT)
             (if (valid-pct-triple? bv i e)
                 (loop (fx+ i 3))
                 (values 'invalid-pct-encoded (fx- i s))))
            ((literal? (bytevector-u8-ref bv i)) (loop (fx+ i 1)))
            (else (values code (fx- i s))))))

  ;; "%" at i, then two bytes before n that are both HEXDIG. hex-digit-value
  ;; returns a number (possibly 0, which is truthy) or #f, so it is the test.
  (define (valid-pct-triple? bv i n)
    (and (fx<? (fx+ i 2) n)
         (hex-digit-value (bytevector-u8-ref bv (fx+ i 1)))
         (hex-digit-value (bytevector-u8-ref bv (fx+ i 2)))
         #t)))
