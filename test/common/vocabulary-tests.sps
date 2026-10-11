#!r6rs
;;; unit.vocabulary -- the table three parties must agree on. Judged before any
;;; grammar node opens a span: this is names and integers, and the whole of what
;;; the grammar, the harness and an embedder import to agree on them.
(import (rnrs)
        (uri test harness)
        (uri vocabulary))

(harness-begin "unit.vocabulary")

(harness-group "modes"
  (lambda ()
    ;; The four names and their integers are the vocabulary table verbatim.
    (harness-case "the mode integers are 0..3 in the RFC's order"
      (lambda ()
        (check-equal "unset"         (uri-mode-value 'unset)         0)
        (check-equal "uri"           (uri-mode-value 'uri)           1)
        (check-equal "relative-ref"  (uri-mode-value 'relative-ref)  2)
        (check-equal "uri-reference" (uri-mode-value 'uri-reference) 3)))

    (harness-case "unset is 0, the refusing default"
      (lambda ()
        ;; A field initial cannot be made mandatory; 0 refuses rather than
        ;; permits. If unset ever stops being 0 the
        ;; grammar's `mode-unset` arm stops being reachable.
        (check-equal "unset value" (uri-mode-value 'unset) 0)))

    (harness-case "the field width holds every mode integer"
      (lambda ()
        (check-equal "width" uri-mode-width 8)
        (check "3 fits in width 8" (< 3 (expt 2 uri-mode-width)))))

    (harness-case "there are exactly four modes"
      (lambda ()
        (check-equal "names" uri-mode-names '(unset uri relative-ref uri-reference))))

    (harness-case "an unknown mode name is refused, not defaulted"
      (lambda ()
        (check-raises "no such mode" uri-vocabulary-error?
                      (lambda () (uri-mode-value 'whatwg)))))))

(harness-group "spans"
  (lambda ()
    (harness-case "six scanner spans, in vocabulary order"
      (lambda ()
        (check-equal "count" (length uri-span-names) 6)
        (check-equal "names" uri-span-names
                     '(scheme leading-token authority path query fragment))))

    (harness-case "authority is one coarse span; userinfo/host/port are the core's"
      (lambda ()
        ;; The scanner emits ONE authority
        ;; span, and userinfo/host/port are pure core functions over it, not
        ;; scanner spans.
        (check "authority is a span"    (uri-span-name? 'authority))
        (check "userinfo is not a span" (not (uri-span-name? 'userinfo)))
        (check "host is not a span"     (not (uri-span-name? 'host)))
        (check "port is not a span"     (not (uri-span-name? 'port)))))

    (harness-case "every span names both a data and a completion callback"
      (lambda ()
        ;; Both, and distinct, for all six.
        (for-each
         (lambda (span)
           (let ((d (uri-span-data-callback span))
                 (c (uri-span-complete-callback span)))
             (check (string-append (symbol->string span) " data is a symbol")
                    (symbol? d))
             (check (string-append (symbol->string span) " complete is a symbol")
                    (symbol? c))
             (check-not-equal (string-append (symbol->string span) " d/=c") d c)))
         uri-span-names)))

    (harness-case "the callback names follow the span (a spot check)"
      (lambda ()
        (check-equal "scheme data"     (uri-span-data-callback 'scheme) 'on-scheme-data)
        (check-equal "scheme complete" (uri-span-complete-callback 'scheme) 'on-scheme-complete)
        (check-equal "authority data"  (uri-span-data-callback 'authority) 'on-authority-data)
        (check-equal "path complete"   (uri-span-complete-callback 'path) 'on-path-complete)))

    (harness-case "an unknown span is refused"
      (lambda ()
        ;; `host` is a core concept, not a scanner span.
        (check-raises "no such span" uri-vocabulary-error?
                      (lambda () (uri-span-data-callback 'host)))))))

(harness-group "callbacks"
  (lambda ()
    (harness-case "the verdict events are events, named for the outcome"
      (lambda ()
        (check-equal "events" uri-event-callback-names
                     '(on-scheme-confirmed on-segment-confirmed on-rooted))))

    (harness-case "the full callback list is 6 spans x 2 plus 3 events"
      (lambda ()
        (check-equal "count" (length uri-callback-names) 15)))

    ;; The whole vocabulary, pinned by identity, not just by count and shape.
    ;; The grammar, the harness and an embedder all bind these exact names, so a
    ;; row mistyped to a self-consistent but wrong name (still a symbol, still
    ;; distinct, count still 15) is caught here.
    (harness-case "every callback name is the one the span dictates, in order"
      (lambda ()
        (check-equal "names" uri-callback-names
                     '(on-scheme-data        on-scheme-complete
                       on-leading-token-data on-leading-token-complete
                       on-authority-data     on-authority-complete
                       on-path-data          on-path-complete
                       on-query-data         on-query-complete
                       on-fragment-data      on-fragment-complete
                       on-scheme-confirmed   on-segment-confirmed
                       on-rooted))))

    (harness-case "no callback name is declared twice"
      (lambda ()
        (let loop ((cs uri-callback-names) (seen '()))
          (cond ((null? cs) (check "no duplicate callback" #t))
                ((memq (car cs) seen)
                 (check-fail "duplicate callback" (symbol->string (car cs))))
                (else (loop (cdr cs) (cons (car cs) seen)))))))

    (harness-case "every span callback and every event is in the full list"
      (lambda ()
        (for-each
         (lambda (span)
           (check (string-append (symbol->string span) " data listed")
                  (uri-callback-name? (uri-span-data-callback span)))
           (check (string-append (symbol->string span) " complete listed")
                  (uri-callback-name? (uri-span-complete-callback span))))
         uri-span-names)
        (check "scheme-confirmed listed"  (uri-callback-name? 'on-scheme-confirmed))
        (check "segment-confirmed listed" (uri-callback-name? 'on-segment-confirmed))
        (check "rooted listed"            (uri-callback-name? 'on-rooted))))))

(harness-group "errors"
  (lambda ()
    (harness-case "the scanner error set is exactly these four"
      (lambda ()
        ;; Order is not asserted -- membership is the API.
        (check-equal "count" (length uri-error-codes) 4)
        (for-each (lambda (code)
                    (check (string-append (symbol->string code) " present")
                           (uri-error-code? code)))
                  '(mode-unset scheme-required scheme-forbidden unexpected-eof))))

    ;; THE NEGATIVE ASSERTION. Charset codes and the host/authority codes
    ;; (the core's) must NOT be in the SCANNER set: a declared
    ;; error no reachable scanner path raises is a promise the scanner does not
    ;; keep. `invalid-ip-literal` is listed because it belongs to the core.
    (harness-case "no charset or host code is in the scanner set"
      (lambda ()
        (for-each
         (lambda (code)
           (check (string-append (symbol->string code) " is not a scanner code")
                  (not (uri-error-code? code))))
         '(invalid-pct-encoded invalid-scheme invalid-reg-name invalid-dec-octet
           invalid-ip-literal invalid-userinfo invalid-port))))

    (harness-case "the two non-production codes are present"
      (lambda ()
        ;; These two, and only these two, name no production.
        (check "mode-unset"     (uri-error-code? 'mode-unset))
        (check "unexpected-eof" (uri-error-code? 'unexpected-eof))))))

(harness-finish)
