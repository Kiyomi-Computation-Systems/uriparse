#!r6rs
;;; unit.easy-resolve -- (uri easy): render, resolve, normalize, compare.
;;;
;;; What is graded here:
;;;   - uri->string is the identity on every committed corpus input that
;;;     validates: the record holds the input as written;
;;;   - uri-resolve reproduces all 42 RFC 3986 §5.4 targets, AS STRINGS, and does
;;;     not normalize;
;;;   - uri-normalize is the full §6.2.2 normalizer (dot segments included,
;;;     except in a relative-path reference), and it is idempotent over the
;;;     validated domain;
;;;   - nothing the easy layer builds renders to a different URI: every Uri that
;;;     uri-resolve and uri-normalize return re-parses to the same components,
;;;     including the `//`-leading no-authority path RFC 3986's own algorithms
;;;     produce;
;;;   - uri=? is equality after normalization, absent still distinct from empty;
;;;   - uri->components and components->uri copy, so neither side can mutate the
;;;     other, and components->uri refuses a set that would re-parse differently.
(import (rnrs)
        (uri test harness)
        (uri test corpus)
        (uri components)
        (uri easy))

(define (corpus-path name)
  (string-append (adapter-environment-variable "URI_CORPUS_DIR") "/" name))
(define (differential-path name)
  (string-append (adapter-environment-variable "URI_DIFFERENTIAL_DIR") "/" name))

