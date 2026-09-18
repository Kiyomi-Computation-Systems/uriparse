#!r6rs
;;; (uri test ratchet): which RFC 3986 vectors this project claims to resolve.
;;;
;;; A TWO-WAY GATE (decision 0005; the sibling's decision 0008 item 6 is the
;;; same rule). A manifest that only fails when a passing vector breaks is a
;;; TODO list: it lets a vector start passing unnoticed, and a milestone whose
;;; exit criterion can drift upward without anyone noticing has stopped being
;;; falsifiable. So there are three violations, not one:
;;;
;;;   * a `passing` row whose vector failed   -- a regression
;;;   * a `not-yet` row whose vector passed   -- an unrecorded gain
;;;   * an id in one set and not the other    -- an orphan or a stale row
;;;
;;; The third is what keeps the first two honest. Without it, deleting a
;;; vector's row is a way to make either violation disappear.
;;;
;;; PURE. `ratchet-load` is the only procedure here that touches a port, and it
;;; does nothing but hand its lines to `ratchet-parse`, so every rule above is
;;; testable with a list of strings.
(library (uri test ratchet)
  (export ratchet-parse ratchet-load
          ratchet-entries ratchet-entry? ratchet-entry-id ratchet-entry-status
          ratchet-status ratchet-violations
          ratchet-statuses
          ratchet-error? ratchet-error-detail)
  (import (rnrs))

  (define-condition-type &ratchet &error
    make-ratchet-error ratchet-error?
    (detail ratchet-error-detail))

  (define (refuse who detail)
    (raise (condition (make-ratchet-error detail)
                      (make-who-condition who)
                      (make-message-condition detail))))

  (define-record-type ratchet-entry (fields id status))

  ;; The only two words a row may carry. A third would have to mean something,
  ;; and every meaning anyone has wanted here so far is one of these two with a
  ;; note beside it -- so a new word is added by amending this list, not by a
  ;; row that reads as neither and is silently ignored.
  (define ratchet-statuses '(passing not-yet))

  ;; --- a small line reader, rather than a general one ----------------------
  ;;
  ;; A manifest row is `<status><space(s)><id>`, and an id may contain anything
  ;; but whitespace -- including the `/`, `;`, `?` and `#` that RFC 3986's own
  ;; references are full of. Splitting on the FIRST run of whitespace and
  ;; taking the whole remainder is what keeps `5.4.2/g;x=1/../y` intact.

  (define (whitespace? c) (or (char=? c #\space) (char=? c #\tab)))

  (define (trim s)
    (let* ((n (string-length s))
           (a (let loop ((i 0)) (if (and (< i n) (whitespace? (string-ref s i)))
                                    (loop (+ i 1)) i)))
           (b (let loop ((i n)) (if (and (> i a) (whitespace? (string-ref s (- i 1))))
                                    (loop (- i 1)) i))))
      (substring s a b)))

  ;; (values status-text id-text) or (values #f #f) for a blank or comment row.
  (define (split-row line)
    (let ((s (trim line)))
      (if (or (string=? s "") (char=? (string-ref s 0) #\#))
          (values #f #f)
          (let* ((n (string-length s))
                 (end (let loop ((i 0))
                        (if (or (= i n) (whitespace? (string-ref s i))) i (loop (+ i 1))))))
            (values (substring s 0 end) (trim (substring s end n)))))))

  ;; ratchet-parse : (Listof String) -> (Listof RatchetEntry)
  (define (ratchet-parse lines)
    (let loop ((ls lines) (acc '()))
      (if (null? ls)
          (reverse acc)
          (let-values (((status id) (split-row (car ls))))
            (cond
              ((not status) (loop (cdr ls) acc))
              ((string=? id "")
               (refuse 'ratchet-parse
                       (string-append "row '" (trim (car ls)) "' names no vector")))
              (else
               (let ((sym (string->symbol status)))
                 (unless (memq sym ratchet-statuses)
                   (refuse 'ratchet-parse
                           (string-append "row '" (trim (car ls))
                                          "' has status '" status
                                          "', which is neither passing nor not-yet")))
                 (loop (cdr ls) (cons (make-ratchet-entry id sym) acc)))))))))

  (define (ratchet-entries r) r)

  (define (ratchet-load path)
    (let ((p (open-file-input-port path
                                   (file-options)
                                   (buffer-mode block)
                                   (native-transcoder))))
      (let loop ((acc '()))
        (let ((l (get-line p)))
          (if (eof-object? l)
              (begin (close-port p) (ratchet-parse (reverse acc)))
              (loop (cons l acc)))))))

  ;; ratchet-status : Ratchet String -> (Option Symbol)
  (define (ratchet-status r id)
    (let loop ((es (ratchet-entries r)))
      (cond ((null? es) #f)
            ((string=? (ratchet-entry-id (car es)) id) (ratchet-entry-status (car es)))
            (else (loop (cdr es))))))

  ;; ratchet-violations : Ratchet (Listof (Pair String (Option String)))
  ;;                   -> (Listof String)
  ;;
  ;; `results` pairs each vector's id with what the comparator said about it:
  ;; #f for agreement, a diagnostic string for a difference -- the same
  ;; polarity `compare-target` uses, so a caller never has to invert it.
  ;;
  ;; The answer is a list of diagnostics, empty when the manifest and the run
  ;; agree exactly. It is not a boolean: a lane that says only "the ratchet
  ;; moved" makes someone diff two runs to find out how.
  (define (ratchet-violations r results)
    (define (id-of pair) (car pair))
    (define (diagnostic-of pair) (cdr pair))
    (let* ((moved
            (let loop ((rs results) (acc '()))
              (if (null? rs)
                  (reverse acc)
                  (let* ((id (id-of (car rs)))
                         (d (diagnostic-of (car rs)))
                         (status (ratchet-status r id)))
                    (loop (cdr rs)
                          (cond
                            ((not status)
                             (cons (string-append
                                    id ": no manifest row. A vector with no "
                                    "recorded status is neither a claim nor a "
                                    "deferral, so it cannot be either kept or "
                                    "broken.")
                                   acc))
                            ((and (eq? status 'passing) d)
                             (cons (string-append
                                    id ": recorded passing, but it failed -- " d)
                                   acc))
                            ((and (eq? status 'not-yet) (not d))
                             (cons (string-append
                                    id ": recorded not-yet, but it passed. Move "
                                    "the row to passing in the same change that "
                                    "made it pass.")
                                   acc))
                            (else acc)))))))
           ;; A row whose vector is gone. Without this, deleting a vector is a
           ;; way to make either violation above disappear quietly.
           (stale
            (let loop ((es (ratchet-entries r)) (acc '()))
              (if (null? es)
                  (reverse acc)
                  (let ((id (ratchet-entry-id (car es))))
                    (loop (cdr es)
                          (if (let seek ((rs results))
                                (cond ((null? rs) #f)
                                      ((string=? (id-of (car rs)) id) #t)
                                      (else (seek (cdr rs)))))
                              acc
                              (cons (string-append
                                     id ": a manifest row for a vector that was "
                                     "not run. Either the corpus lost it or the "
                                     "row outlived it.")
                                    acc))))))))
      (append moved stale))))
