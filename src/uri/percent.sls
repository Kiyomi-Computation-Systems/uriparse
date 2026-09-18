#!r6rs
;;; (uri percent): the percent-encoding mechanics of RFC 3986 §2.1, over
;;; bytevectors.
;;;
;;; A URI is a byte string and `%C3%A9` is two octets, so this library never
;;; leaves bytevector space: it decodes and encodes octets, and the §2.3
;;; unreserved test and the hex primitives it exports are all byte-level. Staying
;;; in bytevectors is decision 0010 -- it keeps `(rnrs unicode)`'s length-changing
;;; Unicode case fold out of reach, since reaching it would first require an
;;; explicit `utf8->string`, a visible seam this library never crosses.
;;;
;;; TOTAL, NOT VALIDATING (decision 0011). v0.1 splits and resolves; it does not
;;; reject. `pct-decode` therefore accepts any bytevector: a `%` that does not
;;; begin two hex digits is copied through as the literal octet `%`, never an
;;; error. `%ZZ` decodes to `%ZZ`. The charset a component actually admits is
;;; M3/v0.2's question, deliberately not asked here.
;;;
;;; This is the mechanics layer; the §6 policy that decides WHICH percent-triples
;;; to normalize and which case to fold lives in `(uri normalize)`, which imports
;;; the two hex primitives below rather than re-deriving them. Pure R6RS,
;;; importing only `(rnrs)`.
(library (uri percent)
  (export
    ;; the codec
    pct-decode pct-encode
    ;; the §2.3 unreserved test, shared with the normalizer
    unreserved-byte?
    ;; the hex primitives the normalizer reuses to read and re-render a triple
    hex-digit-value nibble->hex-digit)
  (import (rnrs))

  ;; Byte constants, named so the loops below read as bytes rather than magic
  ;; numbers. ASCII throughout: a URI's structural octets are ASCII (design §5).
  (define PERCENT 37)                    ; #\%
  (define ZERO 48) (define NINE 57)      ; #\0 .. #\9
  (define UP-A 65) (define UP-F 70) (define UP-Z 90)   ; #\A .. #\F .. #\Z
  (define LO-A 97) (define LO-F 102) (define LO-Z 122) ; #\a .. #\f .. #\z
  (define HYPHEN 45) (define DOT 46)                   ; #\- #\.
  (define UNDERSCORE 95) (define TILDE 126)            ; #\_ #\~   the §2.3 marks

  ;; hex-digit-value : Octet -> (Option (Integer 0 15))
  ;; The numeric value of an ASCII hex-digit octet, case-insensitive on input
  ;; (§2.1: HEXDIG is 0-9 A-F a-f), or #f for any octet that is not a hex digit.
  ;; The #f is what makes it double as the "is this a hex digit" test the decoder
  ;; needs, without a second predicate that could drift from it.
  (define (hex-digit-value b)
    (cond ((and (fx>=? b ZERO) (fx<=? b NINE)) (fx- b ZERO))
          ((and (fx>=? b UP-A) (fx<=? b UP-F)) (fx+ 10 (fx- b UP-A)))
          ((and (fx>=? b LO-A) (fx<=? b LO-F)) (fx+ 10 (fx- b LO-A)))
          (else #f)))

  ;; nibble->hex-digit : (Integer 0 15) -> Octet
  ;; A nibble as an UPPERCASE ASCII hex-digit octet. Uppercase is §2.1's producer
  ;; guidance and §6.2.2.1's normal form, so the encoder and the normalizer agree
  ;; on casing before §6 runs. Inverse of hex-digit-value over 0..15.
  (define (nibble->hex-digit v)
    (if (fx<? v 10) (fx+ ZERO v) (fx+ UP-A (fx- v 10))))

  ;; unreserved-byte? : Octet -> Boolean
  ;; RFC 3986 §2.3 unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~", and
  ;; nothing else -- `+` is a sub-delim, not a mark. This is the only set a
  ;; §6.2.2.2 normalizer may percent-decode, and the conservative "leave it
  ;; alone" set an encoder may keep literal.
  (define (unreserved-byte? b)
    (or (and (fx>=? b UP-A) (fx<=? b UP-Z))     ; A-Z
        (and (fx>=? b LO-A) (fx<=? b LO-Z))     ; a-z
        (and (fx>=? b ZERO) (fx<=? b NINE))     ; 0-9
        (fx=? b HYPHEN) (fx=? b DOT) (fx=? b UNDERSCORE) (fx=? b TILDE)))

  ;; pct-decode : Bytevector -> Bytevector
  ;; Replace every valid `%XX` triple with its octet; copy every other octet
  ;; verbatim. Total: a `%` not followed by two hex digits (including at end of
  ;; input) is the literal octet `%` and decoding continues at the next octet.
  ;; The result is never longer than the input.
  ;;
  ;; SINGLE PASS, never recursive (RFC 3986 §2.4: "do not decode more than
  ;; once"). A decoded octet is emitted and the cursor advances past the triple;
  ;; it is never re-scanned, so `%2541` decodes to `%41`, not to `A`. A
  ;; decode-to-fixpoint rewrite would silently break this.
  (define (pct-decode bv)
    (let ((n (bytevector-length bv)))
      (call-with-bytevector-output-port
       (lambda (out)
         (let loop ((i 0))
           (when (fx<? i n)
             (let ((b (bytevector-u8-ref bv i)))
               (if (fx=? b PERCENT)
                   ;; Both hex digits must be present AND in range. Guard the
                   ;; indices first so the reads never run off the end.
                   (let* ((have2 (fx<? (fx+ i 2) n))
                          (hi (and have2 (hex-digit-value (bytevector-u8-ref bv (fx+ i 1)))))
                          (lo (and have2 (hex-digit-value (bytevector-u8-ref bv (fx+ i 2))))))
                     (if (and hi lo)
                         (begin (put-u8 out (fx+ (fx* 16 hi) lo)) (loop (fx+ i 3)))
                         (begin (put-u8 out b) (loop (fx+ i 1)))))  ; literal %
                   (begin (put-u8 out b) (loop (fx+ i 1)))))))))))

  ;; pct-encode : Bytevector (Octet -> Boolean) -> Bytevector
  ;; Copy every octet the `safe?` predicate accepts; replace every other octet
  ;; with `%` and its two UPPERCASE hex digits. The predicate is the component's
  ;; allowed set -- the charset knowledge lives with the caller, not here
  ;; (M3/v0.2), and `unreserved-byte?` is the conservative default.
  (define (pct-encode bv safe?)
    (let ((n (bytevector-length bv)))
      (call-with-bytevector-output-port
       (lambda (out)
         (let loop ((i 0))
           (when (fx<? i n)
             (let ((b (bytevector-u8-ref bv i)))
               (if (safe? b)
                   (put-u8 out b)
                   (begin (put-u8 out PERCENT)
                          (put-u8 out (nibble->hex-digit (fxdiv b 16)))
                          (put-u8 out (nibble->hex-digit (fxmod b 16)))))
               (loop (fx+ i 1))))))))))