;; raised : (-> Any) -> (Option Condition), the raised object, or #f on return.
(define (raised thunk)
  (guard (e (#t e)) (thunk) #f))

(define (check-uri-error label thunk who reason offset input)
  (let ((c (raised thunk)))
    (if (and c (uri-error? c))
        (begin
          (check-equal (string-append label ": reason") (uri-error-reason c) reason)
          (check-equal (string-append label ": offset") (uri-error-offset c) offset)
          (check-equal (string-append label ": input") (uri-error-input c) input)
          (check-equal (string-append label ": who")
                       (and (who-condition? c) (condition-who c)) who))
        (check-fail label "expected a uri-error"))))

(define (check-refuses label thunk who)
  (let ((c (raised thunk)))
    (check-equal (string-append label ": an assertion naming " (symbol->string who))
                 (and c (assertion-violation? c) (who-condition? c) (condition-who c))
                 who)))

;; renders-faithfully? : Uri -> Boolean
;; Rule 8: the string re-parses to exactly the same components.
(define (renders-faithfully? u)
  (uri-components=? (uri->components (string->uri-reference (uri->string u)))
                    (uri->components u)))

(define (same-uri? a b)
  (uri-components=? (uri->components a) (uri->components b)))

(define (s->s f) (lambda (s) (uri->string (f s))))

;; --- the corpora: every committed input that validates, with its parser ----

(define (read-data path)
  (let ((p (open-file-input-port path (file-options) (buffer-mode block)
                                 (native-transcoder))))
    (let loop ((acc '()))
      (let ((d (get-datum p)))
        (if (eof-object? d)
            (begin (close-port p) (reverse acc))
            (loop (cons d acc)))))))

(define RESOLUTION (corpus-load-resolution (corpus-path "resolution.scm")))
(define BASE (resolution-base RESOLUTION))
(define EXAMPLES (corpus-load-examples (corpus-path "example-uris.scm")))

;; The adversarial corpus's accepted rows, as (mode . string). A row's input is
;; a string or a bytevector; an accepted one is ASCII either way.
(define ADVERSARIAL
  (let loop ((ds (read-data (differential-path "adversarial.scm"))))
    (cond ((null? ds) (error 'adversarial "no (cases ...) form"))
          ((and (pair? (car ds)) (eq? (caar ds) 'cases))
           (let rows ((rs (cdar ds)) (acc '()))
             (cond ((null? rs) (reverse acc))
                   ((eq? (caddr (car rs)) 'accept)
                    (let ((in (cadr (car rs))))
                      (rows (cdr rs)
                            (cons (cons (car (car rs)) (if (string? in) in (utf8->string in)))
                                  acc))))
                   (else (rows (cdr rs) acc)))))
          (else (loop (cdr ds))))))

(define (parser-for mode)
  (case mode
    ((uri) string->uri)
    ((uri-reference) string->uri-reference)
    ((relative-ref) string->relative-ref)))

;; Every corpus input that validates, as (label parser input).
(define CORPUS
  (append
   (map (lambda (s) (list "example" string->uri s)) EXAMPLES)
   (list (list "5.4 base" string->uri BASE))
   (map (lambda (v) (list "5.4 reference" string->uri-reference (rv-reference v)))
        (resolution-vectors RESOLUTION))
   (map (lambda (v) (list "5.4 target" string->uri (rv-target v)))
        (resolution-vectors RESOLUTION))
   (map (lambda (r) (list "adversarial" (parser-for (car r)) (cdr r))) ADVERSARIAL)))

(harness-begin "unit.easy-resolve")

;;; --- uri->string -------------------------------------------------------------
(harness-group "uri->string gives back what was parsed"
  (lambda ()
    (harness-case "every corpus input round-trips as a string"
      (lambda ()
        (display (string-append "uri-harness: coverage corpus=" (number->string (length CORPUS))
                                " examples=" (number->string (length EXAMPLES))
                                " resolution=" (number->string (length (resolution-vectors RESOLUTION)))
                                " adversarial-accepted=" (number->string (length ADVERSARIAL))))
        (newline)
        (adapter-flush-output)
        (check-equal "eight examples" (length EXAMPLES) 8)
        (check-equal "42 resolution rows" (length (resolution-vectors RESOLUTION)) 42)
        (check "the adversarial corpus has accepted rows" (> (length ADVERSARIAL) 0))
        (for-each
         (lambda (row)
           (check-equal (string-append (car row) " \"" (caddr row) "\"")
                        (uri->string ((cadr row) (caddr row))) (caddr row)))
         CORPUS)))
    (harness-case "case, encoding and empty components are kept as written"
      (lambda ()
        (for-each
         (lambda (s) (check-equal s (uri->string (string->uri-reference s)) s))
         '("HTTP://User@Ex%41mple.COM/A%41" "http://a?" "http://a#" "http://a?#"
           "file:///x" "//a" "" "?q" "./a:b" "http://[::1]:80/%7e"))))))

;;; --- uri-resolve ---------------------------------------------------------------
(harness-group "uri-resolve: RFC 3986 §5.4, as strings"
  (lambda ()
    (harness-case "all 42 rows"
      (lambda ()
        (for-each
         (lambda (v)
           (check-equal (rv-id v) (uri->string (uri-resolve BASE (rv-reference v))) (rv-target v)))
         (resolution-vectors RESOLUTION))))
    (harness-case "a Uri or a string in either position"
      (lambda ()
        (let ((b (string->uri BASE)) (r (string->uri-reference "../g?y")))
          (check-equal "Uri, Uri" (uri->string (uri-resolve b r)) "http://a/b/g?y")
          (check-equal "Uri, string" (uri->string (uri-resolve b "../g?y")) "http://a/b/g?y")
          (check-equal "string, Uri" (uri->string (uri-resolve BASE r)) "http://a/b/g?y"))))
    (harness-case "resolution does not normalize"
      (lambda ()
        (check-equal "case and encoding survive"
                     (uri->string (uri-resolve "HTTP://A/b/c" "%7Ed")) "HTTP://A/b/%7Ed")))
    ;; RFC 3986's algorithms give {foo, no authority, "//bar"}, which §5.3 writes
    ;; as "foo://bar": a URI whose authority is "bar". The guard writes "/.//bar",
    ;; which re-parses unchanged and names the same resource.
    (harness-case "a //-leading path after no authority is guarded"
      (lambda ()
        (for-each
         (lambda (ref)
           (let ((t (uri-resolve "foo:/a" ref)))
             (check-equal (string-append "foo:/a + " ref) (uri->string t) "foo:/.//bar")
             (check (string-append ref ": no authority") (not (uri-authority t)))
             (check (string-append ref ": renders faithfully") (renders-faithfully? t))))
         '(".//bar" "/.//bar"))
        (check-equal "an authority keeps // inside the path"
                     (uri->string (uri-resolve "http://h/a" "/.//bar")) "http://h//bar")))
    (harness-case "the base must be absolute"
      (lambda ()
        (check-uri-error "a relative Uri base"
                         (lambda () (uri-resolve (string->uri-reference "/a") "b"))
                         'uri-resolve 'base-not-absolute 0 "/a")
        (check-uri-error "a relative string base" (lambda () (uri-resolve "/a" "b"))
                         'uri-resolve 'scheme-required 0 "/a")
        (check-uri-error "an invalid reference" (lambda () (uri-resolve "http://a/" "b c"))
                         'uri-resolve 'invalid-pchar 1 "b c")))
    (harness-case "a wrong argument is an assertion naming uri-resolve"
      (lambda ()
        (check-refuses "base 42" (lambda () (uri-resolve 42 "a")) 'uri-resolve)
        (check-refuses "reference #f" (lambda () (uri-resolve "http://a/" #f)) 'uri-resolve)))))

;;; --- uri-normalize -------------------------------------------------------------
(define NORMALIZE-ROWS
  '(;; every §6.2.2 step at once: scheme and host case, unreserved decoding,
    ;; hex case, dot segments; userinfo keeps its case
    ("HTTP://User@Ex%41mple.COM/A%41/%7e/./b/../c?%7E%2f#%7e" "http://User@example.com/AA/~/c?~%2F#~")
    ;; percent-normalization first, so a decoded %2E%2E is removed too
    ("http://h/a/%2E%2E/b" "http://h/b")
    ("http://h/a/b/../../../c" "http://h/c")
    ;; a rooted reference and a network-path reference lose their dots
    ("/a/../b" "/b")
    ("//H/a/../b" "//h/b")
    ;; a relative-path reference keeps them: `..` there is relative to a base, and
    ;; removing `./` from "./a:b" would leave "a:b", a scheme
    ("../b" "../b")
    ("a/./b" "a/./b")
    ("./a:b" "./a:b")
    ;; as §5.2.2 resolves a reference with a scheme: dot removal roots the path
    ("foo:a/../b" "foo:/b")
    ;; the guard: dot removal gives "//bar" with no authority
    ("foo:/.//bar" "foo:/.//bar")
    ("/.//x" "/.//x")
    ;; scheme-based normalization is NOT done (§6.2.3)
    ("http://a" "http://a")
    ("http://a:80/" "http://a:80/")
    ("http://a?" "http://a?")))

(harness-group "uri-normalize: syntax-based normalization, §6.2.2"
  (lambda ()
    (harness-case "the normalize table"
      (lambda ()
        (for-each
         (lambda (row)
           (check-equal (string-append "normalize \"" (car row) "\"")
                        (uri->string (uri-normalize (string->uri-reference (car row))))
                        (cadr row)))
         NORMALIZE-ROWS)))
    (harness-case "it returns a new Uri and leaves its argument alone"
      (lambda ()
        (let* ((u (string->uri "HTTP://A/%7e")) (n (uri-normalize u)))
          (check-equal "the argument" (uri->string u) "HTTP://A/%7e")
          (check-equal "the result" (uri->string n) "http://a/~"))))
    (harness-case "a wrong argument is an assertion naming uri-normalize"
      (lambda () (check-refuses "a string" (lambda () (uri-normalize "http://a")) 'uri-normalize)))))

;;; --- rule 8 and idempotence, over the corpora -------------------------------------
(harness-group "what the easy layer builds renders faithfully, and normalize is idempotent"
  (lambda ()
    (harness-case "every normalized corpus input: faithful, and a fixed point"
      (lambda ()
        (for-each
         (lambda (row)
           (let* ((n (uri-normalize ((cadr row) (caddr row))))
                  (label (string-append (car row) " \"" (caddr row) "\"")))
             (check (string-append label ": renders faithfully") (renders-faithfully? n))
             (check (string-append label ": normalize is idempotent")
                    (same-uri? (uri-normalize n) n))))
         CORPUS)))
    (harness-case "every resolved target, against the base and against foo:/a"
      (lambda ()
        (for-each
         (lambda (base)
           (for-each
            (lambda (v)
              (let ((t (uri-resolve base (rv-reference v))))
                (check (string-append base " + \"" (rv-reference v) "\": renders faithfully")
                       (renders-faithfully? t))))
            (resolution-vectors RESOLUTION)))
         (list BASE "foo:/a" "foo:a/b"))))))

;;; --- uri=? ---------------------------------------------------------------------
(harness-group "uri=?: equal after normalization"
  (lambda ()
    (harness-case "the comparison table"
      (lambda ()
        (for-each
         (lambda (row)
           (check-equal (string-append (car row) " vs " (cadr row))
                        (uri=? (car row) (cadr row)) (caddr row)))
         '(("HTTP://a/%7Euser" "http://a/~user" #t)
           ("http://Ex%41mple.com/" "http://example.COM/" #t)
           ("http://a/./b/../c" "http://a/c" #t)
           ("http://a/%2f" "http://a/%2F" #t)
           ("http://a/b" "http://a/c" #f)
           ("http://a/%2F" "http://a//" #f)       ; an encoded / is not a separator
           ("http://a" "http://a/" #f)            ; no scheme-based normalization
           ("http://a:80/" "http://a/" #f)
           ("http://a?" "http://a" #f)            ; absent is not empty
           ("http://U@a/" "http://u@a/" #f)))))   ; userinfo is case-sensitive
    (harness-case "a Uri and a string compare"
      (lambda ()
        (check "Uri, string" (uri=? (string->uri "HTTP://A/") "http://a/"))
        (check "string, Uri" (uri=? "http://a/" (string->uri "HTTP://A/")))))
    (harness-case "an invalid string raises"
      (lambda ()
        (check-uri-error "uri=? \"a b\"" (lambda () (uri=? "http://a/" "a b"))
                         'uri=? 'invalid-pchar 1 "a b")))))

;;; --- the way down, and back ------------------------------------------------------
(define (bv s) (string->utf8 s))

(harness-group "uri->components and components->uri"
  (lambda ()
    (harness-case "down and back up is the identity"
      (lambda ()
        (for-each
         (lambda (s)
           (check-equal s (uri->string (components->uri (uri->components (string->uri-reference s)))) s))
         '("http://u@a:1/p?q#f" "//a" "g" "" "http://a?" "file:///x"))))
    (harness-case "uri->components hands out copies"
      (lambda ()
        (let* ((u (string->uri "http://a/path")) (c (uri->components u)))
          (bytevector-u8-set! (uri-components-path c) 1 (char->integer #\X))
          (check-equal "the Uri is unchanged" (uri-path u) "/path"))))
    (harness-case "components->uri keeps no reference to its argument"
      (lambda ()
        (let* ((c (make-uri-components (bv "http") (bv "a") (bv "/path") #f #f))
               (u (components->uri c)))
          (bytevector-u8-set! (uri-components-path c) 1 (char->integer #\X))
          (check-equal "the Uri is unchanged" (uri-path u) "/path"))))
    (harness-case "a set that would re-parse as a different URI is refused"
      (lambda ()
        (check-uri-error "{#f #f \"a:b\"} would gain a scheme"
                         (lambda () (components->uri (make-uri-components #f #f (bv "a:b") #f #f)))
                         'components->uri 'ambiguous-components 0 "a:b")
        (check-uri-error "{#f #f \"//x\"} would gain an authority"
                         (lambda () (components->uri (make-uri-components #f #f (bv "//x") #f #f)))
                         'components->uri 'ambiguous-components 0 "//x")))
    (harness-case "an invalid set is refused with the low layer's reason"
      (lambda ()
        (check-uri-error "a space in the host"
                         (lambda () (components->uri (make-uri-components (bv "http") (bv "a b") (bv "") #f #f)))
                         'components->uri 'invalid-reg-name 8 "http://a b")))
    (harness-case "a wrong argument is an assertion naming the caller"
      (lambda ()
        (check-refuses "components->uri of a string" (lambda () (components->uri "http://a"))
                       'components->uri)
        (check-refuses "uri->components of a string" (lambda () (uri->components "http://a"))
                       'uri->components)))))

(harness-finish)
