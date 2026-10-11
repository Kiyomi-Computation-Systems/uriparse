#!r6rs
;;; unit.generator-abi -- the pinned generator is importable, emits the ABI this
;;; repository targets, and the machines it builds actually run.
;;;
;;; The generated ABI is 9, asserted in TWO places -- a lane that reads it from a
;;; freshly emitted machine (this one), and a lane that reads it from the
;;; committed artifact (determinism.generated-artifact). Two checks, neither able
;;; to go stale quietly. The ABI target could otherwise rot unnoticed, because it
;;; would live only in prose; a lane cannot.
;;;
;;; The machine below is a SMOKE machine -- the smallest one that exercises a
;;; byte dispatch, an accept, a reject and an EOF route. It is NOT a URI grammar:
;;; this lane answers "is the dependency wired up and speaking ABI 9", and
;;; nothing about RFC 3986. It declares NO field, so it emits no settable
;;; metadata table and the ABI literal is the only thing about its text that a
;;; version bump would move: a machine with a settable field would
;;; conflate "what ABI does the pin speak" with "does the field feature work".
(import (rnrs)
        (uri test harness)
        (byte-machine graph)
        (byte-machine verify)
        (byte-machine compile)
        (byte-machine interpret)
        (byte-machine runtime))

;; The generated-runtime ABI the pinned runtime speaks: `current-abi-version` in
;; `(byte-machine runtime)`. Read from the emitted text
;; below, never remembered: if the pin ever moves and the ABI with it, this
;; reddens here rather than at load time.
(define expected-abi 9)

(define (substring-at? s i sub)
  (and (<= (+ i (string-length sub)) (string-length s))
       (string=? (substring s i (+ i (string-length sub))) sub)))

(define (find-substring s sub)
  (let loop ((i 0))
    (cond ((> (+ i (string-length sub)) (string-length s)) #f)
          ((substring-at? s i sub) i)
          (else (loop (+ i 1))))))

;; The integer that follows `sub` in `s`, or #f.
(define (integer-after s sub)
  (let ((at (find-substring s sub)))
    (and at
         (let* ((start (+ at (string-length sub)))
                (end (let scan ((j start))
                       (if (and (< j (string-length s))
                                (char<=? #\0 (string-ref s j))
                                (char<=? (string-ref s j) #\9))
                           (scan (+ j 1))
                           j))))
           (and (> end start) (string->number (substring s start end)))))))

;; start --0x41--> accept (stop)
;;       --other-> reject (error unexpected-byte)
;;       --EOF---> eof-stop (error unexpected-eof)
(define (smoke-machine)
  (make-machine 'abi-smoke 'start '() '() '()
    (list (make-error-declaration 'eof 'unexpected-eof "unexpected end of input" #f)
          (make-error-declaration 'rejected 'unexpected-byte "expected 0x41" #f))
    (list (make-byte-dispatch-node 'start
            (list (make-byte-case (make-exact-byte-matcher #x41)
                                  (make-edge 'accept 'advance) #f))
            (make-edge 'reject 'reexecute) 'eof-stop #f)
          (make-stop-node 'accept #f)
          (make-error-node 'reject 'rejected #f)
          (make-error-node 'eof-stop 'eof #f))
    'eof #f))

(define (rendered)
  (utf8->string (render-machine (compile-machine (smoke-machine) '()) 'smoke-parser)))

(harness-begin "unit.generator-abi")

(harness-group "the pinned generator"
  (lambda ()
    (harness-case "a machine built through the public API verifies and compiles"
      (lambda ()
        (check "compilation-ok?" (compilation-ok? (compile-machine (smoke-machine) '())))))

    (harness-case "the emitted library names the ABI this repository targets"
      (lambda ()
        (check-equal "abi version"
                     (integer-after (rendered) "(byte-machine-make-compiled-machine ")
                     expected-abi)))

    (harness-case "the emitted library imports the runtime and nothing else above it"
      (lambda ()
        ;; A generated parser depends on
        ;; `(byte-machine runtime)` and nothing else upstream, so a deployed
        ;; consumer ships without the compiler.
        (let ((text (rendered)))
          (check "imports the runtime"    (find-substring text "(byte-machine runtime)"))
          (check "not the builder"        (not (find-substring text "(byte-machine graph)")))
          (check "not the compiler"       (not (find-substring text "(byte-machine compile)")))
          (check "not the verifier"       (not (find-substring text "(byte-machine verify)")))
          (check "not the interpreter"    (not (find-substring text "(byte-machine interpret)"))))))

    (harness-case "the retired ABI constructors are not emitted"
      (lambda ()
        ;; The tombstoned /v1 and /v2 constructors refuse every version;
        ;; emitting either would mean the pin moved somewhere unexpected.
        (let ((text (rendered)))
          (check "no /v1" (not (find-substring text "byte-machine-make-compiled-machine/v1")))
          (check "no /v2" (not (find-substring text "byte-machine-make-compiled-machine/v2"))))))

    (harness-case "emission is byte-identical across two renderings"
      (lambda ()
        ;; The determinism the committed-artifact lane will rely on, proven here
        ;; on a machine with no committed golden of its own.
        (check-equal "deterministic"
                     (render-machine (compile-machine (smoke-machine) '()) 'smoke-parser)
                     (render-machine (compile-machine (smoke-machine) '()) 'smoke-parser))))))

(harness-group "a machine from the pinned generator runs"
  (lambda ()
    (harness-case "the accepted byte stops after one byte"
      (lambda ()
        (let* ((cm (make-interpreted-machine (verify-machine (smoke-machine))))
               (r (parser-feed! (make-parser cm '() #f) (u8-list->bytevector '(#x41)) 0 1)))
          (check-equal "status" (parser-result-status r) 'stopped)
          (check-equal "consumed" (parser-result-consumed r) 1))))

    (harness-case "any other byte is rejected at that byte"
      (lambda ()
        (let* ((cm (make-interpreted-machine (verify-machine (smoke-machine))))
               (r (parser-feed! (make-parser cm '() #f) (u8-list->bytevector '(#x42)) 0 1)))
          (check-equal "status" (parser-result-status r) 'error)
          (check-equal "code" (parser-error-code (parser-result-error r)) 'unexpected-byte)
          (check-equal "offset" (parser-error-offset (parser-result-error r)) 0))))

    (harness-case "end of input before the byte is unexpected-eof"
      (lambda ()
        (let* ((cm (make-interpreted-machine (verify-machine (smoke-machine))))
               (r (parser-finish! (make-parser cm '() #f))))
          (check-equal "status" (parser-result-status r) 'error)
          (check-equal "code" (parser-error-code (parser-result-error r)) 'unexpected-eof))))))

(harness-finish)
