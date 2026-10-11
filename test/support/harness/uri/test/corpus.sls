#!r6rs
;;; (uri test corpus): reading RFC 3986's own vectors, and comparing against
;;; them.
;;;
;;; The RFC's vectors are the anchor of the resolution layer. That puts THIS
;;; library on the critical path: a loader that is one row off makes every later
;;; comparison wrong, and the failure reads as a parser defect rather than as a
;;; reading defect. So it is judged on its own, by
;;; test/common/corpus-tests.sps, before any URI is parsed.
;;;
;;; THE FILES ARE DERIVED, NOT AUTHORED. cmake/UriCorpus.cmake extracts them
;;; from the vendored RFC text and a lane re-derives and compares. This library
;;; therefore does not tolerate a malformed row: a shape it does not recognise
;;; is a defect in the extractor, and guessing at it would hide that. The one
;;; AUTHORED file it reads, test/conformance/differential/adversarial.scm, is
;;; held to the same rule: a malformed row is refused, never skipped.
;;;
;;; PURE, except for the four `-load` procedures, which are the only thing
;;; here that touches a port. Everything else is a function over data, which is
;;; what lets the parsing and the comparing be tested with literals.
(library (uri test corpus)
  (export corpus-load-resolution corpus-parse-resolution
          resolution-base resolution-vectors resolution-ref
          rv? rv-id rv-section rv-reference rv-target
          corpus-load-dot-segments corpus-parse-dot-segments
          ds? ds-trace ds-step ds-output ds-input
          corpus-load-examples corpus-parse-examples
          corpus-load-adversarial corpus-parse-adversarial
          av? av-mode av-input av-expect av-note
          compare-target
          corpus-error? corpus-error-detail)
  (import (rnrs))

  (define-condition-type &corpus &error
    make-corpus-error corpus-error?
    (detail corpus-error-detail))

  ;; A shape this library does not recognise is an extractor defect. It raises
  ;; rather than skipping, because a skipped row leaves every count one short
  ;; and no lane says which row went missing.
  (define (refuse who detail)
    (raise (condition (make-corpus-error detail)
                      (make-who-condition who)
                      (make-message-condition detail))))

  ;; read-data : String -> (Listof Datum)
  ;; Every top-level datum in a corpus file, in order.
  (define (read-data path)
    (let ((p (open-file-input-port path
                                   (file-options)
                                   (buffer-mode block)
                                   (native-transcoder))))
      (let loop ((acc '()))
        (let ((d (get-datum p)))
          (if (eof-object? d)
              (begin (close-port p) (reverse acc))
              (loop (cons d acc)))))))

  ;; The datum tagged `tag`, or a refusal naming what was missing. A corpus
  ;; file with no `vectors` form is not an empty corpus.
  (define (tagged data tag who)
    (let loop ((ds data))
      (cond ((null? ds)
             (refuse who (string-append "no (" (symbol->string tag) " ...) form")))
            ((and (pair? (car ds)) (eq? (caar ds) tag)) (cdar ds))
            (else (loop (cdr ds))))))

  (define (string-or-refuse x who what)
    (unless (string? x) (refuse who (string-append what " is not a string")))
    x)

  ;; --- section 5.4: reference resolution ----------------------------------

  (define-record-type rv (fields id section reference target))

  ;; THE ID IS DERIVED, never written down twice: a corpus row and a ratchet
  ;; row must name the same vector, and the only way to keep two spellings in
  ;; agreement is to have one. `<section>/<reference>`; the empty reference of
  ;; section 5.4.1 is therefore the id "5.4.1/".
  (define (rv-make section reference target)
    (make-rv (string-append section "/" reference) section reference target))

  ;; corpus-parse-resolution : (Listof Datum) -> (Pair String (Listof Rv))
  (define (corpus-parse-resolution data)
    (let ((base (car (tagged data 'base 'corpus-parse-resolution)))
          (rows (tagged data 'vectors 'corpus-parse-resolution)))
      (cons (string-or-refuse base 'corpus-parse-resolution "base")
            (map (lambda (row)
                   (unless (and (list? row) (= (length row) 3))
                     (refuse 'corpus-parse-resolution
                             "a vector row is not (section reference target)"))
                   (rv-make
                    (string-or-refuse (car row) 'corpus-parse-resolution "section")
                    (string-or-refuse (cadr row) 'corpus-parse-resolution "reference")
                    (string-or-refuse (caddr row) 'corpus-parse-resolution "target")))
                 rows))))

  (define (corpus-load-resolution path) (corpus-parse-resolution (read-data path)))
  (define (resolution-base c) (car c))
  (define (resolution-vectors c) (cdr c))

  ;; resolution-ref : Resolution String -> (Option Rv)
  (define (resolution-ref c id)
    (let loop ((vs (resolution-vectors c)))
      (cond ((null? vs) #f)
            ((string=? (rv-id (car vs)) id) (car vs))
            (else (loop (cdr vs))))))

  ;; --- section 5.2.4: the worked dot-segment traces ------------------------

  (define-record-type ds (fields trace step output input))

  (define (corpus-parse-dot-segments data)
    (map (lambda (row)
           (unless (and (list? row) (= (length row) 4))
             (refuse 'corpus-parse-dot-segments
                     "a step row is not (trace step output input)"))
           (unless (and (integer? (car row)) (exact? (car row)))
             (refuse 'corpus-parse-dot-segments "trace is not an exact integer"))
           (make-ds (car row)
                    (string-or-refuse (cadr row) 'corpus-parse-dot-segments "step")
                    (string-or-refuse (caddr row) 'corpus-parse-dot-segments "output")
                    (string-or-refuse (cadddr row) 'corpus-parse-dot-segments "input")))
         (tagged data 'steps 'corpus-parse-dot-segments)))

  (define (corpus-load-dot-segments path)
    (corpus-parse-dot-segments (read-data path)))

  ;; --- section 1.1.2: example URIs ----------------------------------------
  ;;
  ;; These carry no expected decomposition. The RFC gives them as
  ;; illustrations, so the only thing a lane may assert over them is that they
  ;; parse, and the loader hands back bare strings so
  ;; there is no expectation to accidentally invent.
  (define (corpus-parse-examples data)
    (map (lambda (row)
           (unless (and (list? row) (= (length row) 2))
             (refuse 'corpus-parse-examples "an example row is not (section uri)"))
           (string-or-refuse (cadr row) 'corpus-parse-examples "uri"))
         (tagged data 'uris 'corpus-parse-examples)))

  (define (corpus-load-examples path) (corpus-parse-examples (read-data path)))

  ;; --- the authored adversarial corpus ------------------------------------
  ;;
  ;; Deep, structured inputs with their hand-read RFC 3986 verdicts. A row is
  ;; (mode input expect note): mode names a production, input is a string or a
  ;; bytevector, expect is `accept` or `reject`, and note says why.

  ;; av? : Any -> Boolean
  ;; av-mode : Av -> Symbol;  av-input : Av -> (U String Bytevector)
  ;; av-expect : Av -> Symbol;  av-note : Av -> String
  (define-record-type av (fields mode input expect note))

  ;; corpus-parse-adversarial : (Listof Datum) -> (Listof Av)
  (define (corpus-parse-adversarial data)
    (map (lambda (row)
           (unless (and (list? row) (= (length row) 4))
             (refuse 'corpus-parse-adversarial "a row is not (mode input expect note)"))
           (unless (memq (car row) '(uri relative-ref uri-reference))
             (refuse 'corpus-parse-adversarial "mode is not uri, relative-ref or uri-reference"))
           (unless (or (string? (cadr row)) (bytevector? (cadr row)))
             (refuse 'corpus-parse-adversarial "input is neither a string nor a bytevector"))
           (unless (memq (caddr row) '(accept reject))
             (refuse 'corpus-parse-adversarial "expect is neither accept nor reject"))
           (make-av (car row) (cadr row) (caddr row)
                    (string-or-refuse (cadddr row) 'corpus-parse-adversarial "note")))
         (tagged data 'cases 'corpus-parse-adversarial)))

  ;; corpus-load-adversarial : String -> (Listof Av)
  (define (corpus-load-adversarial path) (corpus-parse-adversarial (read-data path)))

  ;; --- the comparator ------------------------------------------------------
  ;;
  ;; compare-target : String String (Option String) -> (Option String)
  ;;
  ;; #f when they agree, a diagnostic naming all three when they do not. The
  ;; asymmetry is deliberate: a lane writes `(if (compare-target ...) fail ok)`,
  ;; so agreement must be the false value and there is no truthy "ok" to
  ;; mistake for a diagnostic.
  ;;
  ;; A #f ACTUAL IS NOT AN EMPTY ONE. The distinction between absent and empty
  ;; reaches even here: a resolver that
  ;; produced nothing at all and one that produced "" must not compare the same,
  ;; so the actual is tested for stringhood before it is compared.
  (define (compare-target id expected actual)
    (cond ((not (string? actual))
           (string-append id ": expected \"" expected "\" but there was no result"))
          ((string=? expected actual) #f)
          (else
           (string-append id ": expected \"" expected "\" but got \"" actual "\"")))))
