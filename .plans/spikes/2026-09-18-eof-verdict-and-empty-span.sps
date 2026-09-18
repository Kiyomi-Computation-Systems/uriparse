#!r6rs
;;; Spike for .plans/2026-09-18-chez-uri-design.md §8 question 1, plus a witness
;;; for decision 0008 item 4.
;;;
;;; MACHINE A -- does `eof-target -> span-end -> callback -> finish` VERIFY, and
;;; does the verdict event actually fire when input ends on the leading token?
;;; Decision 0004's mode 3 depends on it.
;;;
;;; MACHINE B -- is an EMPTY span observable, and is an ABSENT one silent?
;;; Decision 0008 says presence is carried by whether the callbacks fire at all.
(import (rnrs)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(define (range lo hi)
  (let loop ((i hi) (acc '())) (if (< i lo) acc (loop (- i 1) (cons i acc)))))
(define ALPHA (append (range 65 90) (range 97 122)))
(define DIGIT (range 48 57))
(define COLON 58)
(define QUESTION 63)

(define (set-case bs target mode)
  (make-byte-case (make-byte-set-matcher bs) (make-edge target mode) #f))
(define (consume-all name eof-target)
  (make-byte-dispatch-node name '() (make-edge name 'advance) eof-target #f))

;;; ---------------------------------------------------------------- MACHINE A
;;;   start --ALPHA--> open-token -> scan
;;;   scan --':'-----> close-scheme -> say-scheme  -> rest
;;;   scan --other---> close-seg-b  -> say-seg-b   -> rest
;;;   scan --EOF-----> close-seg-e  -> say-seg-e   -> finish   <-- the question
;;;
;;; EVERY delimiter edge is `reexecute`. An `advance` would move the cursor past
;;; the delimiter before span-end emits [mark,cursor), putting the delimiter
;;; INSIDE the span. The first draft of this spike did exactly that and reported
;;; `foo:` as a 4-byte scheme.
(define machine-a
  (make-machine
   'eof-verdict 'start '()
   (list (make-callback-declaration 'on-token-data       'span-data     #f '() #f #f)
         (make-callback-declaration 'on-token-complete   'span-complete #f '() #f #f)
         (make-callback-declaration 'on-scheme-confirmed  'event        #f '() #f #f)
         (make-callback-declaration 'on-segment-confirmed 'event        #f '() #f #f))
   (list (make-span-declaration 'leading-token 'on-token-data 'on-token-complete #f))
   (list (make-error-declaration 'eof 'unexpected-eof "input ended early" #f)
         (make-error-declaration 'bad 'invalid-leading-byte "not ALPHA" #f))
   (list
    (make-byte-dispatch-node
     'start (list (set-case ALPHA 'open-token 'reexecute))
     (make-edge 'e-bad 'reexecute) #f #f)
    (make-span-start-node 'open-token 'leading-token 'scan #f)
    (make-byte-dispatch-node
     'scan
     (list (make-byte-case (make-exact-byte-matcher COLON)
                           (make-edge 'close-scheme 'reexecute) #f)
           (set-case (append ALPHA DIGIT) 'scan 'advance))
     (make-edge 'close-seg-b 'reexecute)
     'close-seg-e #f)
    (make-span-end-node 'close-scheme 'leading-token 'say-scheme #f)
    (make-callback-node 'say-scheme 'on-scheme-confirmed 'rest '() 'rest #f)
    (make-span-end-node 'close-seg-b 'leading-token 'say-seg-b #f)
    (make-callback-node 'say-seg-b 'on-segment-confirmed 'rest '() 'rest #f)
    (make-span-end-node 'close-seg-e 'leading-token 'say-seg-e #f)
    (make-callback-node 'say-seg-e 'on-segment-confirmed 'done '() 'done #f)
    (consume-all 'rest 'done)           ; stands in for the rest of the URI
    (make-finish-node 'done #f)
    (make-error-node 'e-bad 'bad #f))
   'eof #f))

;;; ---------------------------------------------------------------- MACHINE B
;;;   s0 --'?'--> open-q -> q-scan --EOF--> close-q -> finish   (present)
;;;   s0 --other-> plain --EOF------------------------> finish   (absent)
;;;   s0 --EOF---------------------------------------> finish   (absent)
(define machine-b
  (make-machine
   'empty-span 's0 '()
   (list (make-callback-declaration 'on-query-data     'span-data     #f '() #f #f)
         (make-callback-declaration 'on-query-complete 'span-complete #f '() #f #f))
   (list (make-span-declaration 'query 'on-query-data 'on-query-complete #f))
   (list (make-error-declaration 'eof 'unexpected-eof "input ended early" #f))
   (list
    (make-byte-dispatch-node
     's0 (list (make-byte-case (make-exact-byte-matcher QUESTION)
                               (make-edge 'open-q 'advance) #f))
     (make-edge 'plain 'reexecute) 'done #f)
    (consume-all 'plain 'done)
    (make-span-start-node 'open-q 'query 'q-scan #f)
    (consume-all 'q-scan 'close-q)
    (make-span-end-node 'close-q 'query 'done #f)
    (make-finish-node 'done #f))
   'eof #f))

;;; ------------------------------------------------------------------ harness
(define (show-verify label m)
  (let ((v (verify-machine m)))
    (display label) (display " verified?: ") (write (verification-ok? v)) (newline)
    (unless (verification-ok? v)
      (for-each (lambda (d)
                  (display "  ") (write (diagnostic-code d))
                  (display " @ ") (write (diagnostic-node d))
                  (display " -- ") (display (diagnostic-message d)) (newline))
                (verification-diagnostics v)))
    v))

(define (trace v names bytes finish?)
  (let* ((events '())
         (bind (lambda (n data?)
                 (list n (if data?
                             (lambda (p c bv from to)
                               (set! events (cons (list n from to) events))
                               callback-continue)
                             (lambda (p c)
                               (set! events (cons n events))
                               callback-continue)))))
         (p (make-parser (make-interpreted-machine v)
                         (map (lambda (row) (bind (car row) (cadr row))) names) #f))
         (bv (u8-list->bytevector bytes))
         (r1 (parser-feed! p bv 0 (bytevector-length bv)))
         (r2 (if finish? (parser-finish! p) r1)))
    (list (parser-result-status r2) (reverse events))))

(define (report label x) (display "  ") (display label) (display " => ") (write x) (newline))

(define a-names '((on-token-data #t) (on-token-complete #f)
                  (on-scheme-confirmed #f) (on-segment-confirmed #f)))
(define b-names '((on-query-data #t) (on-query-complete #f)))

(define va (show-verify "A (eof verdict)" machine-a))
(when (verification-ok? va)
  (report "\"foo:\"  feed only " (trace va a-names '(102 111 111 58) #f))
  (report "\"foo/\"  feed only " (trace va a-names '(102 111 111 47) #f))
  (report "\"foo\"   feed+finish" (trace va a-names '(102 111 111) #t))
  (report "\"f\"     feed+finish" (trace va a-names '(102) #t)))

(newline)
(define vb (show-verify "B (empty span)" machine-b))
(when (verification-ok? vb)
  (report "\"?\"     present+EMPTY " (trace vb b-names '(63) #t))
  (report "\"?a\"    present+bytes " (trace vb b-names '(63 97) #t))
  (report "\"a\"     ABSENT        " (trace vb b-names '(97) #t))
  (report "\"\"      ABSENT        " (trace vb b-names '() #t))
  ;; The same empty query, split across two feeds, with the span open at the
  ;; boundary -- decision 0008 item 5's case.
  (let* ((events '())
         (p (make-parser (make-interpreted-machine vb)
                         (list (list 'on-query-data
                                     (lambda (p c bv from to)
                                       (set! events (cons (list 'data from to) events))
                                       callback-continue))
                               (list 'on-query-complete
                                     (lambda (p c)
                                       (set! events (cons 'complete events))
                                       callback-continue)))
                         #f))
         (bv (u8-list->bytevector '(63))))
    (parser-feed! p bv 0 1)             ; "?" -- span opens, feed ends
    (parser-feed! p bv 1 1)             ; empty feed
    (let ((r (parser-finish! p)))
      (report "\"?\" split feeds   "
              (list (parser-result-status r) (reverse events))))))
