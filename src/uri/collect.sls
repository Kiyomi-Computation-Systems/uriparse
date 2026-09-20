#!r6rs
;;; (uri collect): the imperative shell (design §2). It feeds bytes to the
;;; generated scanner, copies the span fragments it reports -- copies, because
;;; byte-machine guarantees a delivered range only for the dynamic extent of the
;;; callback -- and assembles a `uri-components` value. It is the one library
;;; that allocates in proportion to its input, and it does so because its caller
;;; asked for the components.
;;;
;;; It reads the scanner's two out-of-band signals (decisions 0018, 0004):
;;;   - `on-rooted`: a path-absolute's leading `/` was dropped from the path span
;;;     and must be prepended.
;;;   - `on-scheme-confirmed` / `on-segment-confirmed` (mode 3): the leading token
;;;     was a scheme, or the first path segment. So the scheme is the leading
;;;     token, or the path is the leading token stitched onto the path span.
;;;
;;; The userinfo/host/port sub-split lives in the core over the `authority` field
;;; (decision 0019); it is not this library's job.
(library (uri collect)
  (export make-uri-collector uri-collect-feed! uri-collect-finish!
          uri-collector-reset!
          uri-parse
          uri-parse-result? uri-parse-ok? uri-parse-components
          uri-parse-error-code uri-parse-error-offset
          uri-parse-component-offset
          uri-parse-validate uri-parse-result-validate
          uri-parse-authority-form uri-parse-authority-form-validate
          uri-authority-form-error-codes uri-authority-form-error-code?)
  (import (rnrs)
          (byte-machine runtime)
          (generated uri-scanner)
          (uri components)
          (uri vocabulary)
          (uri charset)
          (uri host))

  (define-record-type uri-parse-result
    (fields (immutable ok? uri-parse-ok?)
            (immutable components uri-parse-components)
            (immutable error-code uri-parse-error-code)
            (immutable error-offset uri-parse-error-offset)
            ;; A component -> absolute-start-offset alist, holding only the
            ;; present components; #f on an error result. The shell's half of
            ;; decision 0024 item 3 (the offset seam), so a core validator's
            ;; component-relative index rebases to an absolute input offset.
            (immutable offsets uri-parse-offsets)))

  ;; uri-parse-component-offset : uri-parse-result Symbol -> (Option Nat)
  ;; The absolute byte offset at which a present component begins in the input,
  ;; or #f when the component is absent or the parse did not succeed.
  (define (uri-parse-component-offset r name)
    (let ((a (uri-parse-offsets r)))
      (and a (let ((cell (assq name a))) (and cell (cdr cell))))))

  ;; --- pure assembly ------------------------------------------------------

  (define (bv-concat bvs)
    (let* ((total (fold-left (lambda (n b) (+ n (bytevector-length b))) 0 bvs))
           (out (make-bytevector total)))
      (let loop ((bvs bvs) (off 0))
        (if (null? bvs)
            out
            (let ((len (bytevector-length (car bvs))))
              (bytevector-copy! (car bvs) 0 out off len)
              (loop (cdr bvs) (+ off len)))))))

  (define empty-bv (make-bytevector 0))
  (define slash-bv (u8-list->bytevector (list 47)))

  ;; A span's bytes, or #f when it never completed (absent). The fragments are
  ;; held newest-first, so they are reversed before joining.
  (define (span-bytes table present name)
    (and (memq name present)
         (bv-concat (reverse (hashtable-ref table name '())))))

  ;; path COMPONENT = [leading token, when it was the first segment]
  ;;               ++ ["/", when the path was rooted] ++ [the path span].
  ;; Path is always present, so the span is never #f; the guard is belt-only.
  (define (path-component lead path-span rooted? verdict)
    (bv-concat
     (list (if (eq? verdict 'segment) (or lead empty-bv) empty-bv)
           (if rooted? slash-bv empty-bv)
           (or path-span empty-bv))))

  (define (assemble table present rooted? verdict)
    (let ((scheme-span (span-bytes table present 'scheme))
          (lead        (span-bytes table present 'leading-token))
          (authority   (span-bytes table present 'authority))
          (path-span   (span-bytes table present 'path))
          (query       (span-bytes table present 'query))
          (fragment    (span-bytes table present 'fragment)))
      (make-uri-components
       (if (eq? verdict 'scheme) lead scheme-span)   ; scheme
       authority
       (path-component lead path-span rooted? verdict)
       query
       fragment)))

  ;; --- the offset seam (decision 0024 item 3) -----------------------------
  ;;
  ;; A component's absolute START offset, from the per-span offsets the shell
  ;; captured at each span's first fragment. It mirrors `assemble` exactly, so
  ;; the bytes and the offset of a component always agree on where it begins:
  ;;   - a mode-3 scheme/segment verdict rebases scheme/path onto the leading
  ;;     token's start (the token IS the scheme, or is stitched before the path);
  ;;   - a rooted path (decision 0018) begins one byte BEFORE the path span,
  ;;     where the dropped "/" was.
  ;; Absent components contribute no cell, so absent stays distinct from a
  ;; present-empty component whose (possibly empty) span still fired (0008).
  (define (span-offset offsets name) (hashtable-ref offsets name #f))

  (define (path-offset offsets rooted? verdict)
    (cond ((eq? verdict 'segment) (span-offset offsets 'leading-token))
          (rooted? (let ((s (span-offset offsets 'path))) (and s (- s 1))))
          (else (span-offset offsets 'path))))

  (define (offset-cell name off) (if off (list (cons name off)) '()))

  (define (assemble-offsets offsets present rooted? verdict)
    (append
     (offset-cell 'scheme (if (eq? verdict 'scheme)
                              (span-offset offsets 'leading-token)
                              (span-offset offsets 'scheme)))
     (offset-cell 'authority (span-offset offsets 'authority))
     (offset-cell 'path (path-offset offsets rooted? verdict))
     (offset-cell 'query (span-offset offsets 'query))
     (offset-cell 'fragment (span-offset offsets 'fragment))))

  ;; --- the shell ----------------------------------------------------------
  ;;
  ;; A collector is a closure over the parser and the accumulators; it responds
  ;; to `feed!` and `finish!`. Bytes may arrive in any number of feeds -- a span
  ;; that crosses a feed boundary delivers several fragments, which the
  ;; accumulator concatenates -- so the result is the same however the input is
  ;; chunked. `make-uri-collector` takes one of the vocabulary's mode names
  ;; (`uri`, `relative-ref`, `uri-reference`; `unset` refuses).

  (define (make-uri-collector mode-sym)
    (let ((table (make-eq-hashtable))
          (offsets (make-eq-hashtable))
          (present '())
          (rooted? #f)
          (verdict #f))
      (define (accumulate name)
        (lambda (parser context src from to)
          (let ((copy (make-bytevector (- to from))))
            (bytevector-copy! src from copy 0 (- to from))
            (hashtable-update! table name (lambda (fs) (cons copy fs)) '()))
          ;; The span's absolute start, captured at its FIRST fragment only:
          ;; the runtime commits `parser-stream-offset` (the fragment's END)
          ;; before the callback, so the start is that minus the fragment width.
          ;; Witnessed against known offsets in unit.collect (decision 0024 §3).
          (when (eq? (hashtable-ref offsets name 'unseen) 'unseen)
            (hashtable-set! offsets name (- (parser-stream-offset parser) (- to from))))
          callback-continue))
      (define (complete name)
        (lambda (parser context) (set! present (cons name present)) callback-continue))
      (define (event thunk)
        (lambda (parser context) (thunk) callback-continue))
      (define bindings
        (list (list 'on-scheme-data (accumulate 'scheme))
              (list 'on-scheme-complete (complete 'scheme))
              (list 'on-leading-token-data (accumulate 'leading-token))
              (list 'on-leading-token-complete (complete 'leading-token))
              (list 'on-authority-data (accumulate 'authority))
              (list 'on-authority-complete (complete 'authority))
              (list 'on-path-data (accumulate 'path))
              (list 'on-path-complete (complete 'path))
              (list 'on-query-data (accumulate 'query))
              (list 'on-query-complete (complete 'query))
              (list 'on-fragment-data (accumulate 'fragment))
              (list 'on-fragment-complete (complete 'fragment))
              (list 'on-rooted (event (lambda () (set! rooted? #t))))
              (list 'on-scheme-confirmed (event (lambda () (set! verdict 'scheme))))
              (list 'on-segment-confirmed (event (lambda () (set! verdict 'segment))))))
      (let ((parser (make-parser uri-scanner-machine bindings #f
                                 (list (cons 'mode (uri-mode-value mode-sym))))))
        (lambda (msg . args)
          (case msg
            ((feed!) (parser-feed! parser (car args) (cadr args) (caddr args)))
            ((finish!)
             (let* ((r (parser-finish! parser)) (err (parser-result-error r)))
               (if err
                   (make-uri-parse-result #f #f (parser-error-code err) (parser-error-offset err) #f)
                   (make-uri-parse-result #t (assemble table present rooted? verdict) #f #f
                                          (assemble-offsets offsets present rooted? verdict)))))
            ;; Return to the just-constructed state for REUSE (decision 0029): reset
            ;; the parser (which PRESERVES the embedder-chosen mode -- it restores the
            ;; merged field-initials, not the bare declared ones), and clear the span
            ;; table, the offset table and the verdict flags IN PLACE. Nothing is
            ;; reallocated.
            ((reset!)
             (parser-reset! parser)
             (hashtable-clear! table)
             (hashtable-clear! offsets)
             (set! present '())
             (set! rooted? #f)
             (set! verdict #f))
            (else (assertion-violation 'uri-collector "unknown message" msg)))))))

  ;; uri-collector-reset! : Collector -> unspecified
  ;; Return a collector to its just-constructed state so an embedder can REUSE one
  ;; collector across parses -- one per connection -- instead of allocating a parser
  ;; and two hashtables per request (issue #11, decision 0029). A reset-and-reparse
  ;; yields the same result as a fresh collector, and the embedder-chosen mode
  ;; survives (parser-reset! restores the merged field-initials). `uri-parse`'s
  ;; one-shot behaviour is unchanged.
  (define (uri-collector-reset! collector) (collector 'reset!))

  ;; uri-collect-feed! : Collector Bytevector Nat Nat -> feed-result
  (define (uri-collect-feed! collector bv start end) (collector 'feed! bv start end))
  ;; uri-collect-finish! : Collector -> uri-parse-result
  (define (uri-collect-finish! collector) (collector 'finish!))

  ;; uri-parse : Symbol Bytevector -> uri-parse-result   (the one-shot convenience)
  (define (uri-parse mode-sym bv)
    (let ((c (make-uri-collector mode-sym)))
      (uri-collect-feed! c bv 0 (bytevector-length bv))
      (uri-collect-finish! c)))

  ;; --- charset + host validation (M3 decision 0024, M4 decision 0025) ------
  ;;
  ;; component-bytes : Components Symbol -> (Option Bytevector)
  ;; The bytes of a validated component. `authority` joined the map at M4: its
  ;; interior (userinfo/host/port) is judged by (uri host), the others by
  ;; (uri charset).
  (define (component-bytes c name)
    (case name
      ((scheme)    (uri-components-scheme c))
      ((authority) (uri-components-authority c))
      ((path)      (uri-components-path c))
      ((query)     (uri-components-query c))
      ((fragment)  (uri-components-fragment c))))

  ;; validate-one : Symbol Bytevector -> (values (Option Symbol) (Option Nat))
  ;; The authority is judged by (uri host) over its whole span; the four coarse
  ;; components the core holds whole by (uri charset). Both return a
  ;; component-RELATIVE index the caller rebases to absolute.
  (define (validate-one name bytes)
    (if (eq? name 'authority)
        (validate-authority bytes)
        (validate-component name bytes)))

  ;; validate-result : uri-parse-result -> (Option uri-parse-result)
  ;; #f when every present component is valid; else a validation ERROR result
  ;; (ok? #f, the core code, the ABSOLUTE offset -- the component's start from the
  ;; offset seam plus the validator's relative index). Components are visited in
  ;; input order (scheme, authority, path, query, fragment), so the first error is
  ;; the leftmost; a validation error, like a structural one, does not assemble.
  (define (validate-result r)
    (let ((c (uri-parse-components r)))
      (let loop ((names '(scheme authority path query fragment)))
        (if (null? names)
            #f
            (let ((bytes (component-bytes c (car names))))
              (if (not bytes)
                  (loop (cdr names))
                  (let-values (((code index) (validate-one (car names) bytes)))
                    (if code
                        (make-uri-parse-result
                         #f #f code
                         (+ (uri-parse-component-offset r (car names)) index)
                         #f)
                        (loop (cdr names))))))))))

  ;; uri-parse-result-validate : uri-parse-result -> uri-parse-result
  ;; JUDGE an already-parsed result (issue #18, decision 0032). Returns the result
  ;; UNCHANGED -- the argument itself -- when it is not `ok?` (a structural error
  ;; passes straight through; its components are #f and are not re-judged) or when
  ;; every present component is valid; otherwise the validation ERROR result
  ;; `validate-result` produces. This is the post-parse half of `uri-parse-validate`,
  ;; lifted to a public seam so a REUSED collector (decision 0029) can be validated:
  ;; `(uri-parse-result-validate (uri-collect-finish! c))` gives the same audited
  ;; verdict (M3/M4, audited clean at 0028/0030) with no re-parse and no second
  ;; implementation. Validation is a pure function of the result -- its components
  ;; and its offset seam -- so a reused-collector result and a fresh `uri-parse`
  ;; result validate identically.
  (define (uri-parse-result-validate r)
    (if (uri-parse-ok? r)
        (or (validate-result r) r)
        r))

  ;; uri-parse-validate : Symbol Bytevector -> uri-parse-result
  ;; Parse leniently, then JUDGE the component charsets and the authority host
  ;; grammar (M3, M4). A structural error passes straight through; an otherwise-
  ;; valid split whose bytes the ABNF rejects becomes a validation error result.
  ;; `uri-parse` itself stays the lenient splitter M5/M6/M7 depend on (a malformed
  ;; "%" is content there, not an error). The judgement is `uri-parse-result-validate`
  ;; over a fresh one-shot parse (decision 0032).
  (define (uri-parse-validate mode-sym bv)
    (uri-parse-result-validate (uri-parse mode-sym bv)))

  ;; --- authority-form (RFC 9112 §3.2.3, decision 0026) ---------------------
  ;;
  ;; A CONNECT request-target is an AUTHORITY-FORM target -- `host:port`, with no
  ;; scheme and no "//". It has NO RFC 3986 production, so no mode (decision 0004)
  ;; parses it; but it reuses RFC 3986's own host/port -- it is "an authority in
  ;; isolation", NOT a separate machine -- so the reach is a SHELL SPLICE: prepend
  ;; "//", which opens an `authority` span in relative-ref mode, parse, and re-map the
  ;; offsets by -2. The LENIENT `uri-parse-authority-form` mirrors `uri-parse`; the
  ;; strict `uri-parse-authority-form-validate` holds the target to RFC 9112 §3.2.3
  ;; (no userinfo, a real port, a valid host).

  (define SLASH 47) (define AF-COLON 58) (define AF-AT 64) (define AF-LBRK 91)

  ;; The three RFC 9112 authority-form error codes (decision 0026 item 5), living with
  ;; the parser -- neither scanner codes ((uri vocabulary)) nor RFC 3986 host codes
  ;; ((uri host)). Each names the §3.2.3 rule it enforces (0009's spelling;
  ;; `port-required` / `userinfo-forbidden` echo the scanner's `scheme-required` /
  ;; `scheme-forbidden`).
  (define uri-authority-form-error-codes
    '(not-authority-form userinfo-forbidden port-required))
  (define (uri-authority-form-error-code? x)
    (and (memq x uri-authority-form-error-codes) #t))

  ;; splice "//" so relative-ref opens an authority over the whole input.
  (define (splice-slashes bv)
    (let* ((n (bytevector-length bv)) (out (make-bytevector (fx+ n 2))))
      (bytevector-u8-set! out 0 SLASH)
      (bytevector-u8-set! out 1 SLASH)
      (bytevector-copy! bv 0 out 2 n)
      out))

  ;; Re-map a spliced result back to the caller's coordinates: every captured offset
  ;; and the error-offset lose the 2 bytes "//" added. Safe because the authority
  ;; opens at spliced offset 2, so no offset is < 2 (decision 0026 item 3).
  (define (unsplice-result r)
    (if (uri-parse-ok? r)
        (make-uri-parse-result
         #t (uri-parse-components r) #f #f
         (map (lambda (cell) (cons (car cell) (fx- (cdr cell) 2)))
              (uri-parse-offsets r)))
        (make-uri-parse-result
         #f #f (uri-parse-error-code r) (fx- (uri-parse-error-offset r) 2) #f)))

  ;; A parsed authority carrying a path/query/fragment is not authority-form: the
  ;; input has bytes past the authority. Since the authority starts at offset 0 after
  ;; unsplicing, the first such byte IS the authority's length.
  (define (authority-form-trailing? c)
    (or (let ((p (uri-components-path c))) (and p (fx>? (bytevector-length p) 0)))
        (and (uri-components-query c) #t)
        (and (uri-components-fragment c) #t)))

  ;; uri-parse-authority-form : Bytevector -> uri-parse-result
  ;; The LENIENT structural parse of an RFC 9112 authority-form target: splice, parse
  ;; in relative-ref mode, unsplice the offsets, and reject only a trailing
  ;; path/query/fragment as `not-authority-form`. Charsets, a present userinfo, and a
  ;; missing port are NOT judged here -- exactly like `uri-parse`.
  (define (uri-parse-authority-form bv)
    (let ((r (unsplice-result (uri-parse 'relative-ref (splice-slashes bv)))))
      (if (uri-parse-ok? r)
          (let ((c (uri-parse-components r)))
            (if (authority-form-trailing? c)
                (make-uri-parse-result
                 #f #f 'not-authority-form
                 (bytevector-length (uri-components-authority c)) #f)
                r))
          r)))

  ;; A userinfo "@" delimits userinfo from the host ONLY when it precedes the host.
  ;; An IP-literal host opens "["; a "@" INSIDE "[...]" is literal bytes, not a
  ;; delimiter (RFC 3986 §3.2.2 -- "@" is in no IPv6address / IPvFuture). So a genuine
  ;; userinfo "@" is one before the first "[" (or with no "[" at all). Returns its
  ;; index, or #f. This is bracket-aware, unlike a bare first-"@" scan: `[a@b]:443`
  ;; (a MALFORMED literal, not userinfo) therefore has no userinfo and falls through
  ;; to validate-authority (→ invalid-userinfo, as M4 reports for http://[a@b]),
  ;; instead of a misleading userinfo-forbidden.
  (define (find-first auth b)
    (let ((n (bytevector-length auth)))
      (let loop ((i 0))
        (cond ((fx>=? i n) #f)
              ((fx=? (bytevector-u8-ref auth i) b) i)
              (else (loop (fx+ i 1)))))))
  (define (authority-userinfo-index auth)
    (let ((at (find-first auth AF-AT)) (lb (find-first auth AF-LBRK)))
      (and at (or (not lb) (fx<? at lb)) at)))

  ;; uri-parse-authority-form-validate : Bytevector -> uri-parse-result
  ;; The STRICT RFC 9112 §3.2.3 form: the lenient parse, then -- LEFTMOST-first --
  ;; `userinfo-forbidden` (authority-form has no userinfo), the RFC 3986 host grammar
  ;; (`validate-authority`), and `port-required` (authority-form requires a real
  ;; port -- an empty port `host:` is valid RFC 3986 but not RFC 9112). The authority
  ;; begins at offset 0, so `validate-authority`'s relative index IS the caller's
  ;; offset, and `authority-host-span` gives the host end for the port check
  ;; (decision 0026 item 4).
  (define (uri-parse-authority-form-validate bv)
    (let ((r (uri-parse-authority-form bv)))
      (if (not (uri-parse-ok? r))
          r                                     ; structural fault already leftmost
          (let* ((auth (uri-components-authority (uri-parse-components r)))
                 (uat (authority-userinfo-index auth)))
            (cond
              (uat                               ; a genuine userinfo "@" (before any "[")
               (make-uri-parse-result #f #f 'userinfo-forbidden uat #f))
              (else
               (let-values (((code index) (validate-authority auth)))
                 (cond
                   (code (make-uri-parse-result #f #f code index #f))
                   (else
                    (let-values (((hs he) (authority-host-span auth)))
                      (if (and (fx<? (fx+ he 1) (bytevector-length auth))
                               (fx=? (bytevector-u8-ref auth he) AF-COLON))
                          r
                          (make-uri-parse-result
                           #f #f 'port-required (bytevector-length auth) #f)))))))))))))
