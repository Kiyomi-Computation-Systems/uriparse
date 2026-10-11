#!r6rs
;;; example.docs -- every Scheme example in the user-facing docs runs, and prints
;;; what the doc says it prints.
;;;
;;; A doc's Scheme blocks -- `#+begin_src scheme` in org, ```scheme in Markdown --
;;; are of two kinds:
;;;   - a PROGRAM, whose first form is `(import ...)`. Its body is evaluated in
;;;     the environment its import names, with `display`, `write` and `newline`
;;;     captured, and what it prints must equal the first output block after it
;;;     (`#+begin_example`, or ```text), before the next Scheme block;
;;;   - EXPRESSIONS, each followed by a `;; => value` line. Each is evaluated in
;;;     (rnrs) and every library the guides document, and its result must be
;;;     `equal?` to the value read.
;;; A block in another language (`#+begin_src sh`, ```sh) is not an example.
;;;
;;; The candidates are URI_DOC_FILES (space-separated, relative to URI_DOC_ROOT):
;;; README.org and every prose file under docs/. A .org file is read as org and
;;; a .md file as Markdown. A dotfile (an editor's lock file, .DS_Store) is not a
;;; doc. Each of these is a failure, because each would let examples go
;;; unchecked with nothing failing:
;;;   - a doc in a format the lane cannot read (say a guide moved to .rst);
;;;   - a docs/ with no guide the lane reads;
;;;   - a read doc with no example.
;;; The checker is graded first, on inline docs whose verdicts are known, so one
;;; that always agrees reddens before it is trusted.
(import (rnrs)
        (rnrs eval)
        (uri test harness)
        ;; Loaded, nothing bound: every library a documented example imports must
        ;; be in the running image, so `environment` finds it in the compiled lane
        ;; as well as from source. SNIPPET-ENV names the same list.
        (only (uri easy))
        (only (uri collect))
        (only (uri components))
        (only (uri vocabulary))
        (only (uri charset))
        (only (uri host))
        (only (uri normalize))
        (only (uri path))
        (only (uri percent))
        (only (uri query))
        (only (uri recompose))
        (only (uri resolve)))

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

(define (suffix? x s)
  (and (<= (string-length x) (string-length s))
       (string=? x (substring s (- (string-length s) (string-length x)) (string-length s)))))

(define (basename path)
  (let loop ((i (string-length path)))
    (cond ((= i 0) path)
          ((char=? (string-ref path (- i 1)) #\/) (substring path i (string-length path)))
          (else (loop (- i 1))))))

;; --- which files are docs ------------------------------------------------------
;;
;; doc-format : String -> Symbol
;; 'skip for a dotfile (an editor's lock file such as ".#easy.org"); 'org for an
;; org file and 'markdown for a .md file, the two formats the lane reads;
;; 'unread for any other doc. An unread doc fails rather than being skipped: its
;; examples would otherwise go unchecked, and nothing would say so.
(define (doc-format path)
  (let ((base (basename path)))
    (cond ((prefix? "." base) 'skip)
          ((suffix? ".org" base) 'org)
          ((suffix? ".md" base) 'markdown)
          (else 'unread))))

;; read-format? : Symbol -> Boolean
(define (read-format? format) (and (memq format '(org markdown)) #t))

;; doc-set-problems : (Listof String) -> (Listof String)
;; What is wrong with the candidate files as a set: each doc the lane cannot
;; read, and a docs/ with no guide it reads.
(define (doc-set-problems files)
  (append
   (map (lambda (f)
          (string-append f ": no reader for this format, so its examples would go"
                         " unchecked; teach doc-examples-tests.sps to read it"))
        (filter (lambda (f) (eq? (doc-format f) 'unread)) files))
   (if (exists (lambda (f) (and (prefix? "docs/" f) (read-format? (doc-format f)))) files)
       '()
       (list "docs/ has no guide the lane reads"))))

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

;; leading-spaces : String -> Nat
(define (leading-spaces line)
  (let loop ((i 0))
    (if (and (< i (string-length line)) (char=? (string-ref line i) #\space))
        (loop (+ i 1))
        i)))

;; markdown-blocks : (Listof String) -> (values (Listof Block) (Listof String))
;; The same blocks as org-blocks, from Markdown's fenced code blocks: a line of
;; ``` opens one, its first word naming the language, and the next line of only
;; ``` closes it. ```scheme is 'scheme, ```text is 'example -- a program's
;; output -- and any other fence is 'other. A fence indented inside a list item
;; has that indentation removed from each line of its body, as CommonMark does,
;; so a `;; =>` line inside it starts the line.
(define (markdown-blocks lines)
  (let loop ((ls lines) (n 1) (blocks '()) (problems '()))
    (cond
     ((null? ls) (values (reverse blocks) (reverse problems)))
     ((let ((indent (leading-spaces (car ls))))
        (and (prefix? "```" (substring (car ls) indent (string-length (car ls)))) indent))
      => (lambda (indent)
           (let* ((words (split-words (substring (car ls) (+ indent 3) (string-length (car ls)))))
                  (kind (cond ((null? words) 'other)
                              ((string=? (car words) "scheme") 'scheme)
                              ((string=? (car words) "text") 'example)
                              (else 'other))))
             (define (unindent line)
               (substring line (min indent (leading-spaces line)) (string-length line)))
             (let body ((bs (cdr ls)) (m (+ n 1)) (acc '()))
               (cond ((null? bs)
                      (loop '() m blocks
                            (cons (string-append "line " (number->string n)
                                                 ": a block that never closes")
                                  problems)))
                     ((string=? (unindent (car bs)) "```")
                      (loop (cdr bs) (+ m 1)
                            (cons (list kind n (join-lines (reverse acc))) blocks) problems))
                     (else (body (cdr bs) (+ m 1) (cons (unindent (car bs)) acc))))))))
     (else (loop (cdr ls) (+ n 1) blocks problems)))))

;; doc-blocks : String (Listof String) -> (values (Listof Block) (Listof String))
;; The reader for a file, by its doc-format: Markdown for 'markdown, org for
;; anything else (the checker's own inline docs carry names with no extension).
(define (doc-blocks name lines)
  (if (eq? (doc-format name) 'markdown)
      (markdown-blocks lines)
      (org-blocks lines)))

;; --- running examples ------------------------------------------------------------

;; definition? : Datum -> Boolean
(define (definition? form)
  (and (pair? form)
       (memq (car form) '(define define-syntax define-record-type
                          define-condition-type define-enumeration))
       #t))

;; as-body : (Listof Datum) -> (Listof Datum)
;; A top-level program's forms as a body. A program may define after an
;; expression and a body may not, so every expression that comes before a
;; definition is itself made a definition, of a name nothing reads. The order of
;; evaluation is unchanged: a body's definitions run left to right.
(define (as-body forms)
  (let loop ((fs forms) (i 0) (acc '()))
    (cond ((null? fs) (reverse acc))
          ((and (not (definition? (car fs))) (exists definition? (cdr fs)))
           (loop (cdr fs) (+ i 1)
                 (cons `(define ,(string->symbol (string-append "%doc-expr-" (number->string i)))
                          (begin ,(car fs) #f))
                       acc)))
          (else (loop (cdr fs) (+ i 1) (cons (car fs) acc))))))

;; run-program : String -> String
;; Evaluate a program's body in the environment its import names, and return
;; what it printed through display, write and newline.
(define (run-program text)
  (let ((forms (read-all text)))
    (unless (and (pair? forms) (pair? (car forms)) (eq? (caar forms) 'import))
      (error 'run-program "a program does not begin with (import ...)"))
    (let ((env (apply environment
                      '(only (rnrs base) lambda let define begin)
                      '(only (rnrs io simple) display write newline)
                      (cdar forms)))
          (wrapper `(lambda (%out)
                      (let ((display (lambda (x) (display x %out)))
                            (write (lambda (x) (write x %out)))
                            (newline (lambda () (newline %out))))
                        (let () ,@(as-body (cdr forms)))))))
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

;; Every library a guide documents, none of whose names collide, so an
;; expression may call any of them as the page that shows it does.
(define SNIPPET-ENV
  (environment '(rnrs) '(uri easy) '(uri collect) '(uri components) '(uri vocabulary)
               '(uri charset) '(uri host) '(uri normalize) '(uri path) '(uri percent)
               '(uri query) '(uri recompose) '(uri resolve)))

;; check-doc : String String -> (values Nat Nat (Listof String))
;; Run every example in one org text: the programs and expressions checked, and
;; one line per difference or problem. Nothing raises out of it; an example that
;; raises is a difference, and so is a doc with no example at all.
(define (check-doc name text)
  (let-values (((blocks problems) (doc-blocks name (split-lines text))))
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
                       (cons (at b (string-append "a program with no output block after it"
                                                  " (#+begin_example, or ```text in Markdown)"))
                             diffs))
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

;; check-wrong-docs : String (Listof (List String String String)) -> unspecified
;; Each row is a label, a doc with one fault, and a fragment of the difference
;; that fault must produce. The count alone cannot tell a working reader from
;; one that sees no block at all: that one reports every doc as having no
;; example, which is also exactly one difference. Every doc is named
;; "doc" plus `ext`, which picks the reader, and never the label: check-doc
;; prefixes the name to each difference, so a label holding its own fragment
;; would match whatever the difference said.
(define (check-wrong-docs ext rows)
  (for-each
   (lambda (row)
     (let-values (((programs exprs diffs) (check-doc (string-append "doc" ext) (cadr row))))
       (check-equal (string-append (car row) ": one difference") (length diffs) 1)
       (check (string-append (car row) ": the difference names its fault, "
                             (adapter-value->string (caddr row)))
              (and (pair? diffs) (harness-string-contains? (car diffs) (caddr row))))))
   rows))

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
        (check-wrong-docs ".org"
         (list
          (list "wrong output"
                (inline "#+begin_src scheme" "(import (rnrs))" "(write 1)" "#+end_src"
                        "#+begin_example" "2" "#+end_example")
                "printed\n1")
          (list "wrong value"
                (inline "#+begin_src scheme" "(+ 1 2)" ";; => 4" "#+end_src")
                "gave 3")
          ;; The example after the second block matches what the program prints,
          ;; so a search that runs past a Scheme block finds it and sees nothing wrong.
          (list "a program with no example"
                (inline "#+begin_src scheme" "(import (rnrs))" "(write 1) (newline)" "#+end_src"
                        "#+begin_src scheme" "(+ 1 1)" ";; => 2" "#+end_src"
                        "#+begin_example" "1" "#+end_example")
                "a program with no output block")
          (list "no example at all"
                (inline "* Only prose" "Nothing to run here.")
                "no example;")
          ;; These two carry one good example first, so the doc is not also empty.
          (list "an expression with no value"
                (inline "#+begin_src scheme" "(+ 1 1)" ";; => 2" "#+end_src"
                        "#+begin_src scheme" "(+ 1 2)" "#+end_src")
                "with no ;; => value")
          (list "an expression that raises"
                (inline "#+begin_src scheme" "(car '())" ";; => 1" "#+end_src")
                "(car '())\nraised: ")
          (list "a program that raises"
                (inline "#+begin_src scheme" "(import (rnrs))" "(car '())" "#+end_src"
                        "#+begin_example" "#+end_example")
                "the program raised: ")
          (list "a block that never closes"
                (inline "#+begin_src scheme" "(+ 1 1)" ";; => 2" "#+end_src"
                        "#+begin_src scheme" "(+ 1 2)" ";; => 3")
                "a block that never closes")))))
    ;; The set check is what notices a guide changing format: a file the lane
    ;; cannot read must fail, never vanish from what is checked.
    (harness-case "which files are docs, and what is wrong with a set of them"
      (lambda ()
        (for-each
         (lambda (row) (check-equal (car row) (doc-format (car row)) (cadr row)))
         '(("README.org" org) ("docs/easy.org" org) ("docs/api/index.org" org)
           ("docs/easy.md" markdown) ("docs/README.md" markdown)
           ("docs/guide.markdown" unread) ("docs/notes.txt" unread) ("docs/easy.rst" unread)
           ("docs/.#easy.org" skip) ("docs/api/.DS_Store" skip)))
        (check-equal "README.org and a guide" (doc-set-problems '("README.org" "docs/easy.org")) '())
        (check-equal "an editor's lock file beside the guide"
                     (doc-set-problems '("README.org" "docs/.#easy.org" "docs/easy.org")) '())
        (check-equal "a Markdown index beside the guide"
                     (doc-set-problems '("README.org" "docs/easy.org" "docs/README.md")) '())
        (check-equal "the guide moved to Markdown"
                     (doc-set-problems '("README.org" "docs/easy.md")) '())
        (check-equal "no guide at all" (length (doc-set-problems '("README.org"))) 1)
        (check-equal "a Markdown guide beside a doc the lane cannot read"
                     (length (doc-set-problems '("README.org" "docs/easy.md" "docs/notes.txt"))) 1)
        (check-equal "the guide moved to a format with no reader"
                     (length (doc-set-problems '("README.org" "docs/easy.rst"))) 2)))
    ;; "(echo 1)" would raise if it were run as Scheme.
    (harness-case "a block in another language is not an example"
      (lambda ()
        (let-values (((programs exprs diffs)
                      (check-doc "sh" (inline "#+begin_src sh" "(echo 1)" "#+end_src"
                                              "#+begin_src scheme" "(+ 1 2)" ";; => 3" "#+end_src"))))
          (check-equal "the Scheme block alone counts" (list programs exprs) '(0 1))
          (check-equal "no differences" diffs '()))))))

;;; --- the checker, on Markdown ------------------------------------------------------
;;
;; The same verdicts as above, through the Markdown reader: a file whose name ends
;; in .md is read for fences, ```scheme for Scheme and ```text for a program's
;; output. Each wrong doc is the twin of an org one.
(define GOOD-MD
  (inline "# A guide"
          "```scheme"
          "(import (rnrs))"
          "(define x 1)"
          "(write (+ x 1)) (newline)"
          "```"
          "```sh"
          "scheme --script good.scm"
          "```"
          "```text"
          "2"
          "```"
          "- A list item holds an indented fence:"
          ""
          "  ```scheme"
          "  (+ 1 2)"
          "  ;; => 3"
          "  (uri-scheme (string->uri \"HTTP://a\"))"
          "  ;; => \"http\""
          "  ```"))

(harness-group "the checker on Markdown"
  (lambda ()
    (harness-case "a correct doc: every example counted, no difference"
      (lambda ()
        (let-values (((programs exprs diffs) (check-doc "good.md" GOOD-MD)))
          (check-equal "programs" programs 1)
          (check-equal "expressions" exprs 2)
          (check-equal "differences" diffs '()))))
    (harness-case "every kind of wrong doc is reported"
      (lambda ()
        (check-wrong-docs ".md"
         (list
          (list "wrong output.md"
                (inline "```scheme" "(import (rnrs))" "(write 1)" "```"
                        "```text" "2" "```")
                "printed\n1")
          (list "wrong value.md"
                (inline "```scheme" "(+ 1 2)" ";; => 4" "```")
                "gave 3")
          (list "a program with no example.md"
                (inline "```scheme" "(import (rnrs))" "(write 1) (newline)" "```"
                        "```scheme" "(+ 1 1)" ";; => 2" "```"
                        "```text" "1" "```")
                "a program with no output block")
          (list "no example at all.md"
                (inline "# Only prose" "Nothing to run here.")
                "no example;")
          (list "an expression with no value.md"
                (inline "```scheme" "(+ 1 1)" ";; => 2" "```"
                        "```scheme" "(+ 1 2)" "```")
                "with no ;; => value")
          (list "an expression that raises.md"
                (inline "```scheme" "(car '())" ";; => 1" "```")
                "(car '())\nraised: ")
          (list "a program that raises.md"
                (inline "```scheme" "(import (rnrs))" "(car '())" "```"
                        "```text" "```")
                "the program raised: ")
          (list "a block that never closes.md"
                (inline "```scheme" "(+ 1 1)" ";; => 2" "```"
                        "```scheme" "(+ 1 2)" ";; => 3")
                "a block that never closes")))))
    (harness-case "a block in another language is not an example"
      (lambda ()
        (let-values (((programs exprs diffs)
                      (check-doc "sh.md" (inline "```sh" "(echo 1)" "```"
                                                 "```scheme" "(+ 1 2)" ";; => 3" "```"))))
          (check-equal "the Scheme block alone counts" (list programs exprs) '(0 1))
          (check-equal "no differences" diffs '()))))
    ;; An org file holds no fences: read as Markdown it would have no example.
    (harness-case "the reader is chosen by the file's extension"
      (lambda ()
        (let-values (((programs exprs diffs)
                      (check-doc "fences.org" (inline "```scheme" "(+ 1 2)" ";; => 3" "```"))))
          (check-equal "no example in an org file's fences" (list programs exprs) '(0 0)))))
    ;; A top-level program may define after an expression; a body may not. The
    ;; reader runs the program as a program, so the checker must too.
    (harness-case "a program may define after an expression, as a top-level program can"
      (lambda ()
        (let-values (((programs exprs diffs)
                      (check-doc "mixed.md"
                                 (inline "```scheme"
                                         "(import (rnrs))"
                                         "(define x 1)"
                                         "(write x) (newline)"
                                         "(define y (+ x 1))"
                                         "(write y) (newline)"
                                         "```"
                                         "```text" "1" "2" "```"))))
          (check-equal "programs" programs 1)
          (check-equal "no differences" diffs '()))))
    ;; Expressions see every library a guide documents, not only (uri easy).
    (harness-case "an expression can call any documented library"
      (lambda ()
        (let-values (((programs exprs diffs)
                      (check-doc "libraries.md"
                                 (inline "```scheme"
                                         "(utf8->string (pct-decode (string->utf8 \"a%20b\")))"
                                         ";; => \"a b\""
                                         "(uri-parse-ok? (uri-parse 'uri (string->utf8 \"http://a\")))"
                                         ";; => #t"
                                         "```"))))
          (check-equal "expressions" exprs 2)
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
    (harness-case "every doc is one the lane reads, and docs/ has a guide"
      (lambda ()
        (let ((problems (doc-set-problems FILES))
              (count (lambda (kind) (length (filter (lambda (f) (eq? (doc-format f) kind)) FILES)))))
          (display (string-append "uri-harness: coverage doc-set files=" (number->string (length FILES))
                                  " org=" (number->string (count 'org))
                                  " markdown=" (number->string (count 'markdown))
                                  " skipped=" (number->string (count 'skip))
                                  " unread=" (number->string (count 'unread))))
          (newline)
          (adapter-flush-output)
          (for-each (lambda (p) (check-fail "DOC SET" p)) problems)
          (check "the doc set has no problem" (null? problems)))))
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
     (filter (lambda (f) (read-format? (doc-format f))) FILES))))

(harness-finish)
