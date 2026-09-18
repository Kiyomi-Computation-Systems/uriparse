#!r6rs
;;; unit.vocabulary -- the table three parties must agree on (decision 0008,
;;; 0004, 0009). Judged before any grammar node opens a span: this is names and
;;; integers, and the whole of what the grammar, the harness and an embedder
;;; import to agree on them.
(import (rnrs)
        (uri test harness)
        (uri vocabulary))

(harness-begin "unit.vocabulary")

(harness-group "modes"
  (lambda ()
    ;; The four names and their integers are decision 0004's table verbatim.
    (harness-case "the mode integers are 0..3 in the RFC's order"
      (lambda ()
        (check-equal "unset"         (uri-mode-value 'unset)         0)
        (check-equal "uri"           (uri-mode-value 'uri)           1)
        (check-equal "relative-ref"  (uri-mode-value 'relative-ref)  2)
        (check-equal "uri-reference" (uri-mode-value 'uri-reference) 3)))

    (harness-case "unset is 0, the refusing default"
      (lambda ()
        ;; A field initial cannot be made mandatory; 0 refuses rather than
        ;; permits (decision 0004 item 2). If unset ever stops being 0 the
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
    (harness-case "eight spans, all declared, in decision 0008's order"
      (lambda ()
        (check-equal "count" (length uri-span-names) 8)
        (check-equal "names" uri-span-names
                     '(scheme leading-token userinfo host port path query fragment))))

    (harness-case "there is no authority span"
      (lambda ()
        ;; Decision 0008 item 3: the presence of `host` is the presence of the
        ;; authority. An `authority` span would nest, which the verifier refuses.
        (check "authority is not a span" (not (uri-span-name? 'authority)))))

    (harness-case "every span names both a data and a completion callback"
      (lambda ()
        ;; Decision 0008 item 5. Both, and distinct, for all eight.
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
        (check-equal "host data"       (uri-span-data-callback 'host) 'on-host-data)
        (check-equal "path complete"   (uri-span-complete-callback 'path) 'on-path-complete)))

    (harness-case "an unknown span is refused"
      (lambda ()
        (check-raises "no such span" uri-vocabulary-error?
                      (lambda () (uri-span-data-callback 'authority)))))))

(harness-group "callbacks"
  (lambda ()
    (harness-case "the two verdict events are events, named for the outcome"
      (lambda ()
        (check-equal "events" uri-event-callback-names
                     '(on-scheme-confirmed on-segment-confirmed))))

    (harness-case "the full callback list is 8 spans x 2 plus 2 events"
      (lambda ()
        (check-equal "count" (length uri-callback-names) 18)))

    ;; The whole vocabulary, pinned by identity, not just by count and shape.
    ;; The grammar, the harness and an embedder all bind these exact names, so a
    ;; row mistyped to a self-consistent but wrong name (still a symbol, still
    ;; distinct, count still 18) is caught here.
    (harness-case "every callback name is the one the span dictates, in order"
      (lambda ()
        (check-equal "names" uri-callback-names
                     '(on-scheme-data        on-scheme-complete
                       on-leading-token-data on-leading-token-complete
                       on-userinfo-data      on-userinfo-complete
                       on-host-data          on-host-complete
                       on-port-data          on-port-complete
                       on-path-data          on-path-complete
                       on-query-data         on-query-complete
                       on-fragment-data      on-fragment-complete
                       on-scheme-confirmed   on-segment-confirmed))))

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
        (check "segment-confirmed listed" (uri-callback-name? 'on-segment-confirmed))))))

(harness-group "errors"
  (lambda ()
    (harness-case "the M2 split-only error set is exactly these five"
      (lambda ()
        ;; Decision 0009 item 6. Order is not asserted -- membership is the API.
        (check-equal "count" (length uri-error-codes) 5)
        (for-each (lambda (code)
                    (check (string-append (symbol->string code) " present")
                           (uri-error-code? code)))
                  '(mode-unset scheme-required scheme-forbidden
                    invalid-ip-literal unexpected-eof))))

    ;; THE NEGATIVE ASSERTION. Charset codes belong to M3 and must NOT be
    ;; declared at M2 (decision 0009 item 6, 0011): a declared error no
    ;; reachable path raises is a promise the parser does not keep. This case
    ;; reddens the day someone adds one early.
    (harness-case "no charset code is declared at M2"
      (lambda ()
        (for-each
         (lambda (code)
           (check (string-append (symbol->string code) " is not M2")
                  (not (uri-error-code? code))))
         '(invalid-pct-encoded invalid-scheme invalid-reg-name
           invalid-dec-octet invalid-userinfo invalid-port))))

    (harness-case "the two non-production codes are present"
      (lambda ()
        ;; Decision 0009 item 5: these two, and only these two, name no
        ;; production.
        (check "mode-unset"     (uri-error-code? 'mode-unset))
        (check "unexpected-eof" (uri-error-code? 'unexpected-eof))))))

(harness-finish)
