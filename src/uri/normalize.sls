#!r6rs
;;; (uri normalize): RFC 3986 §6.2.2 syntax-based normalization, over the
;;; five-field `uri-components` and the bytevectors inside it.
;;;
;;; This is the §6 POLICY. The percent MECHANICS live in `(uri percent)`, which
;;; this library imports for `hex-digit-value`, `nibble->hex-digit` and
;;; `unreserved-byte?` rather than re-deriving them -- so there is one definition
;;; of "which octet is unreserved" and one hex renderer, shared by the codec and
;;; the normalizer.
;;;
;;; WHAT v0.1 NORMALIZES (decision 0020):
;;;   §6.2.2.1a  the SCHEME, case-folded to lowercase (a hand-written ASCII fold,
;;;              decision 0010 -- never `(rnrs unicode)`, whose length-changing
;;;              Unicode fold would map KELVIN SIGN to `k`);
;;;   §6.2.2.1b  the two hex digits of every valid `%XX`, to uppercase;
;;;   §6.2.2.2   decode a `%XX` iff its octet is unreserved (§2.3), and only those.
;;;
;;; WHAT IT DOES NOT DO, and says so rather than faking it (decision 0020):
;;;   - HOST case. §6.2.2.1a lowercases the scheme AND the host, but the host is
;;;     not isolated inside the opaque `authority` bytevector until the host
;;;     grammar (M4/v0.2, decision 0019/0011). userinfo is case-SENSITIVE, so
;;;     lowercasing the whole authority would corrupt it; preserving authority
;;;     case is conservative and standards-compliant, and a test pins it so a
;;;     later "fix" without the host split reddens.
;;;   - §6.2.2.3/§5.2.4 dot-segment removal (M6), §6.2.3 scheme-based and §6.2.4
;;;     protocol-based normalization (scheme-/protocol-specific, out of scope).
;;;
;;; TOTAL. Like the codec, normalization never rejects (v0.1 is non-validating,
;;; decision 0011): a malformed `%XX` is left byte-for-byte. Pure R6RS.
(library (uri normalize)
  (export normalize-scheme pct-normalize normalize-components)
  (import (rnrs)
          (uri percent)
          (uri components))

  (define PERCENT 37)                       ; #\%
  (define UP-A 65) (define UP-Z 90)         ; #\A .. #\Z
  (define ASCII-CASE 32)                    ; #\a - #\A: the ASCII lower/upper gap

  ;; ascii-downcase : Bytevector -> Bytevector
  ;; The §6.2.2.1 ASCII case fold, `A`-`Z` -> `a`-`z`, byte by byte; every other
  ;; octet is copied unchanged. This is the whole of scheme normalization, and
  ;; is the same fold the host will use once M4 isolates it. Written by hand, over
  ;; bytes, so Unicode case folding is never reached (decision 0010). Returns a
  ;; fresh bytevector -- the input is never mutated.
  (define (ascii-downcase bv)
    (let* ((n (bytevector-length bv)) (out (make-bytevector n)))
      (let loop ((i 0))
        (if (fx<? i n)
            (let ((b (bytevector-u8-ref bv i)))
              (bytevector-u8-set! out i
                                  (if (and (fx>=? b UP-A) (fx<=? b UP-Z))
                                      (fx+ b ASCII-CASE) b))
              (loop (fx+ i 1)))
            out))))

  ;; normalize-scheme : Bytevector -> Bytevector
  ;; §6.2.2.1a for the scheme: fold to lowercase. The scheme production is
  ;; ASCII-only and carries no `pct-encoded`, so the fold is all there is.
  (define (normalize-scheme bv) (ascii-downcase bv))

  ;; pct-normalize : Bytevector -> Bytevector
  ;; §6.2.2.1b + §6.2.2.2 over one component's bytes: for each valid `%XX`, decode
  ;; it when its octet is unreserved (§2.3), otherwise keep it encoded but
  ;; re-render its hex UPPERCASE (parsing to the octet and back drops the input
  ;; casing). A malformed `%` is a literal byte, copied through -- total, like the
  ;; codec. Non-`%` bytes are copied verbatim.
  ;;
  ;; SINGLE PASS (RFC 3986 §2.4): a decoded octet is never re-scanned, so `%2541`
  ;; normalizes to `%2541` (%25 is `%`, reserved, kept). Note this DECODES the
  ;; marks, so `.` (%2E) becomes literal: `/a/%2E%2E/b` -> `/a/../b`. M5 does not
  ;; remove dot-segments but it CREATES them, which is why M6 resolves a
  ;; normalized path, never a raw one (decision 0020).
  (define (pct-normalize bv)
    (let ((n (bytevector-length bv)))
      (call-with-bytevector-output-port
       (lambda (out)
         (let loop ((i 0))
           (when (fx<? i n)
             (let ((b (bytevector-u8-ref bv i)))
               (if (fx=? b PERCENT)
                   (let* ((have2 (fx<? (fx+ i 2) n))
                          (hi (and have2 (hex-digit-value (bytevector-u8-ref bv (fx+ i 1)))))
                          (lo (and have2 (hex-digit-value (bytevector-u8-ref bv (fx+ i 2))))))
                     (if (and hi lo)
                         (let ((v (fx+ (fx* 16 hi) lo)))
                           (if (unreserved-byte? v)
                               (put-u8 out v)                 ; §6.2.2.2: decode
                               (begin                         ; §6.2.2.1b: keep, uppercase
                                 (put-u8 out PERCENT)
                                 (put-u8 out (nibble->hex-digit (fxdiv v 16)))
                                 (put-u8 out (nibble->hex-digit (fxmod v 16)))))
                           (loop (fx+ i 3)))
                         (begin (put-u8 out b) (loop (fx+ i 1)))))  ; malformed %
                   (begin (put-u8 out b) (loop (fx+ i 1)))))))))))

  ;; normalize-components : Components -> Components
  ;; Apply §6.2.2 per component, and no further (decision 0020): the scheme is
  ;; case-folded; authority, path, query and fragment are percent-normalized
  ;; (unreserved-decoding is charset-based and position-independent, so the whole
  ;; authority bytevector normalizes correctly across userinfo/host/port); the
  ;; authority case is left ALONE (host-case is M4/v0.2). An absent (`#f`) field
  ;; stays absent; an empty field stays empty. A fresh components is returned.
  (define (normalize-components c)
    (make-uri-components
     (let ((s (uri-components-scheme c)))    (and s (normalize-scheme s)))
     (let ((a (uri-components-authority c))) (and a (pct-normalize a)))
     (let ((p (uri-components-path c)))      (and p (pct-normalize p)))
     (let ((q (uri-components-query c)))     (and q (pct-normalize q)))
     (let ((f (uri-components-fragment c)))  (and f (pct-normalize f))))))
