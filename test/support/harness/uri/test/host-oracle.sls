#!r6rs
;;; (uri test host-oracle): RFC 3986's AUTHORITY grammar -- the userinfo/host/port
;;; split and the whole host grammar (reg-name, IPv4address, IP-literal →
;;; IPv6address / IPvFuture, dec-octet, port) -- read from the ABNF INDEPENDENTLY
;;; of the src `(uri host)` validator that does not exist yet, plus the reader for
;;; M4's hand-derived negative corpus and the cross-check that ties the two
;;; together (M4, decision 0025, Slice ⓪).
;;;
;;; ORACLE DISCIPLINE (decisions 0005, 0012). This library is the reference against
;;; which `(uri host)` (M4 Slices ①②) is graded, so it is written from RFC 3986
;;; §3.2 / Appendix A (test/conformance/rfc3986/rfc3986.abnf) and RFC 5234 App. B,
;;; NOT from the src validator. `oracle-scan-authority` is a second, deliberately
;;; naive implementation of exactly the property the product must have, and two
;;; implementations of one property that agree on every input are the check.
;;;
;;; THE COUNTING MODEL (decision 0025 item 5). The ABNF writes `IPv6address` as nine
;;; alternatives because ABNF cannot count; this reads it as a counter -- ≤8 `h16`
;;; groups, at most ONE `::` (which fills ≥1 zero group), an optional trailing
;;; `IPv4address` (`ls32`) counting as two groups -- exactly the reduction the design
;;; note predicts. Without `::` the pieces total exactly 8; with `::` they total ≤7.
;;;
;;; OFFSET CONVENTION (decision 0025 items 3-4). `oracle-scan-authority` returns the
;;; AUTHORITY-relative index of the first fault. A userinfo/reg-name/port literal
;;; fault points at the offending byte; a malformed `pct-encoded` at its `%`; and
;;; every IP-literal-interior fault -- including a `dec-octet` range error -- points
;;; at the opening `[` (the byte that opens the failing production), so the code,
;;; not the index, distinguishes the reason. `dec-octet` is REACHABLE ONLY inside a
;;; bracketed literal: a bare `999.1.1.1` is a valid `reg-name` (§3.2.2
;;; first-match-wins), not an error.
;;;
;;; SCOPE. userinfo / host (`reg-name`, `IPv4address`, `IP-literal`, `IPv6address`,
;;; `IPvFuture`) / `port` and `dec-octet`, plus reused `pct-encoded`. This is the
;;; whole authority interior; scheme/path/query/fragment are M3's (uri charset).
;;;
;;; PURE, except `negative-load`, the one procedure that touches a port.
(library (uri test host-oracle)
  (export
    ;; the ABNF byte sets (RFC 5234 B.1 + RFC 3986 §2.2, §2.3, §3.2.2)
    oracle-alpha? oracle-digit? oracle-hexdig?
    oracle-unreserved? oracle-sub-delim?
    oracle-userinfo-literal? oracle-reg-name-literal?
    ;; the reference validator: authority bytes -> (values code index) | (#f #f)
    oracle-scan-authority
    ;; the test-side authority extractor the cross-check rebases against
    authority-of
    ;; M4's negative corpus
    negative-load negative-parse
    nv? nv-mode nv-input nv-component nv-code nv-offset nv-note
    ;; the Slice ⓪ cross-check: corpus row vs oracle, #f when consistent
    negative-cross-check
    host-oracle-error? host-oracle-error-detail)
  (import (rnrs))

  (define-condition-type &host-oracle &error
    make-host-oracle-error host-oracle-error?
    (detail host-oracle-error-detail))

  (define (refuse who detail)
    (raise (condition (make-host-oracle-error detail)
                      (make-who-condition who)
                      (make-message-condition detail))))

  ;; --- byte constants (ASCII structural octets) ---------------------------
  (define COLON 58) (define AT 64) (define LBRK 91) (define RBRK 93)
  (define DOT 46)   (define PCT 37) (define SLASH 47) (define QUEST 63) (define HASH 35)
  (define LO-V 118) (define UP-V 86) (define ZERO 48)

  ;; --- the byte sets, from the ABNF ---------------------------------------
  ;; HEXDIG admits lower-case (RFC 3986 §6.2.2.1: "%3a" == "%3A"; the parser is
  ;; non-normalising, so both are valid pct-encoded).
  (define (oracle-alpha? b) (or (and (fx<=? #x41 b) (fx<=? b #x5A))
                                (and (fx<=? #x61 b) (fx<=? b #x7A))))
  (define (oracle-digit? b) (and (fx<=? #x30 b) (fx<=? b #x39)))
  (define (oracle-hexdig? b) (or (oracle-digit? b)
                                 (and (fx<=? #x41 b) (fx<=? b #x46))
                                 (and (fx<=? #x61 b) (fx<=? b #x66))))

  ;; unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
  (define (oracle-unreserved? b)
    (or (oracle-alpha? b) (oracle-digit? b)
        (fx=? b #x2D) (fx=? b #x2E) (fx=? b #x5F) (fx=? b #x7E)))

  ;; sub-delims = "!" "$" "&" "'" "(" ")" "*" "+" "," ";" "="
  (define (oracle-sub-delim? b)
    (and (memv b '(#x21 #x24 #x26 #x27 #x28 #x29 #x2A #x2B #x2C #x3B #x3D)) #t))

  ;; userinfo = *( unreserved / pct-encoded / sub-delims / ":" )  (literal bytes)
  (define (oracle-userinfo-literal? b)
    (or (oracle-unreserved? b) (oracle-sub-delim? b) (fx=? b COLON)))

  ;; reg-name = *( unreserved / pct-encoded / sub-delims )  (literal bytes)
  (define (oracle-reg-name-literal? b)
    (or (oracle-unreserved? b) (oracle-sub-delim? b)))

  ;; --- small byte helpers -------------------------------------------------
  (define (u8 bv i) (bytevector-u8-ref bv i))

  (define (find-byte bv start end b)
    (let loop ((i start))
      (cond ((fx>=? i end) #f)
            ((fx=? (u8 bv i) b) i)
            (else (loop (fx+ i 1))))))

  ;; "%" at i, then two bytes that exist within end and are both HEXDIG.
  (define (valid-pct? bv i end)
    (and (fx<? (fx+ i 2) end)
         (oracle-hexdig? (u8 bv (fx+ i 1)))
         (oracle-hexdig? (u8 bv (fx+ i 2)))))

  ;; scan a literal-or-pct component in [s,e); `bad` is the literal fault code.
  (define (scan-content bv s e literal? bad)
    (let loop ((i s))
      (cond ((fx>=? i e) (values #f #f))
            ((fx=? (u8 bv i) PCT)
             (if (valid-pct? bv i e) (loop (fx+ i 3))
                 (values 'invalid-pct-encoded i)))
            ((literal? (u8 bv i)) (loop (fx+ i 1)))
            (else (values bad i)))))

  (define (validate-userinfo bv s e)
    (scan-content bv s e oracle-userinfo-literal? 'invalid-userinfo))
  (define (validate-reg-name bv s e)
    (scan-content bv s e oracle-reg-name-literal? 'invalid-reg-name))

  ;; port = *DIGIT (empty is valid)
  (define (validate-port bv s e)
    (let loop ((i s))
      (cond ((fx>=? i e) (values #f #f))
            ((oracle-digit? (u8 bv i)) (loop (fx+ i 1)))
            (else (values 'invalid-port i)))))

  ;; --- the host grammar inside "[" ... "]" (faults reported at the "[") ----
  ;;
  ;; Each of these returns a fault CODE symbol or #f (valid); the caller supplies
  ;; the "[" index as the offset. A `dec-octet` range fault surfaces as
  ;; `invalid-dec-octet`; every structural fault as `invalid-ip-literal`.

  ;; h16 = 1*4HEXDIG
  (define (validate-h16 bv s e)
    (let ((len (fx- e s)))
      (if (or (fx=? len 0) (fx>? len 4))
          'invalid-ip-literal
          (let loop ((i s))
            (cond ((fx>=? i e) #f)
                  ((oracle-hexdig? (u8 bv i)) (loop (fx+ i 1)))
                  (else 'invalid-ip-literal))))))

  ;; dec-octet: 1-3 digits, value 0-255, canonical (no leading zero unless "0").
  ;; #f valid; 'invalid-dec-octet for a numeric-but-out-of-range/non-canonical
  ;; octet; 'invalid-ip-literal for an empty or non-numeric field.
  (define (validate-dec-octet bv s e)
    (let ((len (fx- e s)))
      (cond ((fx=? len 0) 'invalid-ip-literal)
            ((all-digits? bv s e)
             (cond ((fx>? len 3) 'invalid-dec-octet)
                   ((and (fx>? len 1) (fx=? (u8 bv s) ZERO)) 'invalid-dec-octet)
                   ((fx>? (dec-value bv s e) 255) 'invalid-dec-octet)
                   (else #f)))
            (else 'invalid-ip-literal))))

  (define (all-digits? bv s e)
    (let loop ((i s))
      (cond ((fx>=? i e) #t)
            ((oracle-digit? (u8 bv i)) (loop (fx+ i 1)))
            (else #f))))

  (define (dec-value bv s e)
    (let loop ((i s) (v 0))
      (if (fx>=? i e) v
          (loop (fx+ i 1) (fx+ (fx* v 10) (fx- (u8 bv i) ZERO))))))

  ;; IPv4address = four "."-separated dec-octets. #f valid; else a fault code.
  (define (validate-ipv4 bv s e)
    (let loop ((start s) (groups 0))
      (let ((dot (find-byte bv start e DOT)))
        (if dot
            (let ((code (validate-dec-octet bv start dot)))
              (if code code (loop (fx+ dot 1) (fx+ groups 1))))
            (let ((code (validate-dec-octet bv start e)))
              (cond (code code)
                    ((fx=? groups 3) #f)          ; exactly four octets
                    (else 'invalid-ip-literal))))))) ; too few

  ;; count-groups : bv s e ipv4-ok? -> Nat | Symbol
  ;; the number of 16-bit pieces in a ":"-separated run (IPv4 last counts 2), or a
  ;; fault code. An empty run is 0 pieces; an empty field (a stray ":" or a second
  ;; "::") is invalid.
  (define (count-groups bv s e ipv4-ok?)
    (if (fx>=? s e)
        0
        (let loop ((start s) (count 0))
          (let ((colon (find-byte bv start e COLON)))
            (if colon
                (let ((code (validate-h16 bv start colon)))    ; non-last: pure h16
                  (if code code (loop (fx+ colon 1) (fx+ count 1))))
                (if (and ipv4-ok? (find-byte bv start e DOT))  ; last, IPv4 allowed
                    (let ((code (validate-ipv4 bv start e)))
                      (if (symbol? code) code (fx+ count 2)))
                    (let ((code (validate-h16 bv start e)))
                      (if code code (fx+ count 1)))))))))

  ;; first "::" (two adjacent colons) in [s,e), or #f.
  (define (find-dcolon bv s e)
    (let loop ((i s))
      (cond ((fx>=? (fx+ i 1) e) #f)
            ((and (fx=? (u8 bv i) COLON) (fx=? (u8 bv (fx+ i 1)) COLON)) i)
            (else (loop (fx+ i 1))))))

  ;; IPv6address, by the counting model.
  (define (validate-ipv6 bv s e)
    (let ((dc (find-dcolon bv s e)))
      (if dc
          (let ((head (count-groups bv s dc #f)))            ; head: no IPv4
            (if (symbol? head) head
                (let ((tail (count-groups bv (fx+ dc 2) e #t)))
                  (if (symbol? tail) tail
                      (if (fx<=? (fx+ head tail) 7) #f 'invalid-ip-literal)))))
          (let ((total (count-groups bv s e #t)))            ; no "::": exactly 8
            (if (symbol? total) total
                (if (fx=? total 8) #f 'invalid-ip-literal))))))

  ;; IPvFuture = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
  (define (validate-ipvfuture bv s e)
    (let ((hexend (let loop ((j (fx+ s 1)))
                    (if (and (fx<? j e) (oracle-hexdig? (u8 bv j)))
                        (loop (fx+ j 1)) j))))
      (cond ((fx=? hexend (fx+ s 1)) 'invalid-ip-literal)     ; no HEXDIG
            ((or (fx>=? hexend e) (not (fx=? (u8 bv hexend) DOT))) 'invalid-ip-literal)
            ((fx>=? (fx+ hexend 1) e) 'invalid-ip-literal)     ; nothing after "."
            (else
             (let loop ((k (fx+ hexend 1)))
               (cond ((fx>=? k e) #f)
                     ((let ((b (u8 bv k)))
                        (or (oracle-unreserved? b) (oracle-sub-delim? b) (fx=? b COLON)))
                      (loop (fx+ k 1)))
                     (else 'invalid-ip-literal)))))))

  ;; interior of "[" ... "]" in [s,e): IPvFuture if it opens with "v"/"V", else
  ;; IPv6address. Empty interior is invalid.
  (define (validate-ip-literal-interior bv s e)
    (cond ((fx>=? s e) 'invalid-ip-literal)
          ((let ((b (u8 bv s))) (or (fx=? b LO-V) (fx=? b UP-V)))
           (validate-ipvfuture bv s e))
          (else (validate-ipv6 bv s e))))

  ;; --- the reference validator --------------------------------------------
  ;;
  ;; oracle-scan-authority : Bytevector -> (values (Option Symbol) (Option Nat))
  ;;
  ;; #f #f when the authority is valid (an EMPTY authority is valid: empty host);
  ;; else the first fault code and its AUTHORITY-relative index. Split userinfo at
  ;; the single "@" first, then host/port bracket-aware: the port ":" is the one
  ;; AFTER the closing "]" for an IP-literal, else the first ":".
  (define (oracle-scan-authority bv)
    (define n (bytevector-length bv))
    (let* ((at (find-byte bv 0 n AT))
           (hp (if at (fx+ at 1) 0)))
      (let-values (((ucode uidx)
                    (if at (validate-userinfo bv 0 at) (values #f #f))))
        (if ucode
            (values ucode uidx)                     ; userinfo is leftmost
            (cond
              ((fx>=? hp n) (values #f #f))          ; empty host (e.g. "user@", "")
              ((fx=? (u8 bv hp) LBRK)
               (let ((close (find-byte bv (fx+ hp 1) n RBRK)))
                 (if (not close)
                     (values 'invalid-ip-literal hp) ; unterminated "["
                     (let ((icode (validate-ip-literal-interior bv (fx+ hp 1) close)))
                       (cond (icode (values icode hp))                 ; report at "["
                             ((fx=? (fx+ close 1) n) (values #f #f))    ; no port
                             ((fx=? (u8 bv (fx+ close 1)) COLON)
                              (validate-port bv (fx+ close 2) n))
                             (else (values 'invalid-ip-literal hp))))))) ; stray after "]"
              (else
               (let ((colon (find-byte bv hp n COLON)))
                 (if colon
                     (let-values (((hcode hidx) (validate-reg-name bv hp colon)))
                       (if hcode (values hcode hidx)
                           (validate-port bv (fx+ colon 1) n)))
                     (validate-reg-name bv hp n)))))))))

  ;; --- the test-side authority extractor ----------------------------------
  ;;
  ;; authority-of : Bytevector -> (values Bytevector Nat)
  ;;
  ;; The authority bytes and their ABSOLUTE start in a corpus input. Deliberately
  ;; naive and INDEPENDENT of the src scanner: a corpus row is "<scheme>://<auth>"
  ;; optionally followed by "/", "?" or "#", so the authority is the bytes after
  ;; the first "//" up to the first of those delimiters or the end. The Slice ②
  ;; lane re-checks these inputs against the REAL scanner via uri-parse-validate,
  ;; so a disagreement between this split and the scanner would surface there.
  (define (authority-of bv)
    (define n (bytevector-length bv))
    (let ((ss (find-slashslash bv 0 n)))
      (unless ss (refuse 'authority-of "no \"//\" in the corpus input"))
      (let* ((start (fx+ ss 2))
             (end (first-delim bv start n)))
        (values (subbytes bv start end) start))))

  (define (find-slashslash bv s e)
    (let loop ((i s))
      (cond ((fx>=? (fx+ i 1) e) #f)
            ((and (fx=? (u8 bv i) SLASH) (fx=? (u8 bv (fx+ i 1)) SLASH)) i)
            (else (loop (fx+ i 1))))))

  (define (first-delim bv s e)
    (let loop ((i s))
      (cond ((fx>=? i e) e)
            ((let ((b (u8 bv i))) (or (fx=? b SLASH) (fx=? b QUEST) (fx=? b HASH))) i)
            (else (loop (fx+ i 1))))))

  (define (subbytes bv s e)
    (let ((out (make-bytevector (fx- e s))))
      (let loop ((i s) (j 0))
        (if (fx>=? i e) out
            (begin (bytevector-u8-set! out j (u8 bv i))
                   (loop (fx+ i 1) (fx+ j 1)))))))

  ;; --- the negative corpus (decision 0025 item 7) -------------------------
  ;;
  ;; A row is (mode input component code offset note). `input` is a STRING (its
  ;; UTF-8 bytes) or a BYTEVECTOR (exact bytes for the > 0x7F / control cases).
  ;; `offset` is ABSOLUTE in the input. `component` is the authority SUB-part the
  ;; fault falls in (userinfo / reg-name / port / ip-literal / dec-octet).
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

  ;; --- the Slice ⓪ cross-check --------------------------------------------
  ;;
  ;; negative-cross-check : Nv -> (Option String)
  ;;
  ;; #f when the row agrees with the oracle; else a diagnostic. Extracts the
  ;; authority from the row input, runs the oracle, rebases the relative index to
  ;; absolute, and demands the row's (code, absolute-offset) EXACTLY -- a full
  ;; agreement check, stronger than a per-byte one, because the oracle here can
  ;; parse the whole authority.
  (define (negative-cross-check v)
    (define (say . parts) (apply string-append parts))
    (let-values (((auth astart) (authority-of (nv-input v))))
      (let-values (((code idx) (oracle-scan-authority auth)))
        (cond
          ((not code)
           (say "the oracle finds the authority VALID, but the row claims "
                (symbol->string (nv-code v)) " at " (number->string (nv-offset v))))
          ((not (code-matches-component? (nv-code v) (nv-component v)))
           (say "code " (symbol->string (nv-code v)) " does not name component "
                (symbol->string (nv-component v))))
          ((not (eq? code (nv-code v)))
           (say "the oracle raises " (symbol->string code)
                " but the row records " (symbol->string (nv-code v))))
          ((not (= (+ astart idx) (nv-offset v)))
           (say "the oracle offset " (number->string (+ astart idx))
                " (authority start " (number->string astart) " + relative "
                (number->string idx) ") but the row records "
                (number->string (nv-offset v))))
          (else #f)))))

  ;; code-matches-component? : does the code name a component that admits the
  ;; production it refers to? pct-encoded is admitted by userinfo and reg-name.
  (define (code-matches-component? code component)
    (case code
      ((invalid-userinfo)  (eq? component 'userinfo))
      ((invalid-reg-name)  (eq? component 'reg-name))
      ((invalid-port)      (eq? component 'port))
      ((invalid-ip-literal)(eq? component 'ip-literal))
      ((invalid-dec-octet) (eq? component 'dec-octet))
      ((invalid-pct-encoded) (and (memq component '(userinfo reg-name)) #t))
      (else #f))))
