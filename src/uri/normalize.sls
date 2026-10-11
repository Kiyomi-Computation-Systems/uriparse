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
;;; WHAT IT NORMALIZES:
;;;   §6.2.2.1a  the SCHEME and the HOST, case-folded to lowercase (a hand-written
;;;              ASCII fold -- never `(rnrs unicode)`, whose
;;;              length-changing Unicode fold would map KELVIN SIGN to `k`);
;;;   §6.2.2.1b  the two hex digits of every valid `%XX`, to uppercase;
;;;   §6.2.2.2   decode a `%XX` iff its octet is unreserved (§2.3), and only those.
;;;
;;; The host is not the whole authority -- userinfo is case-SENSITIVE and port is
;;; digits -- so (uri host)'s `authority-host-span` isolates the host and the fold
;;; touches only its LITERAL bytes: a `%XX` triplet keeps its (uppercased, §6.2.2.1b)
;;; hex, so `%C3` does not become `%c3`. `User:S3cret@Example.COM` normalizes to
;;; `User:S3cret@example.com`, never `user:s3cret@example.com`.
;;;
;;; WHAT IT DOES NOT DO:
;;;   - §6.2.2.3/§5.2.4 dot-segment removal (that is `(uri path)`'s), §6.2.3
;;;     scheme-based and §6.2.4 protocol-based normalization (scheme-/protocol-
;;;     specific, out of scope).
;;;
;;; TOTAL. Like the codec, normalization never rejects (it does not
;;; validate): a malformed `%XX` is left byte-for-byte. Pure R6RS.
(library (uri normalize)
  (export normalize-scheme pct-normalize normalize-components)
  (import (rnrs)
          (uri percent)
          (uri components)
          (uri host))

  (define PERCENT 37)                       ; #\%
  (define UP-A 65) (define UP-Z 90)         ; #\A .. #\Z
  (define ASCII-CASE 32)                    ; #\a - #\A: the ASCII lower/upper gap

  ;; downcase-byte : Nat -> Nat.  `A`-`Z` -> `a`-`z`; every other octet unchanged.
  (define (downcase-byte b)
    (if (and (fx>=? b UP-A) (fx<=? b UP-Z)) (fx+ b ASCII-CASE) b))

  ;; ascii-downcase : Bytevector -> Bytevector
  ;; The §6.2.2.1 ASCII case fold, `A`-`Z` -> `a`-`z`, byte by byte; every other
  ;; octet is copied unchanged. This is the whole of scheme normalization (and the
  ;; per-byte core of the host fold below). Written by hand, over bytes, so Unicode
  ;; case folding is never reached. Returns a fresh bytevector --
  ;; the input is never mutated.
  (define (ascii-downcase bv)
    (let* ((n (bytevector-length bv)) (out (make-bytevector n)))
      (let loop ((i 0))
        (if (fx<? i n)
            (begin (bytevector-u8-set! out i (downcase-byte (bytevector-u8-ref bv i)))
                   (loop (fx+ i 1)))
            out))))

  ;; downcase-host : Bytevector -> Bytevector
  ;; §6.2.2.1a for the HOST only. Lowercase the host's
  ;; literal bytes, isolated by (uri host)'s `authority-host-span` so userinfo
  ;; (case-sensitive) and port (digits) are untouched. A `%XX` triplet inside the
  ;; host is SKIPPED -- pct-normalize has already uppercased its hex (§6.2.2.1b), so
  ;; case-folding it would undo that. Returns a fresh bytevector; a host with no
  ;; upper-case literal is returned byte-identical.
  (define (downcase-host bv)
    (let ((out (bytevector-copy bv)))
      (let-values (((hs he) (authority-host-span bv)))
        (let loop ((i hs))
          (cond ((fx>=? i he) out)
                ((fx=? (bytevector-u8-ref bv i) PERCENT) (loop (fx+ i 3))) ; keep %XX
                (else (bytevector-u8-set! out i (downcase-byte (bytevector-u8-ref bv i)))
                      (loop (fx+ i 1))))))))

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
  ;; SINGLE PASS (RFC 3986 §2.4): a decoded octet is never re-scanned, so
  ;; `%2541` normalizes to `%2541` (%25 is `%`, reserved, kept). Note this
  ;; DECODES the marks, so `.` (%2E) becomes literal: `/a/%2E%2E/b` ->
  ;; `/a/../b`. Normalization does not remove dot-segments but it CREATES them,
  ;; which is why resolution works on a normalized path, never a raw one.
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

  ;; normalize-authority : Bytevector -> Bytevector
  ;; §6.2.2.2/§6.2.2.1b percent-normalize the whole authority (unreserved-decoding
  ;; is charset-based and position-independent, so it is correct across
  ;; userinfo/host/port), THEN §6.2.2.1a case-fold the HOST alone. Percent first:
  ;; a reserved-decoding `%XX` (e.g. `%40` -> `@`) stays encoded, so the host span
  ;; is found on the same delimiters the split saw, never a synthesized one.
  (define (normalize-authority a) (downcase-host (pct-normalize a)))

  ;; normalize-components : Components -> Components
  ;; Apply §6.2.2 per component: the scheme is case-folded;
  ;; the authority is percent-normalized and its host case-folded; path, query and
  ;; fragment are percent-normalized. An absent (`#f`) field stays absent; an empty
  ;; field stays empty. A fresh components is returned.
  (define (normalize-components c)
    (make-uri-components
     (let ((s (uri-components-scheme c)))    (and s (normalize-scheme s)))
     (let ((a (uri-components-authority c))) (and a (normalize-authority a)))
     (let ((p (uri-components-path c)))      (and p (pct-normalize p)))
     (let ((q (uri-components-query c)))     (and q (pct-normalize q)))
     (let ((f (uri-components-fragment c)))  (and f (pct-normalize f))))))
