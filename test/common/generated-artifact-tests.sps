#!r6rs
;;; determinism.generated-artifact -- the committed `(generated uri-scanner)` is
;;; what this project ships, and this lane guards it three ways (decision 0002
;;; items 3-4):
;;;   1. re-emitting the grammar reproduces the committed bytes exactly, so a
;;;      grammar edit not followed by `make parser-refresh` reddens here;
;;;   2. the committed text declares generated ABI 9, read out, never remembered;
;;;   3. the committed artifact -- run as itself, not re-derived -- decomposes
;;;      the oracle vectors identically to the reference interpreter built from
;;;      the same grammar. The check reads the ARTIFACT's own code, which is the
;;;      only thing a refresh could leave stale.
(import (rnrs)
        (uri test harness)
        (uri grammar)
        (generated uri-scanner)
        (byte-machine compile)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(define (find-substring s sub)
  (let ((sn (string-length s)) (bn (string-length sub)))
    (let loop ((i 0))
      (cond ((> (+ i bn) sn) #f)
            ((string=? (substring s i (+ i bn)) sub) i)
            (else (loop (+ i 1)))))))

(define (integer-after s sub)
  (let ((at (find-substring s sub)))
    (and at (let* ((start (+ at (string-length sub)))
                   (end (let scan ((j start))
                          (if (and (< j (string-length s))
                                   (char<=? #\0 (string-ref s j)) (char<=? (string-ref s j) #\9))
                              (scan (+ j 1)) j))))
              (and (> end start) (string->number (substring s start end)))))))

(define (bytes->str bv from to)
  (let ((s (make-bytevector (- to from)))) (bytevector-copy! bv from s 0 (- to from)) (utf8->string s)))

(define (bv-append a b)
  (let* ((la (bytevector-length a)) (lb (bytevector-length b)) (r (make-bytevector (+ la lb))))
    (bytevector-copy! a 0 r 0 la) (bytevector-copy! b 0 r la lb) r))

;; The artifact the emitter writes: the `#!r6rs` line then the rendered library.
(define (emit)
  (bv-append (string->utf8 "#!r6rs\n")
             (render-machine (compile-machine (make-uri-scanner-machine) '()) 'uri-scanner-machine)))

;; decompose : CompiledMachine Nat String -> canonical result
;; The two executors are compared through this, so any divergence surfaces by
;; vector rather than as a crash.
(define (decompose cm mode str)
  (let ((frags '()) (completes '()) (rooted #f))
    (define (data-cb name) (lambda (p c bv from to) (set! frags (cons (cons name (bytes->str bv from to)) frags)) callback-continue))
    (define (done-cb name) (lambda (p c) (set! completes (cons name completes)) callback-continue))
    (define bindings
      (list (list 'on-scheme-data (data-cb 'scheme)) (list 'on-scheme-complete (done-cb 'scheme))
            (list 'on-host-data (data-cb 'host)) (list 'on-host-complete (done-cb 'host))
            (list 'on-path-data (data-cb 'path)) (list 'on-path-complete (done-cb 'path))
            (list 'on-query-data (data-cb 'query)) (list 'on-query-complete (done-cb 'query))
            (list 'on-fragment-data (data-cb 'fragment)) (list 'on-fragment-complete (done-cb 'fragment))
            (list 'on-rooted (lambda (p c) (set! rooted #t) callback-continue))))
    (let* ((p (make-parser cm bindings #f (list (cons 'mode mode))))
           (bv (string->utf8 str)))
      (parser-feed! p bv 0 (bytevector-length bv))
      (let ((r (parser-finish! p)))
        (list (parser-result-status r) rooted (reverse frags) (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) completes)
              (and (parser-result-error r)
                   (cons (parser-error-code (parser-result-error r)) (parser-error-offset (parser-result-error r)))))))))

(define committed-bytes
  (adapter-file-bytes (adapter-environment-variable "URI_GENERATED_PARSER")))

;; The interpreter (reference) and the committed artifact (shipped).
(define interp (make-interpreted-machine (verify-machine (make-uri-scanner-machine))))

;; The full oracle spread, so a compile-vs-interpret divergence on any shape --
;; userinfo, empty port, empty query/fragment, mode-2 legal colon -- is caught.
(define vectors
  '((1 "http://a/b/c/d;p?q") (1 "foo://info@example.com:8042/over/there?name=ferret#nose")
    (1 "http://@h/p") (1 "http://h:/p") (1 "http:///p") (1 "http:/p")
    (1 "mailto:fred@example.com") (1 "http://a") (1 "http://a?") (1 "http://a#")
    (1 "http://a/p?q#f") (1 "ldap://[2001:db8::7]/c=GB?objectClass?one")
    (2 "/b/c/d;p?q") (2 "g") (2 "//h/p") (2 "?q") (2 "#f") (2 "") (2 "a/b:c")
    (1 "foo/bar") (1 "foo") (2 "g:h") (0 "x")))

(harness-begin "determinism.generated-artifact")

(harness-case "re-emitting the grammar reproduces the committed artifact"
  (lambda ()
    (let ((fresh (emit)))
      ;; A boolean check, not check-equal: the artifact is ~22 KB, and printing
      ;; two of them on a mismatch buries the one fact that matters.
      (check (string-append "byte-identical (fresh " (number->string (bytevector-length fresh))
                            " vs committed " (number->string (bytevector-length committed-bytes)) ")")
             (bytevector=? fresh committed-bytes)))))

(harness-case "the committed artifact declares generated ABI 9"
  (lambda ()
    (check-equal "abi" (integer-after (utf8->string committed-bytes)
                                      "(byte-machine-make-compiled-machine ") 9)))

(harness-case "the committed artifact imports the runtime and nothing above it"
  (lambda ()
    (let ((text (utf8->string committed-bytes)))
      (check "imports runtime" (find-substring text "(byte-machine runtime)"))
      (check "not the compiler" (not (find-substring text "(byte-machine compile)")))
      (check "not the builder"  (not (find-substring text "(byte-machine graph)"))))))

;; THE GATE READS THE ARTIFACT. uri-scanner-machine is the committed library's
;; own compiled machine; running it and the interpreter through `decompose` and
;; comparing is what proves the shipped code, not a re-derivation, is correct.
(harness-group "the committed artifact agrees with the interpreter"
  (lambda ()
    (for-each
     (lambda (v)
       (harness-case (string-append "m" (number->string (car v)) " " (cadr v))
         (lambda ()
           (check-equal "same decomposition"
                        (decompose uri-scanner-machine (car v) (cadr v))
                        (decompose interp (car v) (cadr v))))))
     vectors)))

(harness-finish)
