#!r6rs
;;; (uri vocabulary): the span, callback and error names, and the mode
;;; integers -- the table three parties must agree on before the first byte.
;;;
;;; THIS LIBRARY IS PURE AND DEPENDS ON NOTHING. Not on byte-machine, not on
;;; the generated scanner, not on the harness -- it is a table and the
;;; arithmetic over it, so the three consumers that must agree can import ONE
;;; source: the grammar declares the spans, callbacks and errors; the harness
;;; binds a callback per span per fixture; and an embedder writes the callback
;;; bindings and the `mode` field-initial. A pure table is also what an embedder
;;; can import without dragging the builder and verifier in behind it (design
;;; §5; the same argument chez-httparse's decision 0021 item 4 makes for
;;; `(httparse modes)`).
;;;
;;; The names here are declarations, not the grammar. A span named here is not
;;; opened until a grammar node opens it, and an error code named here is not a
;;; promise until a reachable path raises it (decision 0009 item 6). This table
;;; carries the M2 vocabulary: the eight spans in full (decision 0008 item 2 --
;;; spans cannot be refined later, so the whole vocabulary is declared at M2),
;;; and the split-only error set (decision 0009 item 6). Charset codes arrive
;;; with the charset lanes at M3 and are deliberately absent here.
(library (uri vocabulary)
  (export
    ;; modes (decision 0004)
    uri-mode-table uri-mode-names uri-mode-value uri-mode-width
    ;; spans and their callbacks (decision 0008)
    uri-span-names uri-span-name?
    uri-span-data-callback uri-span-complete-callback
    uri-event-callback-names uri-callback-names uri-callback-name?
    ;; errors (decision 0009)
    uri-error-codes uri-error-code?
    ;; refusal
    uri-vocabulary-error? uri-vocabulary-error-detail)
  (import (rnrs))

  (define-condition-type &uri-vocabulary &error
    make-uri-vocabulary-error uri-vocabulary-error?
    (detail uri-vocabulary-error-detail))

  ;; A NAME WITH NO ROW RAISES; there is no default. A mode silently read as 0,
  ;; or a span name quietly mapped to no callback, is the one failure a table of
  ;; agreed names cannot afford, because the grammar and the harness would then
  ;; disagree with nothing to say so.
  (define (refuse who detail)
    (raise (condition (make-uri-vocabulary-error detail)
                      (make-who-condition who)
                      (make-message-condition detail))))

  ;; --- modes (decision 0004) ----------------------------------------------
  ;;
  ;; The `mode` field is a settable uint of width 8, declared initial 0. 0 is
  ;; `unset` and refuses at offset 0 (decision 0004 item 2): a field initial
  ;; cannot be made mandatory, so the alternative to a refusing default is a
  ;; silently permissive one. The three usable modes select the RFC production
  ;; the caller has committed to.
  (define uri-mode-table
    '((unset         0)
      (uri           1)
      (relative-ref  2)
      (uri-reference 3)))

  (define uri-mode-names (map car uri-mode-table))

  ;; The width the `mode` field must be declared at. The grammar declares 8 and
  ;; a unit case checks it against this, so the two cannot drift.
  (define uri-mode-width 8)

  ;; uri-mode-value : Symbol -> Nat
  (define (uri-mode-value name)
    (let ((row (assq name uri-mode-table)))
      (unless row
        (refuse 'uri-mode-value
                (string-append "no URI parse mode named "
                               (symbol->string name))))
      (cadr row)))

  ;; --- spans and their callbacks (decision 0008) --------------------------
  ;;
  ;; Eight spans, all declared at M2. Each COMPONENT span declares BOTH a data
  ;; and a completion callback (decision 0008 item 5): the completion is the one
  ;; signal that arrives exactly once per present component, because an empty
  ;; final fragment is suppressed across a feed boundary. `leading-token` is the
  ;; mode-3 neutral span (decision 0004 item 4); it carries both callbacks like
  ;; any other span, and the verdict is a separate event.
  (define uri-span-callbacks
    '((scheme        on-scheme-data        on-scheme-complete)
      (leading-token on-leading-token-data on-leading-token-complete)
      (userinfo      on-userinfo-data      on-userinfo-complete)
      (host          on-host-data          on-host-complete)
      (port          on-port-data          on-port-complete)
      (path          on-path-data          on-path-complete)
      (query         on-query-data         on-query-complete)
      (fragment      on-fragment-data      on-fragment-complete)))

  (define uri-span-names (map car uri-span-callbacks))

  (define (uri-span-name? x) (and (assq x uri-span-callbacks) #t))

  (define (uri-span-row who name)
    (let ((row (assq name uri-span-callbacks)))
      (unless row
        (refuse who
                (string-append "no URI span named " (symbol->string name))))
      row))

  ;; uri-span-data-callback : Symbol -> Symbol
  (define (uri-span-data-callback name)
    (cadr (uri-span-row 'uri-span-data-callback name)))

  ;; uri-span-complete-callback : Symbol -> Symbol
  (define (uri-span-complete-callback name)
    (caddr (uri-span-row 'uri-span-complete-callback name)))

  ;; The zero-width verdict events. `on-scheme-confirmed` / `on-segment-confirmed`
  ;; mode 3 fires after `leading-token` closes (decision 0004 item 4);
  ;; `on-rooted` fires when a path-absolute reference's leading `/` was dropped
  ;; from the path span and must be restored (decision 0018). They are events,
  ;; not spans: each names what a token turned out to be and carries no bytes.
  (define uri-event-callback-names
    '(on-scheme-confirmed on-segment-confirmed on-rooted))

  ;; Every callback name the grammar declares and an embedder binds: each span's
  ;; data and completion callback, then the two verdict events. Derived from the
  ;; table so a span added above cannot be forgotten here.
  (define uri-callback-names
    (append (apply append
                   (map (lambda (row) (list (cadr row) (caddr row)))
                        uri-span-callbacks))
            uri-event-callback-names))

  (define (uri-callback-name? x) (and (memq x uri-callback-names) #t))

  ;; --- errors (decision 0009) ---------------------------------------------
  ;;
  ;; An error names the ABNF production that failed, in the RFC's own spelling
  ;; (decision 0009 item 1). Two name no production and are the only such codes
  ;; (item 5): `mode-unset` and `unexpected-eof`. This is the M2 split-only set
  ;; (item 6); the charset codes (`invalid-pct-encoded`, `invalid-scheme`, ...)
  ;; arrive at M3, not here -- a declared error no reachable path raises is a
  ;; promise the parser does not keep.
  (define uri-error-codes
    '(mode-unset          ; no mode was chosen (0004 item 2)
      scheme-required     ; mode 1 reached a delimiter with no `:`
      scheme-forbidden    ; mode 2 found a `:` in the first segment
      invalid-ip-literal  ; an unclosed `[` in the host
      unexpected-eof))    ; input ended inside an unsatisfiable production

  (define (uri-error-code? x) (and (memq x uri-error-codes) #t)))
