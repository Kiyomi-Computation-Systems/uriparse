#!r6rs
;;; (uri test abnf-oracle): a WHOLE-URI recognizer of RFC 3986 Appendix A, read
;;; from the ABNF INDEPENDENTLY of the src `uri-parse-validate` it will grade, and
;;; composed from the two component oracles M3 and M4 already landed (the RFC 3986
;;; conformance audit, decision 0028, Slice ⓪).
;;;
;;; WHY A THIRD ORACLE, AND WHY WHOLE-URI. The charset oracle (M3) and the host
;;; oracle (M4) each read one LAYER of the ABNF -- the component charsets and the
;;; authority interior -- and each grades its own validator byte-for-byte. What
;;; neither reads is the STRUCTURAL grammar that ties the layers into a URI: the
;;; `scheme ":" hier-part` split, the five path-types and their per-context
;;; constraints, and the mode -> production mapping (`URI` / `relative-ref` /
;;; `URI-reference`). That structure is exactly where a lenient-split parser can
;;; diverge from the ABNF without any single component being wrong, so the audit
;;; needs an oracle that recognizes a WHOLE URI. This is that oracle: it adds ONLY
;;; the structural layer and defers every charset question to the two audited
;;; component oracles it composes (decision 0028 item 2).
;;;
;;; ORACLE DISCIPLINE (decisions 0003, 0005, 0012). This is a reference the product
;;; is graded against, so it is written from RFC 3986 Appendix A
;;; (test/conformance/rfc3986/rfc3986.abnf), NOT from `uri-parse-validate`. It is a
;;; second, deliberately naive recognizer of exactly the language the product must
;;; recognize; their agreement over a broad input space is the audit (Slice ①). In
;;; Slice ⓪ the oracle is graded on its OWN first -- against the positive corpora it
;;; must accept and a hand-built structural negative set it must reject -- the same
;;; way the corpus loader and the two component oracles were graded before any
;;; validator existed (decision 0005).
;;;
;;; THE RECOGNITION MODEL. RFC 3986's `query` and `fragment` contain no "#", and
;;; `query` no unescaped "?" delimiter beyond its own first one; `hier-part` /
;;; `relative-part` contain neither. So the greedy split of Appendix B -- fragment
;;; is everything after the first "#", query everything after the first "?" that
;;; precedes it -- is not a heuristic here but the ABNF's own unambiguous
;;; decomposition, and the front that remains is `scheme ":" hier-part` (a URI) or
;;; `relative-part` (a relative-ref). `scheme` admits no ":", so the scheme, when
;;; present, is exactly the run of scheme-chars up to the first ":".
;;;
;;; THE ONE STRUCTURAL FORK. `hier-part` and `relative-part` differ in exactly one
;;; alternative: the colon-bearing `path-rootless` (a URI's) versus the
;;; colon-FORBIDDEN `path-noscheme` (a relative-ref's). That single difference is
;;; the whole `URI` / `relative-ref` disambiguation: "g:h" is a `URI` (scheme "g",
;;; path-rootless "h"), is NOT a `relative-ref` (path-noscheme's first segment may
;;; not contain ":"), and so is a `URI-reference` only through the `URI` arm --
;;; precisely decision 0028's worked example.
;;;
;;; SCOPE. `URI` / `relative-ref` / `URI-reference` recognition per mode. RFC 9112
;;; authority-form (M9) is a different grammar and out of scope (decision 0026).
;;; Normalization (§6.2.2) and resolution (§5.4) are separately gated (M5/M6) and
;;; not re-litigated here (decision 0028 item 1).
;;;
;;; PURE: every procedure is a function over bytevectors; nothing touches a port.
(library (uri test abnf-oracle)
  (export
    ;; the recognizer: mode symbol + bytes -> boolean (accepts iff the bytes are a
    ;; URI / relative-ref / URI-reference per Appendix A, in that mode)
    oracle-recognize?
    ;; the same over a Scheme string's UTF-8 bytes, for ASCII test vectors
    oracle-recognize-string?
    abnf-oracle-error? abnf-oracle-error-detail)
  (import (rnrs)
          ;; ONLY the two component oracles' whole-component validators: the
          ;; structural layer here defers every charset question to them. `only`
          ;; because the two libraries share the ABNF byte-set names (oracle-alpha?
          ;; and friends), and importing both unqualified would collide.
          (only (uri test charset-oracle) oracle-scan)
          (only (uri test host-oracle) oracle-scan-authority))

  (define-condition-type &abnf-oracle &error
    make-abnf-oracle-error abnf-oracle-error?
    (detail abnf-oracle-error-detail))

  (define (refuse who detail)
    (raise (condition (make-abnf-oracle-error detail)
                      (make-who-condition who)
                      (make-message-condition detail))))

  ;; --- structural octets and small byte helpers ---------------------------
  (define SLASH 47) (define COLON 58) (define QUEST 63) (define HASH 35)

  (define (u8 bv i) (bytevector-u8-ref bv i))

  ;; first index of byte b in [s,e), or #f.
  (define (index-in bv s e b)
    (let loop ((i s))
      (cond ((fx>=? i e) #f)
            ((fx=? (u8 bv i) b) i)
            (else (loop (fx+ i 1))))))

  (define (index-of bv b) (index-in bv 0 (bytevector-length bv) b))

  (define (contains? bv s e b) (and (index-in bv s e b) #t))

  ;; the sub-bytevector [s,e). The oracle slices freely: this is a reference
  ;; recognizer read for clarity, not the product's hot path.
  (define (sub bv s e)
    (let ((out (make-bytevector (fx- e s))))
      (let loop ((i s) (j 0))
        (if (fx>=? i e) out
            (begin (bytevector-u8-set! out j (u8 bv i))
                   (loop (fx+ i 1) (fx+ j 1)))))))

  ;; --- the composed component oracles --------------------------------------
  ;;
  ;; charset-ok? defers a component's charset (and, for scheme, the leading-ALPHA
  ;; and non-empty rules) to M3's oracle; authority-ok? defers the whole authority
  ;; interior to M4's. "Valid" is simply "the component oracle raises no code".
  (define (charset-ok? component bv)
    (let-values (((code idx) (oracle-scan component bv)))
      (not code)))

  (define (authority-ok? bv)
    (let-values (((code idx) (oracle-scan-authority bv)))
      (not code)))

  ;; --- the five path-types (RFC 3986 §3.3) ---------------------------------
  ;;
  ;; Each takes the WHOLE path byte-range and answers whether it is that type. The
  ;; charset (pchar / "/" / pct-encoded) is M3's `path` component; these add the
  ;; STRUCTURAL rules the ABNF states over that charset: emptiness, the leading
  ;; byte, the "not //" rule, and path-noscheme's first-segment-no-colon.
  (define (all-path-chars? bv) (charset-ok? 'path bv))

  (define (path-empty? bv) (fx=? (bytevector-length bv) 0))

  ;; path-abempty = *( "/" segment ): empty, or begins with "/" and is otherwise
  ;; all pchar / "/". (segment = *pchar, so any "/"-led run of path chars parses.)
  (define (path-abempty? bv)
    (or (path-empty? bv)
        (and (fx=? (u8 bv 0) SLASH) (all-path-chars? bv))))

  ;; path-absolute = "/" [ segment-nz *( "/" segment ) ]: begins with "/", and the
  ;; byte after it (if any) is NOT "/" -- the "begins with / but not //" rule.
  (define (path-absolute? bv)
    (let ((n (bytevector-length bv)))
      (and (fx>? n 0)
           (fx=? (u8 bv 0) SLASH)
           (or (fx=? n 1) (not (fx=? (u8 bv 1) SLASH)))
           (all-path-chars? bv))))

  ;; path-rootless = segment-nz *( "/" segment ): non-empty, does not begin with
  ;; "/", all pchar / "/". Colons are allowed anywhere (segment/segment-nz = *pchar).
  (define (path-rootless? bv)
    (let ((n (bytevector-length bv)))
      (and (fx>? n 0)
           (not (fx=? (u8 bv 0) SLASH))
           (all-path-chars? bv))))

  ;; path-noscheme = segment-nz-nc *( "/" segment ): like path-rootless, but the
  ;; FIRST segment (up to the first "/", or the end) is segment-nz-nc, which admits
  ;; no ":". A pct-encoded ":" ("%3A") is not a literal colon and stays legal.
  (define (path-noscheme? bv)
    (let ((n (bytevector-length bv)))
      (and (fx>? n 0)
           (not (fx=? (u8 bv 0) SLASH))
           (all-path-chars? bv)
           (let ((seg-end (or (index-of bv SLASH) n)))
             (not (contains? bv 0 seg-end COLON))))))

  ;; --- hier-part (URI) and relative-part (relative-ref) --------------------
  ;;
  ;; The two share every alternative but the last; `part?` takes the rootless-arm
  ;; predicate that distinguishes them. A leading "//" is unambiguously the
  ;; authority alternative in both (path-absolute cannot produce "//"), so it is
  ;; matched first; then a single leading "/" is path-absolute; then empty is
  ;; path-empty; else the rootless arm (path-rootless for a URI, path-noscheme for
  ;; a relative-ref).
  (define (part? bv rootless-arm?)
    (let ((n (bytevector-length bv)))
      (cond
        ((fx=? n 0) #t)                                   ; path-empty
        ((and (fx>=? n 2) (fx=? (u8 bv 0) SLASH) (fx=? (u8 bv 1) SLASH))
         ;; "//" authority path-abempty. The authority runs to the first "/"
         ;; (or the end); userinfo/host/port admit no "/", so this split is exact.
         (let* ((m (fx- n 2))
                (rest (sub bv 2 n))
                (slash (index-of rest SLASH))
                (aend (or slash m)))
           (and (authority-ok? (sub rest 0 aend))
                (path-abempty? (sub rest aend m)))))
        ((fx=? (u8 bv 0) SLASH) (path-absolute? bv))
        (else (rootless-arm? bv)))))

  (define (hier-part? bv) (part? bv path-rootless?))
  (define (relative-part? bv) (part? bv path-noscheme?))

  ;; --- the front: scheme ":" hier-part, or relative-part -------------------
  ;;
  ;; scheme-hier? is the URI front. The scheme is the run up to the first ":";
  ;; `oracle-scan 'scheme` enforces its non-emptiness, its leading ALPHA, and its
  ;; charset, so a colon whose prefix is not a valid scheme (or an absent colon)
  ;; means "not a URI".
  (define (scheme-hier? front)
    (let* ((n (bytevector-length front))
           (colon (index-of front COLON)))
      (and colon
           (charset-ok? 'scheme (sub front 0 colon))
           (hier-part? (sub front (fx+ colon 1) n)))))

  (define (relative-front? front) (relative-part? front))

  ;; --- the recognizer ------------------------------------------------------
  ;;
  ;; recognize peels [ "#" fragment ] then [ "?" query ] (validating each against
  ;; its M3 charset), then applies the front predicate to what remains.
  (define (recognize bv front?)
    (let* ((n (bytevector-length bv))
           (hash (index-of bv HASH)))
      (let-values (((before-hash frag-ok?)
                    (if hash
                        (values (sub bv 0 hash)
                                (charset-ok? 'fragment (sub bv (fx+ hash 1) n)))
                        (values bv #t))))
        (and frag-ok?
             (let* ((m (bytevector-length before-hash))
                    (quest (index-of before-hash QUEST)))
               (let-values (((front query-ok?)
                             (if quest
                                 (values (sub before-hash 0 quest)
                                         (charset-ok? 'query
                                                      (sub before-hash (fx+ quest 1) m)))
                                 (values before-hash #t))))
                 (and query-ok? (front? front))))))))

  (define (recognize-uri? bv) (recognize bv scheme-hier?))
  (define (recognize-relative-ref? bv) (recognize bv relative-front?))
  (define (recognize-uri-reference? bv)
    (or (recognize-uri? bv) (recognize-relative-ref? bv)))

  ;; oracle-recognize? : Symbol Bytevector -> Boolean
  (define (oracle-recognize? mode bv)
    (case mode
      ((uri) (recognize-uri? bv))
      ((relative-ref) (recognize-relative-ref? bv))
      ((uri-reference) (recognize-uri-reference? bv))
      (else (refuse 'oracle-recognize?
                    (string-append "unknown mode " (symbol->string mode))))))

  (define (oracle-recognize-string? mode s)
    (oracle-recognize? mode (string->utf8 s))))
