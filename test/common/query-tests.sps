#!r6rs
;;; unit.query -- (uri query): a query's key/value pairs, split before decoding.
;;;
;;; Three readings of one split, which must agree:
;;;   (a) a hand-derived vector table, each row written from the rules rather than
;;;       from a run. BOTH the product and the oracle must satisfy every row, so
;;;       the table also grades the oracle;
;;;   (b) the independent oracle, (uri test query-oracle), which shares no code
;;;       with the product;
;;;   (c) an exhaustive sweep over a small alphabet holding both separators, `+`,
;;;       `%`, and the hex digits that spell `%26` (`&`) and `%2B` (`+`),
;;;       comparing product and oracle on every word, for both readings.
;;;
;;; The sweep's bound is disclosed and asserted, never silently capped: its
;;; comparison count is checked equal to an independently computed total, and a
;;; `uri-harness: coverage ...` line names the alphabet, MAXLEN and the count on
;;; every run, pass or fail.
(import (rnrs)
        (uri test harness)
        (uri test query-oracle)
        (uri query))

;; expect : (Listof (Pairof (U String Bytevector) (U String Bytevector #f)))
;;          -> (Listof (Pairof Bytevector (Option Bytevector)))
;; A table row's expected pairs, written as text where the bytes are ASCII.
(define (expect pairs)
  (define (bytes x) (if (string? x) (string->utf8 x) x))
  (map (lambda (p) (cons (bytes (car p)) (and (cdr p) (bytes (cdr p))))) pairs))

;; Each row: (input query-pairs-expected) or (input query-expected form-expected).
;; A row without a form column reads the same both ways: it has no `+`.
(define VECTORS
  `(("q=1&r=2"      (("q" . "1") ("r" . "2")))
    ;; split before decode: an encoded `&` or `=` is content, not a separator
    ("q=a%26b&r=1"  (("q" . "a&b") ("r" . "1")))
    ("%26=%3D"      (("&" . "=")))
    ("a%3Db=c"      (("a=b" . "c")))
    ("a=%26&b"      (("a" . "&") ("b" . #f)))
    ;; a piece splits at its FIRST `=`
    ("a=b=c"        (("a" . "b=c")))
    ;; absent is not empty
    ("a"            (("a" . #f)))
    ("a="           (("a" . "")))
    ("="            (("" . "")))
    ("=x"           (("" . "x")))
    ;; empty pieces are skipped
    (""             ())
    ("&"            ())
    ("a&&b"         (("a" . #f) ("b" . #f)))
    ("&&a=1&"       (("a" . "1")))
    ;; order and duplicates are kept
    ("a=1&a=2"      (("a" . "1") ("a" . "2")))
    ("b=2&a=1"      (("b" . "2") ("a" . "1")))
    ;; `;` is not a separator
    ("a;b=c;d"      (("a;b" . "c;d")))
    ;; `+`: literal for query-pairs, a space for form-pairs, read BEFORE decoding
    ("a+b=c+d"      (("a+b" . "c+d"))  (("a b" . "c d")))
    ("+=+"          (("+" . "+"))      ((" " . " ")))
    ("x=%2B+y"      (("x" . "++y"))    (("x" . "+ y")))
    ("k=%2b"        (("k" . "+"))      (("k" . "+")))
    ;; total: any decoded octet is returned as bytes, and a malformed `%` is itself
    ("k=%C3%A9"     (("k" . ,(u8-list->bytevector (list #xC3 #xA9)))))
    ("k=%FF"        (("k" . ,(u8-list->bytevector (list #xFF)))))
    ("k=%zz&%"      (("k" . "%zz") ("%" . #f)))
    ("k=%2"         (("k" . "%2")))))

(define (row-input row) (car row))
(define (row-query row) (expect (cadr row)))
(define (row-form row) (expect (if (pair? (cddr row)) (caddr row) (cadr row))))

;; check-table : String (Bytevector -> pairs) (Row -> pairs) -> void
(define (check-table label split row-expected)
  (for-each
   (lambda (row)
     (check-equal (string-append label " \"" (row-input row) "\"")
                  (split (string->utf8 (row-input row)))
                  (row-expected row)))
   VECTORS))

(harness-begin "unit.query")

(harness-group "the hand-derived table"
  (lambda ()
    (harness-case "query-pairs satisfies every row"
      (lambda () (check-table "query-pairs" query-pairs row-query)))
    (harness-case "form-pairs satisfies every row"
      (lambda () (check-table "form-pairs" form-pairs row-form)))
    ;; The table also grades the oracle, so a mistake the oracle shares with the
    ;; product cannot hide behind their agreement in the sweep below.
    (harness-case "the oracle's query reading satisfies every row"
      (lambda () (check-table "oracle-query-pairs" oracle-query-pairs row-query)))
    (harness-case "the oracle's form reading satisfies every row"
      (lambda () (check-table "oracle-form-pairs" oracle-form-pairs row-form)))
    ;; The split must never write to the caller's bytes, however its pieces are
    ;; cut: form-pairs rewrites `+` on its own copy.
    (harness-case "neither reading modifies its argument"
      (lambda ()
        ;; "a+b" is one piece spanning the whole input: the case where a split
        ;; that handed over the caller's own bytes would expose them.
        (for-each
         (lambda (input)
           (for-each
            (lambda (split name)
              (let ((bv (string->utf8 input)))
                (split bv)
                (check-equal (string-append name " leaves \"" input "\" alone")
                             bv (string->utf8 input))))
            (list query-pairs form-pairs) (list "query-pairs" "form-pairs")))
         '("a+b=c+d" "a+b"))))))

;; --- the exhaustive sweep --------------------------------------------------
;;
;; Eight bytes: a letter, both separators, `+`, `%`, and `2`, `6`, `B` so that
;; `%26` and `%2B` occur in every position. `a`, `2`, `6` and `B` are all hex
;; digits, so malformed and well-formed triplets meet at every boundary.
(define ALPHABET (map char->integer (string->list "a=&+%26B")))
(define MAXLEN 7)
(define READINGS
  (list (list "query" query-pairs oracle-query-pairs)
        (list "form" form-pairs oracle-form-pairs)))

;; The comparisons a full sweep MUST make: one per reading per word of every
;; length 0..MAXLEN (the sum of |A|^k), derived apart from the loop so that the
;; loop's own tally can be asserted against it.
(define EXPECTED-COMPARISONS
  (* (length READINGS)
     (let loop ((k 0) (sum 0))
       (if (fx>? k MAXLEN) sum
           (loop (fx+ k 1) (+ sum (expt (length ALPHABET) k)))))))

;; Every length-`len` word over ALPHABET, in a shared buffer read synchronously.
(define (sweep-length len on-word)
  (let ((buf (make-bytevector len 0)))
    (let rec ((i 0))
      (if (fx=? i len)
          (on-word buf)
          (let aloop ((as ALPHABET))
            (unless (null? as)
              (bytevector-u8-set! buf i (car as))
              (rec (fx+ i 1))
              (aloop (cdr as))))))))

(harness-group "the exhaustive sweep: product and oracle agree"
  (lambda ()
    (harness-case "every length-0..MAXLEN word over the alphabet, both readings"
      (lambda ()
        (let ((compared 0) (disagreements '()))
          (do ((len 0 (fx+ len 1))) ((fx>? len MAXLEN))
            (sweep-length len
              (lambda (buf)
                (for-each
                 (lambda (reading)
                   (set! compared (fx+ compared 1))
                   (unless (equal? ((cadr reading) buf) ((caddr reading) buf))
                     (set! disagreements
                           (cons (string-append (car reading) " \"" (utf8->string buf) "\"")
                                 disagreements))))
                 READINGS))))
          (display (string-append
                    "uri-harness: coverage sweep=exhaustive alphabet="
                    (number->string (length ALPHABET))
                    " maxlen=" (number->string MAXLEN)
                    " readings=" (number->string (length READINGS))
                    " compared=" (number->string compared)
                    " disagreements=" (number->string (length disagreements))))
          (newline)
          (adapter-flush-output)
          (check-equal "the sweep compared the full length-0..MAXLEN space"
                       compared EXPECTED-COMPARISONS)
          (if (null? disagreements)
              (check "no product/oracle disagreement over the swept space" #t)
              ;; The first few name the inputs; the coverage line has the total.
              (let loop ((ds (reverse disagreements)) (k 0))
                (when (and (pair? ds) (fx<? k 10))
                  (check-fail "SWEEP DISAGREEMENT" (car ds))
                  (loop (cdr ds) (fx+ k 1))))))))))

(harness-finish)
