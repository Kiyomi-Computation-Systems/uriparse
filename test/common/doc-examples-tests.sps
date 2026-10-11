#!r6rs
;;; example.docs -- every Scheme example in the user-facing docs runs, and prints
;;; what the doc says it prints.
;;;
;;; An org file's `#+begin_src scheme` blocks are of two kinds:
;;;   - a PROGRAM, whose first form is `(import ...)`. Its body is evaluated in
;;;     the environment its import names, with `display`, `write` and `newline`
;;;     captured, and what it prints must equal the first `#+begin_example`
;;;     block after it, before the next Scheme block;
;;;   - EXPRESSIONS, each followed by a `;; => value` line. Each is evaluated in
;;;     (rnrs) and (uri easy), and its result must be `equal?` to the value read.
;;; A block in another language (`#+begin_src sh`) is not an example.
;;;
;;; The files are URI_DOC_FILES (space-separated, relative to URI_DOC_ROOT). A
;;; listed file with no example is a failure: a check over nothing would pass
;;; whatever the doc said. The checker is graded first, on inline docs whose
;;; verdicts are known, so one that always agrees reddens before it is trusted.
(import (rnrs)
        (rnrs eval)
        (uri test harness)
        ;; Loaded, nothing bound: every library a documented program imports must
        ;; be in the running image, so `environment` finds it in the compiled lane
        ;; as well as from source.
        (only (uri easy))
        (only (uri collect))
        (only (uri components)))

;; --- text ----------------------------------------------------------------------

(define (read-file path)
  (let ((s (call-with-port
            (open-file-input-port path (file-options) (buffer-mode block)
                                  (make-transcoder (utf-8-codec)))
            get-string-all)))
    (if (eof-object? s) "" s)))

