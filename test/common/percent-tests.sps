#!r6rs
;;; unit.percent -- the percent mechanics: decode every valid %XX, encode by a
;;; caller-supplied safe? predicate, and the §2.3 unreserved set plus the two hex
;;; primitives `(uri normalize)` reuses. Pure bytevectors in, bytevectors out; no
;;; scanner, no components, no §6 policy (that is unit.normalize).
;;;
;;; Two decisions this suite pins, both from decision 0011's non-validating
;;; stance: pct-decode is TOTAL -- a malformed `%` (not followed by two hex
;;; digits) is left byte-for-byte, never an error -- and pct-encode always emits
;;; UPPERCASE hex (§2.1's producer guidance, so the encoder and the normalizer
;;; agree on casing before §6 ever runs).
(import (rnrs)
        (uri test harness)
        (uri percent))

;; `a` builds a bytevector from an ASCII string; `bytes` from raw octets. Both
;; inputs and expectations here are byte strings -- a URI is bytes (decision
;; 0010) -- and the ASCII spelling is only a convenience for the reader.
(define (a str) (string->utf8 str))
(define (bytes . lst) (u8-list->bytevector lst))

(harness-begin "unit.percent")

;;; --- the unreserved set (§2.3): ALPHA / DIGIT / - . _ ~ and nothing else ----
(harness-group "unreserved-byte?"
  (lambda ()
    (harness-case "every ALPHA, DIGIT and the four marks are unreserved"
      (lambda ()
        (for-each
         (lambda (ch) (check (string ch) (unreserved-byte? (char->integer ch))))
         (string->list
          "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"))))

    ;; The plausible over-reach: `+` is a sub-delim, not a mark; and every
    ;; gen-/sub-delim, space, control and `%` itself is reserved OR excluded.
    (harness-case "reserved and excluded bytes are not unreserved"
      (lambda ()
        (for-each
         (lambda (ch)
           (check (string-append "not " (string ch))
                  (not (unreserved-byte? (char->integer ch)))))
         (string->list "+:/?#[]@!$&'()*,;= %\"<>\\^`{|}"))
        (check "NUL not unreserved"  (not (unreserved-byte? 0)))
        (check "DEL not unreserved"  (not (unreserved-byte? 127)))
        (check "high byte 0xFF not unreserved" (not (unreserved-byte? 255)))))))

