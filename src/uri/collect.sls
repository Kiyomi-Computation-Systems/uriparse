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
          uri-parse-error-code uri-parse-error-offset)
  (import (rnrs)
          (byte-machine runtime)
          (generated uri-scanner)
          (uri components)
          (uri vocabulary))

  (define-record-type uri-parse-result
    (fields (immutable ok? uri-parse-ok?)
            (immutable components uri-parse-components)
            (immutable error-code uri-parse-error-code)
            (immutable error-offset uri-parse-error-offset)))

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
          (present '())
          (rooted? #f)
          (verdict #f))
      (define (accumulate name)
        (lambda (parser context src from to)
          (let ((copy (make-bytevector (- to from))))
            (bytevector-copy! src from copy 0 (- to from))
            (hashtable-update! table name (lambda (fs) (cons copy fs)) '()))
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
                   (make-uri-parse-result #f #f (parser-error-code err) (parser-error-offset err))
                   (make-uri-parse-result #t (assemble table present rooted? verdict) #f #f))))
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