(define (split-lines s)
  (let loop ((i 0) (start 0) (acc '()))
    (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
          ((char=? (string-ref s i) #\newline)
           (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
          (else (loop (+ i 1) start acc)))))

(define (split-words s)
  (filter (lambda (w) (> (string-length w) 0))
          (let loop ((i 0) (start 0) (acc '()))
            (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
                  ((char=? (string-ref s i) #\space)
                   (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
                  (else (loop (+ i 1) start acc))))))

(define (prefix? p s)
  (and (<= (string-length p) (string-length s))
       (string=? p (substring s 0 (string-length p)))))

;; Org keywords are case-insensitive.
(define (keyword? kw line) (prefix? kw (string-downcase line)))

(define (join-lines lines)
  (apply string-append (map (lambda (l) (string-append l "\n")) lines)))

(define (read-all text)
  (let ((p (open-string-input-port text)))
    (let loop ((acc '()))
      (let ((d (get-datum p)))
        (if (eof-object? d) (reverse acc) (loop (cons d acc)))))))

(define (describe c)
  (cond ((and (message-condition? c) (irritants-condition? c))
         (call-with-string-output-port
          (lambda (p) (display (condition-message c) p) (display " " p)
                  (write (condition-irritants c) p))))
        ((message-condition? c) (condition-message c))
        (else (call-with-string-output-port (lambda (p) (write c p))))))

;; --- blocks ----------------------------------------------------------------------
;;
;; org-blocks : (Listof String) -> (values (Listof Block) (Listof String))
;; Block = (kind line text): kind is 'scheme, 'example or 'other; line is where
;; the block opens (1-based); text is its body. The second value lists problems,
;; such as a block that never closes.
(define (org-blocks lines)
  (let loop ((ls lines) (n 1) (blocks '()) (problems '()))
    (cond
     ((null? ls) (values (reverse blocks) (reverse problems)))
     ((or (keyword? "#+begin_src" (car ls)) (keyword? "#+begin_example" (car ls)))
      (let* ((src? (keyword? "#+begin_src" (car ls)))
             (words (split-words (car ls)))
             (kind (cond ((not src?) 'example)
                         ((and (pair? (cdr words)) (string=? (cadr words) "scheme")) 'scheme)
                         (else 'other)))
             (end (if src? "#+end_src" "#+end_example")))
        (let body ((bs (cdr ls)) (m (+ n 1)) (acc '()))
          (cond ((null? bs)
                 (loop '() m blocks
                       (cons (string-append "line " (number->string n) ": a block that never closes")
                             problems)))
                ((keyword? end (car bs))
                 (loop (cdr bs) (+ m 1)
                       (cons (list kind n (join-lines (reverse acc))) blocks) problems))
                (else (body (cdr bs) (+ m 1) (cons (car bs) acc)))))))
     (else (loop (cdr ls) (+ n 1) blocks problems)))))

;; --- running examples ------------------------------------------------------------

;; run-program : String -> String
;; Evaluate a program's body in the environment its import names, and return
;; what it printed through display, write and newline.
(define (run-program text)
  (let ((forms (read-all text)))
    (unless (and (pair? forms) (pair? (car forms)) (eq? (caar forms) 'import))
      (error 'run-program "a program does not begin with (import ...)"))
    (let ((env (apply environment
                      '(only (rnrs base) lambda let)
                      '(only (rnrs io simple) display write newline)
                      (cdar forms)))
          (wrapper `(lambda (%out)
                      (let ((display (lambda (x) (display x %out)))
                            (write (lambda (x) (write x %out)))
                            (newline (lambda () (newline %out))))
                        (let () ,@(cdr forms))))))
      (call-with-string-output-port
       (lambda (port) ((eval wrapper env) port))))))

;; expression-pairs : String -> (values (Listof (Pair String String)) (Listof String))
;; Each expression's text with the text of the `;; =>` value after it, and the
;; problems: an expression left with no value line.
(define (expression-pairs text)
  (let loop ((ls (split-lines text)) (expr '()) (pairs '()))
    (cond
     ((null? ls)
      (values (reverse pairs)
              (if (null? expr) '() (list "an expression with no ;; => value after it"))))
     ((prefix? ";; =>" (car ls))
      (loop (cdr ls) '()
            (cons (cons (join-lines (reverse expr))
                        (substring (car ls) 5 (string-length (car ls))))
                  pairs)))
     ((string=? (car ls) "") (loop (cdr ls) expr pairs))
     (else (loop (cdr ls) (cons (car ls) expr) pairs)))))

(define SNIPPET-ENV (environment '(rnrs) '(uri easy)))

;; check-doc : String String -> (values Nat Nat (Listof String))
;; Run every example in one org text: the programs and expressions checked, and
;; one line per difference or problem. Nothing raises out of it; an example that
;; raises is a difference, and so is a doc with no example at all.
(define (check-doc name text)
  (let-values (((blocks problems) (org-blocks (split-lines text))))
    (let loop ((bs blocks) (programs 0) (exprs 0)
               (diffs (map (lambda (p) (string-append name ": " p)) problems)))
      (define (at b what) (string-append name " line " (number->string (cadr b)) ": " what))
      (cond
       ((null? bs)
        (values programs exprs
                (reverse (if (= (+ programs exprs) 0)
                             (cons (string-append name ": no example; a check over nothing"
                                                  " would pass whatever the doc says")
                                   diffs)
                             diffs))))
       ((not (eq? (caar bs) 'scheme)) (loop (cdr bs) programs exprs diffs))
       ((let ((forms (guard (e (#t '())) (read-all (caddr (car bs))))))
          (and (pair? forms) (pair? (car forms)) (eq? (caar forms) 'import)))
        ;; a program: its example is the first example block before the next Scheme block
        (let* ((b (car bs))
               (example (let find ((rest (cdr bs)))
                          (cond ((null? rest) #f)
                                ((eq? (caar rest) 'scheme) #f)
                                ((eq? (caar rest) 'example) (caddr (car rest)))
                                (else (find (cdr rest))))))
               (printed (guard (e (#t (list 'raised (describe e))))
                          (run-program (caddr b)))))
          (loop (cdr bs) (+ programs 1) exprs
                (cond ((not example)
                       (cons (at b "a program with no #+begin_example after it") diffs))
                      ((pair? printed)
                       (cons (at b (string-append "the program raised: " (cadr printed))) diffs))
                      ((string=? printed example) diffs)
                      (else (cons (at b (string-append "printed\n" printed
                                                       "but the doc says\n" example))
                                  diffs))))))
       (else
        ;; expressions, each with its value
        (let-values (((pairs problems) (expression-pairs (caddr (car bs)))))
          (let ((b (car bs)))
            (let each ((ps pairs) (n exprs)
                       (diffs (append (map (lambda (p) (at b p)) problems) diffs)))
              (if (null? ps)
                  (loop (cdr bs) programs n diffs)
                  (let* ((expr (caar ps)) (want-text (cdar ps))
                         (outcome
                          (guard (e (#t (list 'raised (describe e))))
                            (let ((want (read-all want-text)) (forms (read-all expr)))
                              (unless (= (length want) 1)
                                (error 'check-doc "a ;; => line holds no single value" want-text))
                              (unless (= (length forms) 1)
                                (error 'check-doc "an expression is not a single form" expr))
                              (let ((got (eval (car forms) SNIPPET-ENV)))
                                (if (equal? got (car want))
                                    'same
                                    (list 'differs
                                          (call-with-string-output-port
                                           (lambda (p) (write got p))))))))))
                    (each (cdr ps) (+ n 1)
                          (cond ((eq? outcome 'same) diffs)
                                ((eq? (car outcome) 'raised)
                                 (cons (at b (string-append expr "raised: " (cadr outcome))) diffs))
                                (else
                                 (cons (at b (string-append expr "gave " (cadr outcome)
                                                            " but the doc says" want-text))
                                       diffs))))))))))))))

(harness-begin "example.docs")

;;; --- the checker, on docs whose verdicts are known --------------------------------
(define (inline . lines) (join-lines lines))

(define GOOD
  (inline "* A guide"
          "#+begin_src scheme"
          "(import (rnrs))"
          "(define x 1)"
          "(write (+ x 1)) (newline)"
          "#+end_src"
          "#+begin_src sh"
          "scheme --script good.scm"
          "#+end_src"
          "#+begin_example"
          "2"
          "#+end_example"
          "#+begin_src scheme"
          "(+ 1 2)"
          ";; => 3"
          "(uri-scheme (string->uri \"HTTP://a\"))"
          ";; => \"http\""
          "#+end_src"))

(harness-group "the checker"
  (lambda ()
    (harness-case "a correct doc: every example counted, no difference"
      (lambda ()
        (let-values (((programs exprs diffs) (check-doc "good" GOOD)))
          (check-equal "programs" programs 1)
          (check-equal "expressions" exprs 2)
          (check-equal "differences" diffs '()))))
    ;; Each of these must produce exactly one difference. A checker that always
    ;; agrees, or skips what it cannot read, fails here.
    (harness-case "every kind of wrong doc is reported"
      (lambda ()
        (for-each
         (lambda (row)
           (let-values (((programs exprs diffs) (check-doc (car row) (cadr row))))
             (check-equal (string-append (car row) ": one difference") (length diffs) 1)))
         (list
          (list "wrong output"
                (inline "#+begin_src scheme" "(import (rnrs))" "(write 1)" "#+end_src"
                        "#+begin_example" "2" "#+end_example"))
          (list "wrong value"
                (inline "#+begin_src scheme" "(+ 1 2)" ";; => 4" "#+end_src"))
          ;; The example after the second block matches what the program prints,
          ;; so a search that runs past a Scheme block finds it and sees nothing wrong.
          (list "a program with no example"
                (inline "#+begin_src scheme" "(import (rnrs))" "(write 1) (newline)" "#+end_src"
                        "#+begin_src scheme" "(+ 1 1)" ";; => 2" "#+end_src"
                        "#+begin_example" "1" "#+end_example"))
          (list "no example at all"
                (inline "* Only prose" "Nothing to run here."))
          ;; These two carry one good example first, so the doc is not also empty.
          (list "an expression with no value"
                (inline "#+begin_src scheme" "(+ 1 1)" ";; => 2" "#+end_src"
                        "#+begin_src scheme" "(+ 1 2)" "#+end_src"))
          (list "an expression that raises"
                (inline "#+begin_src scheme" "(car '())" ";; => 1" "#+end_src"))
          (list "a program that raises"
                (inline "#+begin_src scheme" "(import (rnrs))" "(car '())" "#+end_src"
                        "#+begin_example" "#+end_example"))
          (list "a block that never closes"
                (inline "#+begin_src scheme" "(+ 1 1)" ";; => 2" "#+end_src"
                        "#+begin_src scheme" "(+ 1 2)" ";; => 3"))))))
    ;; "(echo 1)" would raise if it were run as Scheme.
    (harness-case "a block in another language is not an example"
      (lambda ()
        (let-values (((programs exprs diffs)
                      (check-doc "sh" (inline "#+begin_src sh" "(echo 1)" "#+end_src"
                                              "#+begin_src scheme" "(+ 1 2)" ";; => 3" "#+end_src"))))
          (check-equal "the Scheme block alone counts" (list programs exprs) '(0 1))
          (check-equal "no differences" diffs '()))))))

;;; --- the docs ------------------------------------------------------------------------
(define ROOT (adapter-environment-variable "URI_DOC_ROOT"))
(define FILES (split-words (or (adapter-environment-variable "URI_DOC_FILES") "")))

(harness-group "the docs"
  (lambda ()
    (harness-case "the lane names its files"
      (lambda ()
        (check "URI_DOC_ROOT is set" (string? ROOT))
        (check "URI_DOC_FILES lists at least one file" (pair? FILES))))
    (for-each
     (lambda (file)
       (harness-case (string-append file ": every example prints what the doc says")
         (lambda ()
           (let-values (((programs exprs diffs)
                         (check-doc file (read-file (string-append ROOT "/" file)))))
             (display (string-append "uri-harness: coverage doc=" file
                                     " programs=" (number->string programs)
                                     " expressions=" (number->string exprs)
                                     " differences=" (number->string (length diffs))))
             (newline)
             (adapter-flush-output)
             (for-each (lambda (d) (check-fail "DOC EXAMPLE" d)) diffs)))))
     FILES)))

(harness-finish)
