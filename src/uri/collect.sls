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
          uri-parse
          uri-parse-result? uri-parse-ok? uri-parse-components
          uri-parse-error-code uri-parse-error-offset
          uri-parse-component-offset)
  (import (rnrs)
          (byte-machine runtime)
          (generated uri-scanner)
          (uri components)
          (uri vocabulary))

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
            (else (assertion-violation 'uri-collector "unknown message" msg)))))))

  ;; uri-collect-feed! : Collector Bytevector Nat Nat -> feed-result
  (define (uri-collect-feed! collector bv start end) (collector 'feed! bv start end))
  ;; uri-collect-finish! : Collector -> uri-parse-result
  (define (uri-collect-finish! collector) (collector 'finish!))

  ;; uri-parse : Symbol Bytevector -> uri-parse-result   (the one-shot convenience)
  (define (uri-parse mode-sym bv)
    (let ((c (make-uri-collector mode-sym)))
      (uri-collect-feed! c bv 0 (bytevector-length bv))
      (uri-collect-finish! c))))
