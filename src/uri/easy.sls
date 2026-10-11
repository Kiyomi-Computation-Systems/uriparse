#!r6rs
;;; (uri easy): URIs as strings in, a record out.
;;;
;;; The layer for programs that handle a URI as a value rather than on a request
;;; hot path. Every procedure composes exports of the libraries below it, and
;;; none of those imports this one. It allocates freely and validates on every
;;; parse; a server keeps (uri collect)'s reusable collector and the ranged
;;; judges.
;;;
;;; THE DOMAIN IS VALIDATED. A `uri` holds `uri-components` that passed
;;; `uri-parse-validate` in the mode that built it. RFC 3986 admits only ASCII,
;;; so every raw field is ASCII and `utf8->string` on one is exact.
;;;
;;; RAW, EXCEPT SCHEME AND HOST. Accessors return the text as written: the path
;;; keeps its `%20`, the userinfo its case. `uri-scheme` and `uri-host` return
;;; their §6.2.2 form (lowercase, unreserved `%XX` decoded): both are
;;; case-insensitive, and both are mostly read to be compared, where a raw
;;; `Example.COM` would not equal `example.com`. The record is never normalized.
;;;
;;; ABSENT IS NOT EMPTY: #f is absent, "" is present and empty. `uri-port` is the
;;; one exception: an empty port (`http://a:`) has no number, and reads #f.
;;;
;;; DECODING SPLITS FIRST AND IS STRICT UTF-8. Path segments and query pairs are
;;; split on their literal delimiters before percent-decoding. Decoded bytes are
;;; checked by hand against UTF-8's well-formedness table and raise
;;; `invalid-utf-8`; they never become U+FFFD, which would read `%FF` and `%FE`
;;; as the same string.
;;;
;;; ERRORS. Bad input raises `&uri-error`: a reason (one of `uri-error-reasons`),
;;; a CHARACTER offset into the input (the low layer counts bytes of UTF-8), and
;;; the input, with &who and &message. A wrong argument type is an assertion
;;; violation naming the public procedure.
(library (uri easy)
  (export
    ;; parsing
    string->uri string->uri-reference string->relative-ref uri-string? uri?
    ;; fields: raw, except scheme and host
    uri-scheme uri-authority uri-userinfo uri-host uri-port
    uri-path uri-query uri-fragment
    ;; decoded readings
    uri-path-segments uri-query-pairs uri-form-pairs uri-decode uri-encode
    ;; errors
    uri-error? uri-error-reason uri-error-offset uri-error-input uri-error-reasons)
  (import (rnrs)
          (only (uri components)
                make-uri-components
                uri-components-scheme uri-components-authority uri-components-path
                uri-components-query uri-components-fragment)
          (only (uri collect)
                uri-parse-validate uri-parse-ok? uri-parse-components
                uri-parse-error-code uri-parse-error-offset)
          (only (uri host) authority-host-span)
          (only (uri normalize) normalize-scheme normalize-components)
          (only (uri percent) pct-decode pct-encode unreserved-byte?)
          (only (uri query) query-pairs form-pairs))

  (define SLASH 47)                         ; #\/
  (define ZERO 48)                          ; #\0

  ;; --- the record and the condition ----------------------------------------

  ;; uri? : Any -> Boolean
  ;; Opaque: record inspection (`record?`, `record-rtd`) cannot see inside it, so
  ;; the validated component bytes are reachable only through this library.
  (define-record-type (uri make-uri uri?)
    (opaque #t)
    (fields (immutable components uri-parts)))

  ;; uri-error? : Any -> Boolean
  ;; uri-error-reason : UriError -> Symbol
  ;; uri-error-offset : UriError -> Nat
  ;;   Every reason carries one: the low layer reports an offset with every error
  ;;   result, and the easy layer's own reasons give theirs.
  ;; uri-error-input : UriError -> String
  (define-condition-type &uri-error &error
    make-uri-error uri-error?
    (reason uri-error-reason)
    (offset uri-error-offset)
    (input uri-error-input))

  ;; uri-error-reasons : (Listof Symbol)
  ;; Every reason a &uri-error can carry. Written out rather than derived from
  ;; the code lists below, so that a new low-layer code is a visible change
  ;; here, not one that arrives unannounced. (`mode-unset` cannot arise: every
  ;; parser picks its mode.)
  (define uri-error-reasons
    '(scheme-required scheme-forbidden unexpected-eof        ; the scanner
      invalid-scheme invalid-pchar invalid-query             ; (uri charset)
      invalid-fragment invalid-pct-encoded
      invalid-userinfo invalid-reg-name invalid-ip-literal   ; (uri host)
      invalid-dec-octet invalid-port
      invalid-utf-8))                                        ; decoding

  (define (raise-uri-error who reason offset input)
    (raise (condition (make-uri-error reason offset input)
                      (make-who-condition who)
                      (make-message-condition
                       (string-append (symbol->string reason) " at "
                                      (number->string offset))))))

  ;; --- bytes ----------------------------------------------------------------

  ;; slice : Bytevector Nat Nat -> Bytevector, a fresh copy of [s, e).
  (define (slice bv s e)
    (let ((out (make-bytevector (fx- e s))))
      (bytevector-copy! bv s out 0 (fx- e s))
      out))

  ;; find-byte : Bytevector Nat Nat Octet -> Nat, the first `b` in [s, e), or e.
  (define (find-byte bv s e b)
    (let loop ((i s))
      (cond ((fx=? i e) e)
            ((fx=? (bytevector-u8-ref bv i) b) i)
            (else (loop (fx+ i 1))))))

  ;; char-offset : Bytevector Nat -> Nat
  ;; The character index of byte `i` in UTF-8 `bv`: the bytes before it that
  ;; begin a character, which is every byte but a 10xxxxxx continuation. The low
  ;; layer's offsets always land on a character's first byte (an ASCII byte, or
  ;; the first non-ASCII byte, which no component admits).
  (define (char-offset bv i)
    (let loop ((j 0) (n 0))
      (if (fx=? j i)
          n
          (loop (fx+ j 1)
                (if (fx=? (fxand (bytevector-u8-ref bv j) #xC0) #x80) n (fx+ n 1))))))

  ;; --- parsing ----------------------------------------------------------------

  (define (check-string who s)
    (unless (string? s) (assertion-violation who "expected a string" s)))

  (define (parse who mode s)
    (check-string who s)
    (let* ((bv (string->utf8 s))
           (r (uri-parse-validate mode bv)))
      (if (uri-parse-ok? r)
          (make-uri (uri-parse-components r))
          (raise-uri-error who (uri-parse-error-code r)
                           (char-offset bv (uri-parse-error-offset r)) s))))

  ;; string->uri : String -> Uri
  ;; An absolute URI (RFC 3986 §3): a scheme is required.
  (define (string->uri s) (parse 'string->uri 'uri s))

  ;; string->uri-reference : String -> Uri
  ;; A URI or a relative reference (§4.1).
  (define (string->uri-reference s) (parse 'string->uri-reference 'uri-reference s))

  ;; string->relative-ref : String -> Uri
  ;; A relative reference only (§4.2): a scheme is refused.
  (define (string->relative-ref s) (parse 'string->relative-ref 'relative-ref s))

  ;; uri-string? : String [Mode] -> Boolean
  ;;   Mode = (U 'uri 'uri-reference 'relative-ref), by default 'uri
  ;; Whether the string parses and validates in the mode. Never raises a
  ;; &uri-error; an unknown mode is an assertion violation.
  (define uri-string?
    (case-lambda
      ((s) (uri-string? s 'uri))
      ((s mode)
       (check-string 'uri-string? s)
       (unless (memq mode '(uri uri-reference relative-ref))
         (assertion-violation 'uri-string? "unknown mode" mode))
       (uri-parse-ok? (uri-parse-validate mode (string->utf8 s))))))

  ;; --- fields -----------------------------------------------------------------

  (define (parts who u)
    (unless (uri? u) (assertion-violation who "expected a uri" u))
    (uri-parts u))

  (define (text bv) (and bv (utf8->string bv)))

  ;; uri-scheme : Uri -> (Option String)
  ;; Lowercase. #f for a relative reference.
  (define (uri-scheme u)
    (let ((s (uri-components-scheme (parts 'uri-scheme u))))
      (and s (utf8->string (normalize-scheme s)))))

  ;; uri-authority : Uri -> (Option String)
  ;; Raw `userinfo@host:port`. #f when there is no `//`; "" for `file:///x`.
  (define (uri-authority u) (text (uri-components-authority (parts 'uri-authority u))))

  ;; uri-userinfo : Uri -> (Option String)
  ;; Raw, case kept. #f when no `@` precedes the host; "" for `http://@a`.
  (define (uri-userinfo u)
    (let ((a (uri-components-authority (parts 'uri-userinfo u))))
      (and a
           (let-values (((hs he) (authority-host-span a)))
             (and (fx>? hs 0) (utf8->string (slice a 0 (fx- hs 1))))))))

  ;; uri-host : Uri -> (Option String)
  ;; Normalized: lowercase, unreserved `%XX` decoded, other triplets kept with
  ;; uppercase hex. An IP-literal keeps its brackets. #f with no authority.
  ;; The host is read from a normalized COPY of the authority alone; the record
  ;; stays raw, and the path, query and fragment are not touched.
  (define (uri-host u)
    (let ((raw (uri-components-authority (parts 'uri-host u))))
      (and raw
           (let ((a (uri-components-authority
                     (normalize-components
                      (make-uri-components #f raw (make-bytevector 0) #f #f)))))
             (let-values (((hs he) (authority-host-span a)))
               (utf8->string (slice a hs he)))))))

  ;; uri-port : Uri -> (Option Nat)
  ;; The port as a number: `080` is 80, and there is no range check (RFC 3986
  ;; has none). #f when there is no port, and when it is empty (`http://a:`).
  (define (uri-port u)
    (let ((a (uri-components-authority (parts 'uri-port u))))
      (and a
           (let-values (((hs he) (authority-host-span a)))
             ;; In a valid authority a byte after the host is the port's ":".
             (let ((n (bytevector-length a)))
               (and (fx<? (fx+ he 1) n)
                    (let loop ((i (fx+ he 1)) (port 0))
                      (if (fx=? i n)
                          port
                          (loop (fx+ i 1)
                                (+ (* port 10) (fx- (bytevector-u8-ref a i) ZERO)))))))))))

  ;; uri-path : Uri -> String
  ;; Raw. Always present; "" for `http://a`.
  (define (uri-path u) (utf8->string (uri-components-path (parts 'uri-path u))))

  ;; uri-query : Uri -> (Option String)
  ;; Raw. #f when there is no `?`; "" for `http://a?`.
  (define (uri-query u) (text (uri-components-query (parts 'uri-query u))))

  ;; uri-fragment : Uri -> (Option String)
  ;; Raw. #f when there is no `#`; "" for `http://a#`.
  (define (uri-fragment u) (text (uri-components-fragment (parts 'uri-fragment u))))

  ;; --- decoding -----------------------------------------------------------------

  ;; utf8-fault : Bytevector -> (Option Nat)
  ;; The index of the first byte that does not begin a well-formed UTF-8
  ;; sequence (the Unicode Standard's Table 3-7), or #f when all of `bv` is
  ;; UTF-8. Refuses overlongs, surrogates, code points above U+10FFFF, stray
  ;; continuation bytes and truncated sequences.
  (define (utf8-fault bv)
    (let ((n (bytevector-length bv)))
      (define (in? i lo hi)
        (and (fx<? i n) (fx<=? lo (bytevector-u8-ref bv i) hi)))
      (let loop ((i 0))
        (if (fx=? i n)
            #f
            (let ((b (bytevector-u8-ref bv i)))
              (cond
               ((fx<? b #x80) (loop (fx+ i 1)))
               ((fx<=? #xC2 b #xDF)
                (if (in? (fx+ i 1) #x80 #xBF) (loop (fx+ i 2)) i))
               ((fx<=? #xE0 b #xEF)
                (if (and (in? (fx+ i 1) (if (fx=? b #xE0) #xA0 #x80) (if (fx=? b #xED) #x9F #xBF))
                         (in? (fx+ i 2) #x80 #xBF))
                    (loop (fx+ i 3))
                    i))
               ((fx<=? #xF0 b #xF4)
                (if (and (in? (fx+ i 1) (if (fx=? b #xF0) #x90 #x80) (if (fx=? b #xF4) #x8F #xBF))
                         (in? (fx+ i 2) #x80 #xBF)
                         (in? (fx+ i 3) #x80 #xBF))
                    (loop (fx+ i 4))
                    i))
               (else i)))))))

  ;; triplet-at? : Bytevector Nat -> Boolean
  ;; Whether `pct-decode` reads the three bytes at `i` as one `%XX` triplet. It
  ;; asks pct-decode itself, over that window, rather than restating its rule:
  ;; only a triplet turns three bytes into one, so the offsets below cannot drift
  ;; from the decoder they describe.
  (define (triplet-at? raw i)
    (and (fx<=? (fx+ i 3) (bytevector-length raw))
         (fx=? (bytevector-length (pct-decode (slice raw i (fx+ i 3)))) 1)))

  ;; source-index : Bytevector Nat -> Nat
  ;; The index in `raw` of what `pct-decode` turned into decoded byte `d`. Walks
  ;; pct-decode's units, a triplet or a single byte, one decoded byte each. Only
  ;; an error offset needs it, so its window allocations are off the hot path.
  (define (source-index raw d)
    (let loop ((i 0) (k 0))
      (if (fx=? k d)
          i
          (loop (if (triplet-at? raw i) (fx+ i 3) (fx+ i 1)) (fx+ k 1)))))

  ;; decode-strictly : Symbol Bytevector String -> Bytevector
  ;; `raw` percent-decoded, raising invalid-utf-8 unless the result is UTF-8, at
  ;; the character index in `input` where the bad sequence begins. Splitting on
  ;; an ASCII delimiter can neither cut a well-formed sequence nor mend an
  ;; ill-formed one, so judging the whole text once judges every piece split
  ;; from it, and the offset is into the whole text.
  (define (decode-strictly who raw input)
    (let* ((decoded (pct-decode raw))
           (d (utf8-fault decoded)))
      (if d
          (raise-uri-error who 'invalid-utf-8 (char-offset raw (source-index raw d)) input)
          decoded)))

  ;; uri-decode : String -> String
  ;; Percent-decode, strictly: raises invalid-utf-8 rather than produce U+FFFD.
  ;; Total otherwise: a `%` without two hex digits is itself, and `+` is `+`.
  (define (uri-decode s)
    (check-string 'uri-decode s)
    (utf8->string (decode-strictly 'uri-decode (string->utf8 s) s)))

  ;; uri-encode : String -> String
  ;; Percent-encode every octet of the string's UTF-8 except §2.3 unreserved,
  ;; with uppercase hex. The result is safe in any component.
  (define (uri-encode s)
    (check-string 'uri-encode s)
    (utf8->string (pct-encode (string->utf8 s) unreserved-byte?)))

  ;; uri-path-segments : Uri -> (Listof String)
  ;; The path split on `/`, then each segment decoded. The one empty segment
  ;; before a leading `/` is dropped: "" is (), "/" is (""), "/a/b/" is
  ;; ("a" "b" ""), "a/b" is ("a" "b"). Raises invalid-utf-8, offset into the path.
  (define (uri-path-segments u)
    (let* ((p (uri-components-path (parts 'uri-path-segments u)))
           (n (bytevector-length p)))
      (decode-strictly 'uri-path-segments p (utf8->string p))
      (if (fx=? n 0)
          '()
          (let loop ((s (if (fx=? (bytevector-u8-ref p 0) SLASH) 1 0)) (acc '()))
            (let* ((e (find-byte p s n SLASH))
                   (acc (cons (utf8->string (pct-decode (slice p s e))) acc)))
              (if (fx=? e n) (reverse acc) (loop (fx+ e 1) acc)))))))

  (define (pairs who u split)
    (let ((q (uri-components-query (parts who u))))
      (if (not q)
          '()
          (begin
            (decode-strictly who q (utf8->string q))
            (map (lambda (p) (cons (utf8->string (car p)) (text (cdr p))))
                 (split q))))))

  ;; uri-query-pairs : Uri -> (Listof (Pairof String (Option String)))
  ;; The query's `key=value` pairs, split before decoding; `+` is literal. A key
  ;; with no `=` has the value #f. () when there is no query. Raises
  ;; invalid-utf-8, offset into the query.
  (define (uri-query-pairs u) (pairs 'uri-query-pairs u query-pairs))

  ;; uri-form-pairs : Uri -> (Listof (Pairof String (Option String)))
  ;; As uri-query-pairs, but `+` reads as a space (HTML form encoding).
  (define (uri-form-pairs u) (pairs 'uri-form-pairs u form-pairs)))