;;; --- the hex primitives normalize reuses ------------------------------------
(harness-group "hex-digit-value"
  (lambda ()
    (harness-case "0-9 map to 0-9"
      (lambda ()
        (check-equal "0" (hex-digit-value (char->integer #\0)) 0)
        (check-equal "9" (hex-digit-value (char->integer #\9)) 9)))
    (harness-case "A-F and a-f both map to 10-15 (input hex is case-insensitive)"
      (lambda ()
        (check-equal "A" (hex-digit-value (char->integer #\A)) 10)
        (check-equal "C" (hex-digit-value (char->integer #\C)) 12)
        (check-equal "F" (hex-digit-value (char->integer #\F)) 15)
        (check-equal "a" (hex-digit-value (char->integer #\a)) 10)
        (check-equal "c" (hex-digit-value (char->integer #\c)) 12)
        (check-equal "f" (hex-digit-value (char->integer #\f)) 15)))
    ;; The non-hex checks pin BOTH boundaries of each range -- the byte just
    ;; below and just above -- so an off-by-one that widened a bound by one is
    ;; caught: `/`:`</`0`>`, `:`:`<9`>`, `@`:`<A`>`, `G`:`<F`>`, backtick:`<a`>`,
    ;; `g`:`<f`>`. Without `@` and backtick a lowered UP-A/LO-A would slip.
    (harness-case "a non-hex byte is #f, not a value"
      (lambda ()
        (check "/ (just below 0)"  (not (hex-digit-value (char->integer #\/))))
        (check ": (just above 9)"  (not (hex-digit-value (char->integer #\:))))
        (check "@ (just below A)"  (not (hex-digit-value (char->integer #\@))))
        (check "G (just above F)"  (not (hex-digit-value (char->integer #\G))))
        (check "` (just below a)"  (not (hex-digit-value (char->integer #\`))))
        (check "g (just above f)"  (not (hex-digit-value (char->integer #\g))))
        (check "space is not hex"  (not (hex-digit-value 32)))))))

(harness-group "nibble->hex-digit"
  (lambda ()
    (harness-case "nibbles render as UPPERCASE ASCII hex digits"
      (lambda ()
        (check-equal "0"  (nibble->hex-digit 0)  (char->integer #\0))
        (check-equal "9"  (nibble->hex-digit 9)  (char->integer #\9))
        (check-equal "10" (nibble->hex-digit 10) (char->integer #\A))
        (check-equal "15" (nibble->hex-digit 15) (char->integer #\F))))
    ;; The two primitives are inverse over the whole nibble range, which is what
    ;; lets normalize parse a triple and re-render it uppercased.
    (harness-case "hex-digit-value inverts nibble->hex-digit for every nibble"
      (lambda ()
        (let loop ((v 0))
          (when (< v 16)
            (check-equal (number->string v)
                         (hex-digit-value (nibble->hex-digit v)) v)
            (loop (+ v 1))))))))

;;; --- pct-decode: decode every valid %XX, leave a malformed % alone ----------
(harness-group "pct-decode"
  (lambda ()
    (harness-case "a valid triple decodes to its octet"
      (lambda ()
        (check-equal "%41 -> A" (pct-decode (a "%41")) (a "A"))
        (check-equal "%2F -> /" (pct-decode (a "%2F")) (a "/"))
        (check-equal "%20 -> space" (pct-decode (a "%20")) (a " "))))
    (harness-case "input hex is case-insensitive"
      (lambda ()
        (check-equal "%2f -> /"    (pct-decode (a "%2f")) (a "/"))
        (check-equal "%7b -> {"    (pct-decode (a "%7b")) (a "{"))
        ;; Both cases pinned to the octet 0x3A itself, not merely to each other:
        ;; a decoder mapping both spellings to the same WRONG value must not pass.
        (check-equal "%3a -> 0x3A" (pct-decode (a "%3a")) (bytes 58))
        (check-equal "%3A -> 0x3A" (pct-decode (a "%3A")) (bytes 58))))
    (harness-case "%00 decodes to the NUL octet, %FF to 255"
      (lambda ()
        (check-equal "%00" (pct-decode (a "%00")) (bytes 0))
        (check-equal "%FF" (pct-decode (a "%FF")) (bytes 255))))
    (harness-case "adjacent and embedded triples all decode"
      (lambda ()
        (check-equal "%41%42 -> AB"   (pct-decode (a "%41%42")) (a "AB"))
        (check-equal "a%20b -> a b"   (pct-decode (a "a%20b")) (a "a b"))
        (check-equal "%2Fx%2F -> /x/" (pct-decode (a "%2Fx%2F")) (a "/x/"))))
    (harness-case "no percent means the bytes pass through unchanged"
      (lambda ()
        (check-equal "plain" (pct-decode (a "hello-world")) (a "hello-world"))
        (check-equal "empty" (pct-decode (a "")) (a ""))))
    ;; The non-validating stance (decision 0011): a `%` that does not begin a
    ;; valid triple is a literal byte, and decode is total -- it never raises.
    (harness-case "a malformed % is left byte-for-byte"
      (lambda ()
        (check-equal "%ZZ (neither hex)"     (pct-decode (a "%ZZ")) (a "%ZZ"))
        (check-equal "%GG (neither hex)"     (pct-decode (a "%GG")) (a "%GG"))
        (check-equal "%G1 (first not hex)"   (pct-decode (a "%G1")) (a "%G1"))
        (check-equal "%1G (second not hex)"  (pct-decode (a "%1G")) (a "%1G"))
        (check-equal "%A  (one digit, EOF)"  (pct-decode (a "%A"))  (a "%A"))
        (check-equal "trailing %"            (pct-decode (a "ab%")) (a "ab%"))
        (check-equal "% then more"           (pct-decode (a "%%41")) (a "%A"))))
    (harness-case "a literal % survives when it is not an escape"
      (lambda ()
        ;; "100% done" has a `%` followed by a space -- not a triple.
        (check-equal "100% done" (pct-decode (a "100% done")) (a "100% done"))))))

;;; --- pct-encode: encode by predicate, UPPERCASE hex out ---------------------
(harness-group "pct-encode"
  (lambda ()
    (harness-case "bytes failing safe? become %XX; safe bytes stay"
      (lambda ()
        (check-equal "space -> %20"
                     (pct-encode (a " ") unreserved-byte?) (a "%20"))
        (check-equal "/ -> %2F"
                     (pct-encode (a "/") unreserved-byte?) (a "%2F"))
        (check-equal "a stays a"
                     (pct-encode (a "a") unreserved-byte?) (a "a"))
        (check-equal "the four marks stay"
                     (pct-encode (a "-._~") unreserved-byte?) (a "-._~"))))
    (harness-case "hex is UPPERCASE even for bytes whose lowercase would differ"
      (lambda ()
        (check-equal "{ (0x7B) -> %7B"  (pct-encode (a "{") unreserved-byte?) (a "%7B"))
        (check-equal "0xFF -> %FF"      (pct-encode (bytes 255) unreserved-byte?) (a "%FF"))
        (check-equal "0xAB -> %AB"      (pct-encode (bytes 171) unreserved-byte?) (a "%AB"))
        (check-equal "0x0A -> %0A"      (pct-encode (bytes 10) unreserved-byte?) (a "%0A"))))
    (harness-case "a mixed string encodes only the unsafe bytes"
      (lambda ()
        (check-equal "a b/c -> a%20b%2Fc"
                     (pct-encode (a "a b/c") unreserved-byte?) (a "a%20b%2Fc"))))
    (harness-case "the predicate governs what is left alone"
      (lambda ()
        (check-equal "everything-safe leaves all bytes"
                     (pct-encode (a "a /?#") (lambda (b) #t)) (a "a /?#"))
        (check-equal "nothing-safe encodes even a letter"
                     (pct-encode (a "A") (lambda (b) #f)) (a "%41"))))
    (harness-case "empty in, empty out"
      (lambda ()
        (check-equal "empty" (pct-encode (a "") unreserved-byte?) (a ""))))))

;;; --- the round-trip property: decode inverts encode for ANY bytevector ------
;;; encode leaves unreserved bytes literal and turns every other byte into an
;;; uppercase %XX; decode turns every %XX back and leaves the rest. So over all
;;; 256 octets, decode . encode is the identity. This is a NECESSARY property,
;;; not a sufficient one -- it would still hold for a lowercase-emitting encoder
;;; (decode folds case) -- so the casing and which-bytes-are-escaped guarantees
;;; live in the pct-encode point cases above, and this only backstops that no
;;; octet is dropped, doubled or corrupted across the pair.
(harness-group "round-trip"
  (lambda ()
    (harness-case "decode . encode = identity over every octet 0..255"
      (lambda ()
        (let ((all (make-bytevector 256)))
          (let loop ((i 0)) (when (< i 256) (bytevector-u8-set! all i i) (loop (+ i 1))))
          (check-equal "all 256 bytes survive the round trip"
                       (pct-decode (pct-encode all unreserved-byte?)) all))))
    (harness-case "encode then decode preserves a URI-shaped byte string"
      (lambda ()
        (let ((s (a "a b/c?d=e&f#g %ZZ")))
          (check-equal "round trip" (pct-decode (pct-encode s unreserved-byte?)) s))))))

(harness-finish)
