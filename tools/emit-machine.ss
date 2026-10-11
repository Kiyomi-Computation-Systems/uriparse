;;; Emit this project's URI scanner as a checked-in derived artifact.
;;;
;;; Usage:
;;;   chez --libdirs <src>:<generator-src> --script tools/emit-machine.ss \
;;;        --output src/generated/uri-scanner.sls
;;;
;;; This is the ONLY way the artifact is written. `make parser-refresh` runs it
;;; and `uri.determinism.generated-artifact.chez.source` runs it again and
;;; compares bytes, so a grammar edit that is not followed by a refresh reddens
;;; rather than shipping an artifact that does not match its source.
;;;
;;; The emitted library is `(generated uri-scanner)` -- the collection is the
;;; machine's own name, chosen at `make-machine` -- and it imports
;;; `(byte-machine runtime)` and nothing above it. This
;;; script imports `(chezscheme)` for file I/O; it is build tooling, not the
;;; shipped surface, so the `(chezscheme)`-free rule for `src/` does not reach it.
(import (rnrs) (chezscheme) (uri grammar) (byte-machine compile))

(define (die message)
  (display (string-append "uri-emit: " message "\n") (current-error-port))
  (exit 2))

(define (flag-value name)
  (let loop ((args (cdr (command-line))))
    (cond ((null? args) #f)
          ((string=? (car args) name)
           (if (null? (cdr args))
               (die (string-append name " needs a value"))
               (cadr args)))
          (else (loop (cdr args))))))

(define out (or (flag-value "--output") (die "--output is required")))

(define (bv-append a b)
  (let* ((la (bytevector-length a)) (lb (bytevector-length b)) (r (make-bytevector (+ la lb))))
    (bytevector-copy! a 0 r 0 la) (bytevector-copy! b 0 r la lb) r))

;; A `#!r6rs` line leads the artifact so it reads on every implementation the
;; family targets (Racket needs it, Chez and Guile accept it) -- the
;; shipped file is the one that most needs to be portable, and render-machine
;; emits no such line. The determinism lane prepends the same prefix, so the two
;; cannot drift. The library form follows, so the ABI read is unaffected.
(define body
  (render-machine (compile-machine (make-uri-scanner-machine) '())
                  'uri-scanner-machine))
(define bytes (bv-append (string->utf8 "#!r6rs\n") body))

(when (file-exists? out) (delete-file out))
(call-with-port (open-file-output-port out (file-options no-fail))
  (lambda (p) (put-bytevector p bytes)))
(display (string-append "uri-emit: wrote " (number->string (bytevector-length bytes))
                        " bytes to " out "\n"))
