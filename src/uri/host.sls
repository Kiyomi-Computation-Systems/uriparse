#!r6rs
;;; (uri host): RFC 3986 §3.2 AUTHORITY validation (M4, decision 0025). M3's
;;; (uri charset) judges the components the core holds whole; this library judges
;;; the AUTHORITY -- the opaque span the forward-only scanner cannot sub-split -- by
;;; finding the userinfo/host/port seams itself and validating each: userinfo, host
;;; as reg-name / IPv4address / IP-literal (→ IPv6address / IPvFuture), and port.
;;;
;;; PURE, and INDEPENDENT of the test-side (uri test host-oracle): the two are two
;;; readings of the same ABNF, graded into agreement on every input, and the
;;; hand-derived negative corpus is a THIRD (decisions 0005 / 0012 / 0025). It
;;; reuses (uri percent)'s §2.3 unreserved test and hex primitive -- the same ones
;;; (uri charset) reuses, and DIFFERENT ones from the oracle, which defines its own
;;; -- so a charset mistake cannot be shared between the product and its oracle.
;;;
;;; THE SPLIT is bracket-aware (decision 0025 item 4): userinfo ends at the single
;;; "@"; the port ":" is the one AFTER the closing "]" for an IP-literal, else the
;;; first ":". THE HOST is an ordered union with a permissive tail (§3.2.2): a "["
;;; commits to IP-literal, otherwise a bare host is a reg-name -- so a dotted quad
;;; like "999.1.1.1" is a VALID reg-name, and `dec-octet` range errors are reachable
;;; ONLY inside "[" ... "]". IPv6address is read as a COUNTER (≤8 h16 pieces, one
;;; optional "::", an optional trailing IPv4address as ls32 counting 2), NOT the nine
;;; ABNF alternatives (decision 0025 item 5). Every IP-literal-interior fault --
;;; including a `dec-octet` range error -- is reported at the opening "[".
;;;
;;; validate-authority returns a component-RELATIVE index; the shell ((uri collect))
;;; rebases it onto the authority's absolute start (already captured since M3).
(library (uri host)
  (export uri-host-error-codes uri-host-error-code? validate-authority
          authority-host-span)
  (import (rnrs) (uri percent) (uri range))

  ;; The CORE host error vocabulary (decision 0025 item 6): each the RFC's own ABNF
  ;; spelling (0009 item 1), living with the core, out of (uri vocabulary).
  ;; `invalid-pct-encoded` is shared with (uri charset): userinfo and reg-name both
  ;; admit pct-encoded.
  (define uri-host-error-codes
    '(invalid-userinfo invalid-reg-name invalid-ip-literal invalid-dec-octet
      invalid-port invalid-pct-encoded))

  (define (uri-host-error-code? x) (and (memq x uri-host-error-codes) #t))

  ;; --- byte constants ------------------------------------------------------
  (define PERCENT 37) (define COLON 58) (define AT 64)
  (define LBRK 91)    (define RBRK 93)  (define DOT 46)
  (define ZERO 48)    (define NINE 57)  (define LO-V 118) (define UP-V 86)

  (define (digit? b) (and (fx>=? b ZERO) (fx<=? b NINE)))

  ;; sub-delims = "!" "$" "&" "'" "(" ")" "*" "+" "," ";" "="
  (define (sub-delim? b)
    (or (fx=? b 33) (fx=? b 36) (fx=? b 38) (fx=? b 39) (fx=? b 40) (fx=? b 41)
        (fx=? b 42) (fx=? b 43) (fx=? b 44) (fx=? b 59) (fx=? b 61)))

  ;; userinfo = unreserved / pct-encoded / sub-delims / ":"  (literal bytes)
  (define (userinfo-literal? b)
    (or (unreserved-byte? b) (sub-delim? b) (fx=? b COLON)))
  ;; reg-name = unreserved / pct-encoded / sub-delims  (literal bytes)
  (define (reg-name-literal? b)
    (or (unreserved-byte? b) (sub-delim? b)))

  (define (u8 bv i) (bytevector-u8-ref bv i))

  (define (find-byte bv start end b)
    (let loop ((i start))
      (cond ((fx>=? i end) #f)
            ((fx=? (u8 bv i) b) i)
            (else (loop (fx+ i 1))))))

  ;; "%" at i, then two HEXDIG within end. hex-digit-value is #f for a non-hex byte.
  (define (pct-triple? bv i end)
    (and (fx<? (fx+ i 2) end)
         (hex-digit-value (u8 bv (fx+ i 1)))
         (hex-digit-value (u8 bv (fx+ i 2)))
         #t))

  ;; scan [s,e): a literal byte, or "%" HEXDIG HEXDIG; `bad` is the literal code.
  (define (scan bv s e literal? bad)
    (let loop ((i s))
      (cond ((fx>=? i e) (values #f #f))
            ((fx=? (u8 bv i) PERCENT)
             (if (pct-triple? bv i e) (loop (fx+ i 3))
                 (values 'invalid-pct-encoded i)))
            ((literal? (u8 bv i)) (loop (fx+ i 1)))
            (else (values bad i)))))

  (define (validate-userinfo bv s e) (scan bv s e userinfo-literal? 'invalid-userinfo))
  (define (validate-reg-name bv s e) (scan bv s e reg-name-literal? 'invalid-reg-name))

  ;; port = *DIGIT (empty is valid)
  (define (validate-port bv s e)
    (let loop ((i s))
      (cond ((fx>=? i e) (values #f #f))
            ((digit? (u8 bv i)) (loop (fx+ i 1)))
            (else (values 'invalid-port i)))))

  ;; --- the host grammar inside "[" ... "]" --------------------------------
  ;; Each returns a fault CODE symbol or #f (valid); the caller supplies the "["
  ;; index as the offset.

  ;; h16 = 1*4HEXDIG
  (define (h16? bv s e)
    (let ((len (fx- e s)))
      (and (fx>? len 0) (fx<=? len 4)
           (let loop ((i s))
             (or (fx>=? i e)
                 (and (hex-digit-value (u8 bv i)) (loop (fx+ i 1))))))))

  (define (all-digit? bv s e)
    (let loop ((i s)) (or (fx>=? i e) (and (digit? (u8 bv i)) (loop (fx+ i 1))))))

  (define (dec-val bv s e)
    (let loop ((i s) (v 0))
      (if (fx>=? i e) v (loop (fx+ i 1) (fx+ (fx* v 10) (fx- (u8 bv i) ZERO))))))

  ;; dec-octet: #f valid; 'invalid-dec-octet for numeric-but-out-of-range or
  ;; non-canonical (a leading zero); 'invalid-ip-literal for empty or non-numeric.
  (define (dec-octet bv s e)
    (let ((len (fx- e s)))
      (cond ((fx=? len 0) 'invalid-ip-literal)
            ((not (all-digit? bv s e)) 'invalid-ip-literal)
            ((fx>? len 3) 'invalid-dec-octet)
            ((and (fx>? len 1) (fx=? (u8 bv s) ZERO)) 'invalid-dec-octet)
            ((fx>? (dec-val bv s e) 255) 'invalid-dec-octet)
            (else #f))))

  ;; IPv4address = four "."-separated dec-octets.
  (define (ipv4 bv s e)
    (let loop ((start s) (n 0))
      (let ((dot (find-byte bv start e DOT)))
        (if dot
            (let ((c (dec-octet bv start dot)))
              (if c c (loop (fx+ dot 1) (fx+ n 1))))
            (let ((c (dec-octet bv start e)))
              (cond (c c) ((fx=? n 3) #f) (else 'invalid-ip-literal)))))))

  ;; count-pieces : bv s e ipv4-ok? -> Nat | Symbol
  ;; the 16-bit pieces in a ":"-separated run (IPv4 last counts 2), or a fault. An
  ;; empty field (a stray ":" or a second "::") is invalid.
  (define (count-pieces bv s e ipv4-ok?)
    (if (fx>=? s e) 0
        (let loop ((start s) (n 0))
          (let ((colon (find-byte bv start e COLON)))
            (if colon
                (if (h16? bv start colon) (loop (fx+ colon 1) (fx+ n 1))
                    'invalid-ip-literal)
                (if (and ipv4-ok? (find-byte bv start e DOT))
                    (let ((c (ipv4 bv start e))) (if (symbol? c) c (fx+ n 2)))
                    (if (h16? bv start e) (fx+ n 1) 'invalid-ip-literal)))))))

  ;; first "::" (two adjacent colons) in [s,e), or #f.
  (define (dcolon bv s e)
    (let loop ((i s))
      (cond ((fx>=? (fx+ i 1) e) #f)
            ((and (fx=? (u8 bv i) COLON) (fx=? (u8 bv (fx+ i 1)) COLON)) i)
            (else (loop (fx+ i 1))))))

  ;; IPv6address, by the counting model: with "::" the pieces total ≤7 (it fills
  ;; ≥1 zero group); without, exactly 8.
  (define (ipv6 bv s e)
    (let ((d (dcolon bv s e)))
      (if d
          (let ((h (count-pieces bv s d #f)))
            (if (symbol? h) h
                (let ((t (count-pieces bv (fx+ d 2) e #t)))
                  (if (symbol? t) t
                      (if (fx<=? (fx+ h t) 7) #f 'invalid-ip-literal)))))
          (let ((total (count-pieces bv s e #t)))
            (if (symbol? total) total
                (if (fx=? total 8) #f 'invalid-ip-literal))))))

  ;; IPvFuture = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
  (define (ipvfuture bv s e)
    (let ((hexend (let loop ((j (fx+ s 1)))
                    (if (and (fx<? j e) (hex-digit-value (u8 bv j))) (loop (fx+ j 1)) j))))
      (cond ((fx=? hexend (fx+ s 1)) 'invalid-ip-literal)          ; no HEXDIG
            ((or (fx>=? hexend e) (not (fx=? (u8 bv hexend) DOT))) 'invalid-ip-literal)
            ((fx>=? (fx+ hexend 1) e) 'invalid-ip-literal)          ; nothing after "."
            (else (let loop ((k (fx+ hexend 1)))
                    (cond ((fx>=? k e) #f)
                          ((let ((b (u8 bv k)))
                             (or (unreserved-byte? b) (sub-delim? b) (fx=? b COLON)))
                           (loop (fx+ k 1)))
                          (else 'invalid-ip-literal)))))))

  ;; interior of "[" ... "]" in [s,e): IPvFuture if it opens with "v"/"V", else
  ;; IPv6address. Empty interior is invalid.
  (define (ip-literal-interior bv s e)
    (cond ((fx>=? s e) 'invalid-ip-literal)
          ((let ((b (u8 bv s))) (or (fx=? b LO-V) (fx=? b UP-V))) (ipvfuture bv s e))
          (else (ipv6 bv s e))))

  ;; --- validate-authority --------------------------------------------------
  ;;
  ;; validate-authority : Bytevector [Nat [Nat]] -> (values (Option Symbol) (Option Nat))
  ;;
  ;; #f #f when the authority is valid (an EMPTY authority is valid: empty host);
  ;; else the first fault code and its authority-RELATIVE index. Split userinfo at
  ;; the single "@" first, then host/port bracket-aware. userinfo → host → port,
  ;; left to right, so the first fault is the leftmost.
  ;;
  ;; The authority is bv[start, end), by default the whole bytevector, so an
  ;; embedder can judge a span of a larger buffer in place without copying it
  ;; (decision 0036). Nothing outside [start, end) is read, and the index is
  ;; relative to start. A range not within the bytevector is an assertion violation.
  (define validate-authority
    (case-lambda
      ((bv) (authority-fault bv 0 (bytevector-length bv)))   ; relative = absolute
      ((bv start) (validate-authority bv start (bytevector-length bv)))
      ((bv start end)
       (check-range 'validate-authority bv start end)
       (let-values (((code i) (authority-fault bv start end)))
         (values code (and i (fx- i start)))))))

  ;; authority-split : Bytevector Nat Nat -> (values (Option Nat) Nat Symbol (Option Nat))
  ;;
  ;; The bracket-aware split of the authority bv[s, e) (decision 0025 item 4): the
  ;; ONE split validate-authority and authority-host-span both read, so the host
  ;; one bounds is the host the other judges. Its values, as indices IN bv: the
  ;; first "@" (#f if none); the host start hp (after that "@", else s); the host's
  ;; kind -- 'empty when hp = e, 'ip-literal when a "[" opens it, else 'reg-name;
  ;; and its delimiter -- the first "]" after hp for an ip-literal, the first ":"
  ;; from hp for a reg-name, #f when there is none (always #f for 'empty).
  (define (authority-split bv s e)
    (let* ((at (find-byte bv s e AT))
           (hp (if at (fx+ at 1) s)))
      (cond ((fx>=? hp e) (values at hp 'empty #f))
            ((fx=? (u8 bv hp) LBRK)
             (values at hp 'ip-literal (find-byte bv (fx+ hp 1) e RBRK)))
            (else (values at hp 'reg-name (find-byte bv hp e COLON))))))

  ;; The first fault in the authority bv[s, e) and its index IN bv, or #f #f.
  (define (authority-fault bv s e)
    (let-values (((at hp kind delim) (authority-split bv s e)))
      (let-values (((uc ui) (if at (validate-userinfo bv s at) (values #f #f))))
        (cond
          (uc (values uc ui))                                ; userinfo is leftmost
          ((eq? kind 'empty) (values #f #f))                 ; e.g. "user@", ""
          ((eq? kind 'ip-literal)
           (if (not delim) (values 'invalid-ip-literal hp)   ; unterminated "["
               (let ((ic (ip-literal-interior bv (fx+ hp 1) delim)))
                 (cond (ic (values ic hp))                   ; report at "["
                       ((fx=? (fx+ delim 1) e) (values #f #f)) ; no port
                       ((fx=? (u8 bv (fx+ delim 1)) COLON)
                        (validate-port bv (fx+ delim 2) e))
                       (else (values 'invalid-ip-literal hp)))))) ; stray after "]"
          (delim                                             ; reg-name ":" port
           (let-values (((hc hi) (validate-reg-name bv hp delim)))
             (if hc (values hc hi) (validate-port bv (fx+ delim 1) e))))
          (else (validate-reg-name bv hp e))))))

  ;; authority-host-span : Bytevector [Nat [Nat]] -> (values Nat Nat)
  ;;
  ;; The [start, end) of the HOST within an authority, by the SAME bracket-aware
  ;; split as validate-authority (decision 0025 item 4): the host begins after the
  ;; single "@" (or at 0), and ends at the closing "]" for an IP-literal (brackets
  ;; included) or the port ":" for a reg-name/IPv4, else the end. Used by
  ;; (uri normalize) to case-fold only the host (§6.2.2.1a) -- userinfo is
  ;; case-sensitive and port is digits. Structural and total (v0.1 is lenient), so
  ;; an unterminated "[" yields the span to the end.
  ;;
  ;; The authority is bv[start, end), by default the whole bytevector (decision
  ;; 0036): nothing outside it is read, and both bounds are relative to start, like
  ;; validate-authority's index. A range not within the bytevector is an assertion
  ;; violation.
  (define authority-host-span
    (case-lambda
      ((bv) (host-span bv 0 (bytevector-length bv)))          ; relative = absolute
      ((bv start) (authority-host-span bv start (bytevector-length bv)))
      ((bv start end)
       (check-range 'authority-host-span bv start end)
       (let-values (((hs he) (host-span bv start end)))
         (values (fx- hs start) (fx- he start))))))

  ;; The host's bounds IN bv, within the authority bv[s, e).
  (define (host-span bv s e)
    (let-values (((at hp kind delim) (authority-split bv s e)))
      (case kind
        ((empty) (values hp hp))
        ((ip-literal) (values hp (if delim (fx+ delim 1) e)))  ; "]" inclusive, else to e
        (else (values hp (or delim e)))))))
