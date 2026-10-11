#!r6rs
;;; example.api-reference -- docs/reference.md documents exactly what src/
;;; exports.
;;;
;;; Every library under src/ is read as data -- its `(library NAME (export
;;; ...))` form, never imported -- and compared with the reference page: the
;;; page's module table must list exactly those libraries, and each exported
;;; binding must have one `### `name` (kind)` entry with a body and one
;;; `**Available from:**` line naming exactly the libraries that export it. So
;;; a new export with no entry, an entry for a binding that is gone, and an
;;; entry naming the wrong library each fail here, by name.
;;;
;;; The files are URI_API_LIBRARIES (space-separated, relative to URI_API_ROOT,
;;; the repository root), and the page is docs/reference.md under that root.
;;; The checker, (uri test api-reference), is graded first on inline pages
;;; whose diagnostics are known, so a checker that always agrees reddens before
;;; it is trusted.
(import (rnrs)
        (uri test harness)
        (uri test api-reference))

(define (split-words s)
  (filter (lambda (w) (> (string-length w) 0))
          (let loop ((i 0) (start 0) (acc '()))
            (cond ((= i (string-length s)) (reverse (cons (substring s start i) acc)))
                  ((char=? (string-ref s i) #\space)
                   (loop (+ i 1) (+ i 1) (cons (substring s start i) acc)))
                  (else (loop (+ i 1) start acc))))))

(define (read-text path)
  (let ((s (call-with-port
            (open-file-input-port path (file-options) (buffer-mode block)
                                  (make-transcoder (utf-8-codec)))
            get-string-all)))
    (if (eof-object? s) "" s)))

(define (read-library-datum path)
  (call-with-port
   (open-file-input-port path (file-options) (buffer-mode block)
                         (make-transcoder (utf-8-codec)))
   get-datum))

(define (diagnostic-values tag diagnostics)
  (cond ((assq tag diagnostics) => cdr) (else '())))

(define (reference-text modules entries)
  (string-append "# API reference\n\n## Modules\n\n" modules "\n## Bindings\n\n" entries))

(define (entry name kind available body)
  (string-append "### `" name "` (" kind ")\n\n" body "\n\n"
                 "**Available from:** " available "\n\n"))

(define DEMO-MODULES "| `(demo)` | fixture |\n")
(define DEMO "`(demo)`")

(harness-begin "example.api-reference")

;;; --- the checker, on pages whose diagnostics are known --------------------------

(harness-group "export forms"
  (lambda ()
    (harness-case "a library's name and exports are read in declaration order"
      (lambda ()
        (let-values (((name exports problem)
                      (library-datum->api
                       '(library (demo core) (export alpha beta gamma) (import (rnrs))))))
          (check-equal "name" name '(demo core))
          (check-equal "exports" exports '(alpha beta gamma))
          ;; A value only the successful path produces.
          (check-equal "problem" (or problem 'no-problem) 'no-problem))))
    (harness-case "an export form the checker cannot read is a problem, not a skip"
      (lambda ()
        (let-values (((name exports problem)
                      (library-datum->api
                       '(library (demo renamed) (export alpha (rename beta public-beta))
                          (import (rnrs))))))
          (check-equal "problem" problem
                       '(unsupported-export-spec (rename beta public-beta))))))
    (harness-case "a datum that is not a library is a problem"
      (lambda ()
        (let-values (((name exports problem) (library-datum->api '(define x 1))))
          (check-equal "problem" (and (pair? problem) (car problem))
                       'malformed-library-datum))))))

(harness-group "the page grammar"
  (lambda ()
    (define parsed
      (markdown->reference-analysis
       (string-append
        "# API reference\n\n"
        "| `(outside before)` | ignored |\n\n"
        "## Modules\n\n"
        "| Module | Role |\n|---|---|\n"
        "| `(demo core)` | pure fixture |\n"
        "| `(demo shell)` | shell fixture |\n\n"
        "## Bindings\n\n"
        (entry "string->uri" "procedure" "`(demo core)`, `(demo shell)`"
               "`(string->uri s) -> uri`\n\nParses.")
        (entry "uri-error-reasons" "constant" "`(demo core)`" "`uri-error-reasons : (Listof Symbol)`")
        "| `(outside after)` | ignored |\n")))
    (harness-case "only rows inside the Modules section are modules"
      (lambda ()
        (check-equal "modules" (reference-analysis-modules parsed)
                     '((demo core) (demo shell)))))
    (harness-case "each h3 of the exact grammar is one entry, with its kind"
      (lambda ()
        (check-equal "names" (map reference-entry-name (reference-analysis-entries parsed))
                     '(string->uri uri-error-reasons))
        (check-equal "kinds" (map reference-entry-kind (reference-analysis-entries parsed))
                     '(procedure constant))))
    (harness-case "Available from records every library in code spans"
      (lambda ()
        (check-equal "modules"
                     (reference-entry-modules (car (reference-analysis-entries parsed)))
                     '((demo core) (demo shell)))))
    (harness-case "a signature or prose makes an entry substantive"
      (lambda ()
        (check-equal "body"
                     (map (lambda (e) (if (reference-entry-body? e) 'substantive 'empty))
                          (reference-analysis-entries parsed))
                     '(substantive substantive))))
    (harness-case "prose, fenced headings and index links are not entries"
      (lambda ()
        (check-equal "entries"
                     (map reference-entry-name
                          (reference-analysis-entries
                           (markdown->reference-analysis
                            (string-append
                             "# API reference\n\nThe `prose-name` binding.\n\n"
                             "```markdown\n### `fenced-name` (procedure)\n```\n\n"
                             "- [`index-name`](#index-name-procedure)\n"))))
                     '())))
    (harness-case "an h3 outside the grammar is reported by its text"
      (lambda ()
        (define (malformed text)
          (diagnostic-values 'malformed-entry-headings
                             (reference-diagnostics '() (markdown->reference-analysis text))))
        (check-equal "no code span"
                     (malformed "## Bindings\n\n### string->uri\n\nNo code span.\n")
                     '("### string->uri"))
        ;; The kinds are a closed list: a misspelt or invented kind is not an entry.
        (check-equal "unknown kind"
                     (malformed "## Bindings\n\n### `x` (variable)\n\n`x`\n")
                     '("### `x` (variable)"))))))

(harness-group "the diagnostics"
  (lambda ()
    (harness-case "a duplicate entry fails by name"
      (lambda ()
        (check-equal "duplicates"
                     (diagnostic-values
                      'duplicate-bindings
                      (reference-diagnostics
                       (list '((demo) alpha))
                       (markdown->reference-analysis
                        (reference-text DEMO-MODULES
                                        (string-append
                                         (entry "alpha" "procedure" DEMO "`(alpha) -> symbol`")
                                         (entry "alpha" "procedure" DEMO "`(alpha) -> symbol`"))))))
                     '(alpha))))
    (harness-case "an Available from line alone is not a body"
      (lambda ()
        (check-equal "empty"
                     (diagnostic-values
                      'empty-entry-bodies
                      (reference-diagnostics
                       (list '((demo) alpha))
                       (markdown->reference-analysis
                        (reference-text DEMO-MODULES
                                        "### `alpha` (procedure)\n\n**Available from:** `(demo)`\n"))))
                     '(alpha))))
    (harness-case "an export with no entry is missing, an entry with no export is extra"
      (lambda ()
        (let ((ds (reference-diagnostics
                   (list '((demo) alpha beta))
                   (markdown->reference-analysis
                    (reference-text DEMO-MODULES
                                    (string-append
                                     (entry "alpha" "procedure" DEMO "`(alpha) -> symbol`")
                                     (entry "charlie" "procedure" DEMO "`(charlie) -> symbol`")))))))
          (check-equal "missing" (diagnostic-values 'missing-bindings ds) '(beta))
          (check-equal "extra" (diagnostic-values 'extra-bindings ds) '(charlie)))))
    (harness-case "a library absent from the table is missing, an invented row is extra"
      (lambda ()
        (let ((ds (reference-diagnostics
                   (list '((demo) alpha) '((actual second)))
                   (markdown->reference-analysis
                    (reference-text "| `(demo)` | fixture |\n| `(invented)` | fixture |\n"
                                    (entry "alpha" "procedure" DEMO "`(alpha) -> symbol`"))))))
          (check-equal "missing" (diagnostic-values 'missing-modules ds) '((actual second)))
          (check-equal "extra" (diagnostic-values 'extra-modules ds) '((invented))))))
    (harness-case "an entry needs exactly one Available from line"
      (lambda ()
        (check-equal "none"
                     (diagnostic-values
                      'missing-availability
                      (reference-diagnostics
                       (list '((demo) alpha))
                       (markdown->reference-analysis
                        (reference-text DEMO-MODULES "### `alpha` (procedure)\n\n`(alpha) -> symbol`\n"))))
                     '(alpha))
        (check-equal "two"
                     (diagnostic-values
                      'duplicate-availability
                      (reference-diagnostics
                       (list '((demo) alpha))
                       (markdown->reference-analysis
                        (reference-text DEMO-MODULES
                                        (string-append
                                         "### `alpha` (procedure)\n\n`(alpha) -> symbol`\n\n"
                                         "**Available from:** `(demo)`\n\n"
                                         "**Available from:** `(demo)`\n")))))
                     '(alpha))))
    (harness-case "Available from must name every exporting library, and only those"
      (lambda ()
        (check-equal "mismatch"
                     (diagnostic-values
                      'module-membership-mismatches
                      (reference-diagnostics
                       (list '((demo) alpha) '((demo narrow) alpha))
                       (markdown->reference-analysis
                        (reference-text "| `(demo)` | fixture |\n| `(demo narrow)` | fixture |\n"
                                        (entry "alpha" "procedure" "`(demo)`" "`(alpha) -> symbol`")))))
                     '((alpha ((demo) (demo narrow)) ((demo)))))))
    (harness-case "nothing on either side is never success"
      (lambda ()
        (let ((ds (reference-diagnostics '() (markdown->reference-analysis "# API reference\n"))))
          (check-equal "no public modules" (diagnostic-values 'no-public-modules ds) '(empty))
          (check-equal "no public bindings" (diagnostic-values 'no-public-bindings ds) '(empty))
          (check-equal "no reference modules" (diagnostic-values 'no-reference-modules ds) '(empty))
          (check-equal "no reference bindings" (diagnostic-values 'no-reference-bindings ds) '(empty)))))
    (harness-case "a page that matches its sources has no diagnostics"
      (lambda ()
        (check-equal "diagnostics"
                     (reference-diagnostics
                      (list '((demo) alpha))
                      (markdown->reference-analysis
                       (reference-text DEMO-MODULES (entry "alpha" "procedure" DEMO "`(alpha) -> symbol`"))))
                     '())))))

;;; --- the real page against the real sources --------------------------------------

(define ROOT (adapter-environment-variable "URI_API_ROOT"))
(define LIBRARIES (split-words (or (adapter-environment-variable "URI_API_LIBRARIES") "")))

(harness-group "docs/reference.md"
  (lambda ()
    (harness-case "the lane names its libraries"
      (lambda ()
        (check "URI_API_ROOT is set" (string? ROOT))
        (check "URI_API_LIBRARIES lists at least one library" (pair? LIBRARIES))))
    (harness-case "documents exactly what src/ exports"
      (lambda ()
        (let loop ((files LIBRARIES) (apis '()))
          (if (pair? files)
              (let-values (((name exports problem)
                            (library-datum->api
                             (read-library-datum (string-append ROOT "/" (car files))))))
                (if problem
                    (begin (check-fail (car files) (adapter-value->string problem))
                           (loop (cdr files) apis))
                    (loop (cdr files) (cons (cons name exports) apis))))
              (let* ((apis (reverse apis))
                     (analysis (markdown->reference-analysis
                                (read-text (string-append ROOT "/docs/reference.md"))))
                     (diagnostics (reference-diagnostics apis analysis)))
                (display (string-append
                          "uri-harness: coverage reference libraries="
                          (number->string (length apis))
                          " documented-modules="
                          (number->string (length (reference-analysis-modules analysis)))
                          " entries="
                          (number->string (length (reference-analysis-entries analysis)))
                          " diagnostics=" (number->string (length diagnostics))))
                (newline)
                (adapter-flush-output)
                (for-each (lambda (d) (check-fail (symbol->string (car d))
                                                  (adapter-value->string (cdr d))))
                          diagnostics)
                (check-equal "every library was read" (length apis) (length LIBRARIES)))))))))

(harness-finish)
