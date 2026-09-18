#!r6rs
;;; unit.grammar -- the URI scanner (modes 1 & 2), judged against the split
;;; oracle. The scanner's ABI is the spans plus the `on-rooted` verdict; the
;;; expected decompositions were derived from RFC 3986's ABNF independently of
;;; this grammar (the M2 split oracle), so a bug shared between grammar and test
;;; cannot hide.
;;;
;;; SLICE ① reads the whole authority as one `host` span (userinfo/host/port are
;;; Slice ①b), so `host` here is the authority substring. A path-absolute's
;;; leading `/` is dropped from the `path` span and recovered by `on-rooted`
;;; (decision 0018): the path COMPONENT is `(if rooted "/" "") ++ path-span`, and
;;; both the raw span and that reconstruction are asserted.
(import (rnrs)
        (uri test harness)
        (uri grammar)
        (uri vocabulary)
        (byte-machine verify)
        (byte-machine interpret)
        (byte-machine runtime))

(define M (make-uri-scanner-machine))
(define V (verify-machine M))
(define CM (and (verification-ok? V) (make-interpreted-machine V)))

(define (bytes->str bv from to)
  (let ((s (make-bytevector (- to from)))) (bytevector-copy! bv from s 0 (- to from)) (utf8->string s)))

;; parse : Nat String [chunk] -> parse-record (a tagged alist)
;; A span is PRESENT iff its COMPLETION callback fires (decision 0008 item 5:
;; the completion is the one signal that is always exactly once, because an empty
;; data fragment is suppressed across a feed boundary). Its bytes are the
;; concatenation of its data fragments in arrival order -- so a span open across
;; several feeds reads back the same as one delivered whole. A span whose
;; completion never fires is absent (#f). `chunk` feeds one byte at a time.
(define (parse mode str . chunk?)
  (let ((frags '()) (completes '()) (rooted #f))
    (define (data-cb name)
      (lambda (p c bv from to) (set! frags (cons (cons name (bytes->str bv from to)) frags)) callback-continue))
    (define (done-cb name)
      (lambda (p c) (set! completes (cons name completes)) callback-continue))
    (define bindings
      (list (list 'on-scheme-data (data-cb 'scheme))   (list 'on-scheme-complete (done-cb 'scheme))
            (list 'on-host-data (data-cb 'host))        (list 'on-host-complete (done-cb 'host))
            (list 'on-path-data (data-cb 'path))        (list 'on-path-complete (done-cb 'path))
            (list 'on-query-data (data-cb 'query))      (list 'on-query-complete (done-cb 'query))
            (list 'on-fragment-data (data-cb 'fragment)) (list 'on-fragment-complete (done-cb 'fragment))
            (list 'on-rooted (lambda (p c) (set! rooted #t) callback-continue))))
    (let* ((p (make-parser CM bindings #f (list (cons 'mode mode))))
           (bv (string->utf8 str))
           (n (bytevector-length bv)))
      (if (and (pair? chunk?) (car chunk?))
          (let loop ((i 0)) (when (< i n) (parser-feed! p bv i (+ i 1)) (loop (+ i 1))))
          (parser-feed! p bv 0 n))
      (let ((r (parser-finish! p)))
        (list (cons 'status (parser-result-status r))
              (cons 'rooted rooted)
              (cons 'frags (reverse frags))
              (cons 'completes completes)
              (cons 'err (and (parser-result-error r)
                              (cons (parser-error-code (parser-result-error r))
                                    (parser-error-offset (parser-result-error r))))))))))

;; accessors over a parse-record
(define (pr-status r) (cdr (assq 'status r)))
(define (pr-rooted r) (cdr (assq 'rooted r)))
(define (pr-err r) (cdr (assq 'err r)))
;; #f = absent (completion never fired); otherwise the concatenated fragments.
(define (pr-span r name)
  (and (memq name (cdr (assq 'completes r)))
       (apply string-append
              (map cdr (filter (lambda (c) (eq? (car c) name)) (cdr (assq 'frags r)))))))
;; the path COMPONENT collect will build, from the raw span and the verdict
(define (pr-path r)
  (let ((s (pr-span r 'path))) (and s (if (pr-rooted r) (string-append "/" s) s))))

(harness-begin "unit.grammar")

(harness-case "the machine verifies"
  (lambda ()
    (check "verified" (verification-ok? V))
    (unless (verification-ok? V)
      (for-each (lambda (d) (check-fail "diagnostic"
                              (string-append (symbol->string (diagnostic-code d)) " @ "
                                             (symbol->string (diagnostic-node d)))))
                (verification-diagnostics V)))))

;;; --- the mode field (decision 0004) -------------------------------------
(harness-group "modes"
  (lambda ()
    (harness-case "mode 0 (unset) refuses at offset 0"
      (lambda ()
        (let ((r (parse 0 "http://a/")))
          (check-equal "status" (pr-status r) 'error)
          (check-equal "code"   (car (pr-err r)) 'mode-unset)
          (check-equal "offset" (cdr (pr-err r)) 0))))
    ;; Mode 3 is uri-reference and is Slice ②; until then it shares the unset
    ;; arm. This case pins the CURRENT behaviour so the slice that builds mode 3
    ;; has to change it deliberately.
    (harness-case "mode 3 is not yet built and refuses like unset"
      (lambda ()
        (check-equal "code" (car (pr-err (parse 3 "g"))) 'mode-unset)))))

;;; --- the split oracle: modes 1 & 2, every span ---------------------------
;;;
;;; Each row: (mode uri  scheme host path query fragment rooted?). A field is a
;;; string (present, "" = empty) or #f (absent). `path` is the COMPONENT (with
;;; the leading slash restored); `rooted?` pins the raw verdict beneath it.
(define oracle
  '((1 "http://a/b/c/d;p?q"  "http" "a"                     "/b/c/d;p" "q"           #f #f)
    (1 "foo://info@example.com:8042/over/there?name=ferret#nose"
                              "foo"  "info@example.com:8042" "/over/there" "name=ferret" "nose" #f)
    (1 "http://@h/p"          "http" "@h"                    "/p"       #f            #f #f)
    (1 "http://h:/p"          "http" "h:"                    "/p"       #f            #f #f)
    (1 "http:///p"            "http" ""                      "/p"       #f            #f #f)
    (1 "http:/p"              "http" #f                      "/p"       #f            #f #t)
    (1 "mailto:fred@example.com" "mailto" #f                 "fred@example.com" #f    #f #f)
    (1 "urn:oasis:names:x"    "urn"  #f                      "oasis:names:x" #f       #f #f)
    (1 "http://a"             "http" "a"                     ""         #f            #f #f)
    (1 "http://a?"            "http" "a"                     ""         ""            #f #f)
    (1 "http://a#"            "http" "a"                     ""         #f            "" #f)
    (1 "http://a?q"           "http" "a"                     ""         "q"           #f #f)
    ;; content transparency: a query holds "/" and "?" and ends only at "#"; a
    ;; fragment holds "/" and "?" and ends only at EOF.
    (1 "http://a/p?x/y?z#f/g?h" "http" "a"                   "/p"       "x/y?z"       "f/g?h" #f)
    (1 "http://a#x?y/z"        "http" "a"                    ""         #f            "x?y/z" #f)
    (1 "telnet://192.0.2.16:80/" "telnet" "192.0.2.16:80"   "/"        #f            #f #f)
    (1 "ldap://[2001:db8::7]/c=GB?objectClass?one"
                              "ldap" "[2001:db8::7]"         "/c=GB"    "objectClass?one" #f #f)
    (1 "http://a/p?q#f"       "http" "a"                     "/p"       "q"           "f" #f)
    (2 "/b/c/d;p?q"           #f     #f                      "/b/c/d;p" "q"           #f #t)
    (2 "g"                    #f     #f                      "g"        #f            #f #f)
    (2 "//h/p"               #f     "h"                      "/p"       #f            #f #f)
    (2 "?q"                  #f     #f                      ""         "q"           #f #f)
    (2 "#f"                  #f     #f                      ""         #f            "f" #f)
    (2 ""                    #f     #f                      ""         #f            #f #f)
    (2 "a/b/c"               #f     #f                      "a/b/c"    #f            #f #f)))

(harness-group "split"
  (lambda ()
    (for-each
     (lambda (row)
       (let ((mode (list-ref row 0)) (uri (list-ref row 1))
             (e-scheme (list-ref row 2)) (e-host (list-ref row 3))
             (e-path (list-ref row 4)) (e-query (list-ref row 5))
             (e-frag (list-ref row 6)) (e-rooted (list-ref row 7)))
         (harness-case uri
           (lambda ()
             (let ((r (parse mode uri)))
               (check-equal "status"   (pr-status r) 'finished)
               (check-equal "scheme"   (pr-span r 'scheme) e-scheme)
               (check-equal "host"     (pr-span r 'host) e-host)
               (check-equal "path"     (pr-path r) e-path)
               (check-equal "rooted"   (pr-rooted r) e-rooted)
               (check-equal "query"    (pr-span r 'query) e-query)
               (check-equal "fragment" (pr-span r 'fragment) e-frag))))))
     oracle)))

;;; --- absent is not empty (decision 0008), the load-bearing pairs ---------
(harness-group "absent-is-not-empty"
  (lambda ()
    (harness-case "empty authority (host \"\") is not no authority (host #f)"
      (lambda ()
        (check-equal "///p host empty"  (pr-span (parse 1 "http:///p") 'host) "")
        (check-equal "/p   host absent" (pr-span (parse 1 "http:/p")   'host) #f)))
    (harness-case "empty query is not absent query"
      (lambda ()
        (check-equal "a? query empty" (pr-span (parse 1 "http://a?") 'query) "")
        (check-equal "a  query absent" (pr-span (parse 1 "http://a") 'query) #f)))
    (harness-case "path is always present, even empty"
      (lambda ()
        (check-equal "//h path empty" (pr-span (parse 2 "//h") 'path) "")
        (check-equal "empty path present" (pr-span (parse 2 "") 'path) "")))))

;;; --- the errors (decision 0009): code AND offset -------------------------
(harness-group "errors"
  (lambda ()
    (harness-case "mode 1 with no colon before a delimiter is scheme-required at the delimiter"
      (lambda ()
        (let ((r (parse 1 "foo/bar")))
          (check-equal "code" (car (pr-err r)) 'scheme-required)
          (check-equal "offset" (cdr (pr-err r)) 3))))
    (harness-case "mode 1 with no colon before EOF is scheme-required at EOF"
      (lambda ()
        (check-equal "offset" (cdr (pr-err (parse 1 "foo"))) 3)))
    (harness-case "mode 2 with a colon in the first segment is scheme-forbidden at the colon"
      (lambda ()
        (let ((r (parse 2 "g:h")))
          (check-equal "code" (car (pr-err r)) 'scheme-forbidden)
          (check-equal "offset" (cdr (pr-err r)) 1))))
    ;; A ":" AFTER the first "/" is a legal pchar in mode 2, not scheme-forbidden.
    (harness-case "a colon after the first slash in mode 2 is legal"
      (lambda ()
        (let ((r (parse 2 "a/b:c")))
          (check-equal "status" (pr-status r) 'finished)
          (check-equal "path" (pr-path r) "a/b:c"))))))

;;; --- chunk-invariance (the property lane, in miniature) ------------------
;;; A parse that reaches no error produces the same spans however the bytes
;;; arrive. Fed one byte at a time, the hardest cases must decompose identically.
(harness-group "chunk-invariance"
  (lambda ()
    (for-each
     (lambda (row)
       (let ((mode (list-ref row 0)) (uri (list-ref row 1)))
         (harness-case (string-append "byte-by-byte: " uri)
           (lambda ()
             (let ((whole (parse mode uri)) (drip (parse mode uri #t)))
               (check-equal "scheme"   (pr-span drip 'scheme) (pr-span whole 'scheme))
               (check-equal "host"     (pr-span drip 'host) (pr-span whole 'host))
               (check-equal "path"     (pr-path drip) (pr-path whole))
               (check-equal "rooted"   (pr-rooted drip) (pr-rooted whole))
               (check-equal "query"    (pr-span drip 'query) (pr-span whole 'query))
               (check-equal "fragment" (pr-span drip 'fragment) (pr-span whole 'fragment)))))))
     oracle)))

;;; --- the grammar declares only names the vocabulary knows ----------------
(harness-case "every span and error the grammar uses is in the vocabulary"
  (lambda ()
    ;; A cross-check so the grammar and (uri vocabulary) cannot drift: the five
    ;; spans Slice ① opens and the four errors it declares must all be vocabulary
    ;; entries (mode-unset/scheme-required/scheme-forbidden/unexpected-eof).
    (for-each (lambda (s) (check (string-append (symbol->string s) " is a span")
                                 (uri-span-name? s)))
              '(scheme host path query fragment))
    (for-each (lambda (e) (check (string-append (symbol->string e) " is an error code")
                                 (uri-error-code? e)))
              '(mode-unset scheme-required scheme-forbidden unexpected-eof))
    ;; and every callback the grammar binds is a vocabulary callback name, so the
    ;; grammar's declaration list cannot drift from the table the harness and an
    ;; embedder read.
    (for-each (lambda (cb) (check (string-append (symbol->string cb) " is a callback")
                                  (uri-callback-name? cb)))
              (append (apply append
                             (map (lambda (s) (list (uri-span-data-callback s)
                                                   (uri-span-complete-callback s)))
                                  '(scheme host path query fragment)))
                      '(on-rooted)))))

(harness-finish)
