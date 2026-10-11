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
;;; can import without dragging the builder and verifier in behind it.
;;;
;;; The names here are declarations, not the grammar. A span named here is not
;;; opened until a grammar node opens it, and an error code named here is not a
;;; promise until a reachable path raises it. This table
;;; is the SCANNER's vocabulary: the six coarse spans (the five RFC 3986
;;; components plus the mode-3 `leading-token`) and the four structural error
;;; codes. userinfo/host/port and the host/charset errors are the core's,
;;; not the scanner's, and live with the core.
(library (uri vocabulary)
  (export
    ;; modes
    uri-mode-table uri-mode-names uri-mode-value uri-mode-width
    ;; spans and their callbacks
    uri-span-names uri-span-name?
    uri-span-data-callback uri-span-complete-callback
    uri-event-callback-names uri-callback-names uri-callback-name?
    ;; errors
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

  ;; --- modes ---------------------------------------------------------------
  ;;
  ;; The `mode` field is a settable uint of width 8, declared initial 0. 0 is
  ;; `unset` and refuses at offset 0: a field initial
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

  ;; --- spans and their callbacks -------------------------------------------
  ;;
  ;; SIX scanner spans -- the FIVE coarse RFC 3986 components plus the mode-3
  ;; neutral `leading-token`. The functional-core line falls here:
  ;; the scanner splits the coarse components (essentially Appendix B), and
  ;; userinfo/host/port -- which the forward-only machine cannot split cleanly --
  ;; are pure CORE functions over the `authority` bytevector, not scanner spans.
  ;; So there IS an `authority` span; its presence carries
  ;; the authority's presence, empty for `http:///p`, absent for `http:/p`.
  ;;
  ;; Each span declares BOTH a data and a completion callback: the completion is
  ;; the one signal that arrives exactly once per present
  ;; component, because an empty final fragment is suppressed across a feed
  ;; boundary. `leading-token` is the mode-3 neutral span;
  ;; it carries both callbacks like any other span, and the verdict is an event.
  (define uri-span-callbacks
    '((scheme        on-scheme-data        on-scheme-complete)
      (leading-token on-leading-token-data on-leading-token-complete)
      (authority     on-authority-data     on-authority-complete)
      (path          on-path-data          on-path-complete)
      (query         on-query-data         on-query-complete)
      (fragment      on-fragment-data      on-fragment-complete)))

  (define uri-span-names (map car uri-span-callbacks))

  ;; uri-span-name? : Any -> Boolean
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

  ;; The zero-width verdict events. In mode 3, `on-scheme-confirmed` or
  ;; `on-segment-confirmed` fires after `leading-token` closes, saying whether the
  ;; token was a scheme or the first path segment. `on-rooted` fires when a
  ;; path-absolute reference's leading `/` was dropped from the path span and must
  ;; be restored. They are events, not spans: each names what a token turned out
  ;; to be and carries no bytes.
  (define uri-event-callback-names
    '(on-scheme-confirmed on-segment-confirmed on-rooted))

  ;; Every callback name the grammar declares and an embedder binds: each span's
  ;; data and completion callback, then the verdict events. Derived from the
  ;; table so a span added above cannot be forgotten here.
  (define uri-callback-names
    (append (apply append
                   (map (lambda (row) (list (cadr row) (caddr row)))
                        uri-span-callbacks))
            uri-event-callback-names))

  ;; uri-callback-name? : Any -> Boolean
  (define (uri-callback-name? x) (and (memq x uri-callback-names) #t))

  ;; --- errors --------------------------------------------------------------
  ;;
  ;; The SCANNER's error codes. An error names the ABNF production that failed,
  ;; in the RFC's own spelling; two name no production and
  ;; are the only such codes: `mode-unset` and `unexpected-eof`. Host and
  ;; charset errors (`invalid-ip-literal`, `invalid-dec-octet`,
  ;; `invalid-pct-encoded`, ...) are the CORE's, raised where the core validates
  ;; the authority and the charsets, and belong to a core
  ;; error vocabulary, not this one -- a declared error no reachable scanner path
  ;; raises is a promise the scanner does not keep.
  (define uri-error-codes
    '(mode-unset          ; no mode was chosen
      scheme-required     ; mode 1 reached a delimiter with no `:`
      scheme-forbidden    ; mode 2 found a `:` in the first segment
      unexpected-eof))    ; input ended inside an unsatisfiable production

  ;; uri-error-code? : Any -> Boolean
  (define (uri-error-code? x) (and (memq x uri-error-codes) #t)))
