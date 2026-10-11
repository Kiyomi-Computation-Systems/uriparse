#!r6rs
;;; unit.easy -- (uri easy), parsing and reading: strings in, a record out.
;;;
;;; What is graded here:
;;;   - the three parsers validate (a lenient parse would accept "http://a b/"),
;;;     and a failure is a &uri-error carrying the low layer's reason, a
;;;     CHARACTER offset (the low layer counts bytes) and the input;
;;;   - every field, in both its absent (#f) and its present-empty ("") case;
;;;   - scheme and host come back normalized, while userinfo, authority and the
;;;     record stay raw;
;;;   - decoded readings split before they decode, and decode to strict UTF-8:
;;;     invalid sequences raise instead of becoming U+FFFD;
;;;   - uri-encode then uri-decode is the identity on generated strings;
;;;   - uri-error-reasons is exactly the union of the low layer's code lists
;;;     plus the easy layer's own, so a new low-layer code cannot leak unlisted;
;;;   - a non-string or non-Uri argument is an assertion naming the caller.
;;; Non-ASCII characters are written as \x...; escapes, so this file is ASCII.
(import (rnrs)
        (uri test harness)
        (uri test prng)
        (uri vocabulary)
        (uri charset)
        (uri host)
        (uri easy))

;; raised : (-> Any) -> (Option Condition), the raised object, or #f on return.
(define (raised thunk)
  (guard (e (#t e)) (thunk) #f))

;; check-uri-error : String (-> Any) Symbol Symbol Nat String -> void
(define (check-uri-error label thunk who reason offset input)
  (let ((c (raised thunk)))
    (if (and c (uri-error? c))
        (begin
          (check-equal (string-append label ": reason") (uri-error-reason c) reason)
          (check-equal (string-append label ": offset") (uri-error-offset c) offset)
          (check-equal (string-append label ": input") (uri-error-input c) input)
          (check-equal (string-append label ": who")
                       (and (who-condition? c) (condition-who c)) who)
          (check (string-append label ": not an assertion") (not (assertion-violation? c))))
        (check-fail label "expected a uri-error"))))

;; check-refuses : String (-> Any) Symbol -> void
;; An assertion violation, and the who is the PUBLIC procedure, not whatever
;; R6RS primitive happened to trip over the bad argument first.
(define (check-refuses label thunk who)
  (let ((c (raised thunk)))
    (check-equal (string-append label ": an assertion naming " (symbol->string who))
                 (and c (assertion-violation? c) (who-condition? c) (condition-who c))
                 who)))

(define (set=? a b)
  (and (for-all (lambda (x) (memq x b)) a)
       (for-all (lambda (x) (memq x a)) b)))

(define (no-duplicates? xs)
  (or (null? xs) (and (not (memq (car xs) (cdr xs))) (no-duplicates? (cdr xs)))))

(harness-begin "unit.easy")

;;; --- parsing ---------------------------------------------------------------
(harness-group "the three parsers"
  (lambda ()
    (harness-case "each mode accepts its own form"
      (lambda ()
        (check "string->uri, absolute" (uri? (string->uri "http://a/b")))
        (check "string->uri-reference, relative" (uri? (string->uri-reference "g")))
        (check "string->uri-reference, absolute" (uri? (string->uri-reference "http://a")))
        (check "string->relative-ref, relative" (uri? (string->relative-ref "../g")))
        (check "uri? is false for a string" (not (uri? "http://a")))))
    (harness-case "each mode refuses what it must"
      (lambda ()
        (check-uri-error "string->uri \"g\"" (lambda () (string->uri "g"))
                         'string->uri 'scheme-required 1 "g")
        (check-uri-error "string->uri \"\"" (lambda () (string->uri ""))
                         'string->uri 'scheme-required 0 "")
        (check-uri-error "string->relative-ref \"http://a\""
                         (lambda () (string->relative-ref "http://a"))
                         'string->relative-ref 'scheme-forbidden 4 "http://a")))
    ;; The easy layer validates. uri-parse alone accepts all of these.
    (harness-case "parsing validates: charset, host and port"
      (lambda ()
        (check-uri-error "a space in the host" (lambda () (string->uri "http://a b/"))
                         'string->uri 'invalid-reg-name 8 "http://a b/")
        (check-uri-error "a space in the path"
                         (lambda () (string->uri-reference "http://a/b c"))
                         'string->uri-reference 'invalid-pchar 10 "http://a/b c")
        (check-uri-error "a malformed %" (lambda () (string->uri "http://a/%zz"))
                         'string->uri 'invalid-pct-encoded 9 "http://a/%zz")
        (check-uri-error "a letter in the port" (lambda () (string->uri "http://a:8x/"))
                         'string->uri 'invalid-port 10 "http://a:8x/")
        (check-uri-error "an unterminated IP-literal" (lambda () (string->uri "http://[::1"))
                         'string->uri 'invalid-ip-literal 7 "http://[::1")))
    ;; The low layer reports byte offsets into UTF-8. These inputs fail AFTER a
    ;; non-ASCII character, where bytes and characters differ: "\xE9;" is two
    ;; bytes and "\x1F600;" four, so the byte offsets are 2 and 4.
    (harness-case "offsets count characters, not bytes"
      (lambda ()
        (check-uri-error "e-acute then a colon" (lambda () (string->relative-ref "\xE9;:b"))
                         'string->relative-ref 'scheme-forbidden 1 "\xE9;:b")
        (check-uri-error "an astral character then a colon"
                         (lambda () (string->relative-ref "\x1F600;:b"))
                         'string->relative-ref 'scheme-forbidden 1 "\x1F600;:b")))
    (harness-case "uri-string? answers without raising"
      (lambda ()
        (check "absolute, default mode" (uri-string? "http://a"))
        (check "relative is not a uri" (not (uri-string? "g")))
        (check "relative is a uri-reference" (uri-string? "g" 'uri-reference))
        (check "relative is a relative-ref" (uri-string? "g" 'relative-ref))
        (check "an absolute is not a relative-ref" (not (uri-string? "http://a" 'relative-ref)))
        (check "it validates" (not (uri-string? "http://a b/")))))))

;;; --- the error condition ---------------------------------------------------
(harness-group "the error condition"
  (lambda ()
    (harness-case "a uri-error prints usefully: its message names reason and offset"
      (lambda ()
        (let ((c (raised (lambda () (string->uri "http://a b/")))))
          (check "it carries a message" (message-condition? c))
          (check-equal "the message" (and (message-condition? c) (condition-message c))
                       "invalid-reg-name at 8"))))
    (harness-case "uri-error-reasons is the low layer's codes plus the easy layer's own"
      (lambda ()
        (let ((expected (append (remq 'mode-unset uri-error-codes)
                                uri-charset-error-codes
                                uri-host-error-codes
                                '(invalid-utf-8))))
          (check "no duplicates" (no-duplicates? uri-error-reasons))
          (check "the same set" (set=? uri-error-reasons expected))
          ;; mode-unset cannot arise: every parser picks its mode.
          (check "mode-unset is not a reason" (not (memq 'mode-unset uri-error-reasons))))))))

;;; --- fields ----------------------------------------------------------------
;; Each row: (field-name accessor input expected), parsed as a uri-reference.
(define FIELD-ROWS
  `(("scheme" ,uri-scheme "http://a" "http")
    ("scheme" ,uri-scheme "//a" #f)
    ("authority" ,uri-authority "http://u@a:1" "u@a:1")
    ("authority" ,uri-authority "file:///x" "")
    ("authority" ,uri-authority "mailto:a@b" #f)
    ("userinfo" ,uri-userinfo "http://u@a" "u")
    ("userinfo" ,uri-userinfo "http://@a" "")
    ("userinfo" ,uri-userinfo "http://a" #f)
    ("userinfo" ,uri-userinfo "mailto:a@b" #f)
    ("host" ,uri-host "http://a" "a")
    ("host" ,uri-host "file:///x" "")
    ("host" ,uri-host "mailto:a@b" #f)
    ("host" ,uri-host "http://u@a:1" "a")
    ("host" ,uri-host "http://[::1]:443/" "[::1]")
    ("port" ,uri-port "http://a:8080" 8080)
    ("port" ,uri-port "http://a:" #f)
    ("port" ,uri-port "http://a" #f)
    ("port" ,uri-port "http://a:080" 80)
    ("port" ,uri-port "http://a:99999" 99999)
    ("port" ,uri-port "http://[::1]:443" 443)
    ("port" ,uri-port "http://[::1]" #f)
    ("port" ,uri-port "http://u:1@a" #f)
    ("path" ,uri-path "http://a" "")
    ("path" ,uri-path "http://a/b%20c" "/b%20c")
    ("path" ,uri-path "mailto:a@b" "a@b")
    ("query" ,uri-query "http://a" #f)
    ("query" ,uri-query "http://a?" "")
    ("query" ,uri-query "http://a?q=%26" "q=%26")
    ("fragment" ,uri-fragment "http://a" #f)
    ("fragment" ,uri-fragment "http://a#" "")
    ("fragment" ,uri-fragment "http://a#F%41" "F%41")))

(harness-group "fields: absent is #f, present-empty is \"\""
  (lambda ()
    (harness-case "every field-table row"
      (lambda ()
        (for-each
         (lambda (row)
           (check-equal (string-append (car row) " of \"" (caddr row) "\"")
                        ((cadr row) (string->uri-reference (caddr row)))
                        (cadddr row)))
         FIELD-ROWS)))))

(harness-group "scheme and host are normalized; everything else stays raw"
  (lambda ()
    (harness-case "case and unreserved %XX, in scheme and host only"
      (lambda ()
        (let ((u (string->uri "HTTP://User@Ex%41mple.COM/A%41")))
          (check-equal "scheme" (uri-scheme u) "http")
          (check-equal "host" (uri-host u) "example.com")
          (check-equal "userinfo keeps its case" (uri-userinfo u) "User")
          (check-equal "authority is raw" (uri-authority u) "User@Ex%41mple.COM")
          (check-equal "path is raw" (uri-path u) "/A%41"))))
    (harness-case "an IP-literal folds its hex digits"
      (lambda () (check-equal "host" (uri-host (string->uri "http://[::A]/")) "[::a]")))
    ;; %C3 is not unreserved, so it stays encoded, with its hex kept uppercase:
    ;; the fold must skip the triplet.
    (harness-case "a reserved triplet in the host keeps its uppercase hex"
      (lambda () (check-equal "host" (uri-host (string->uri "http://%C3%A9.COM/")) "%C3%A9.com")))
    (harness-case "reading the host does not change the record"
      (lambda ()
        (let ((u (string->uri "http://Ex%41mple.COM/")))
          (check-equal "host" (uri-host u) "example.com")
          (check-equal "authority after reading the host" (uri-authority u) "Ex%41mple.COM")
          (check-equal "host read twice" (uri-host u) "example.com"))))))

;;; --- decoded readings ------------------------------------------------------
(harness-group "uri-path-segments: split on /, then decode"
  (lambda ()
    (harness-case "the segment table"
      (lambda ()
        (for-each
         (lambda (row)
           (check-equal (string-append "segments of \"" (car row) "\"")
                        (uri-path-segments (string->uri-reference (car row)))
                        (cadr row)))
         '(("http://a" ())
           ("http://a/" (""))
           ("http://a/a/b/" ("a" "b" ""))
           ("a/b" ("a" "b"))
           ("http://h//x" ("" "x"))
           ("http://a/a%2Fb" ("a/b"))
           ("http://a/caf%C3%A9" ("caf\xE9;"))))))
    (harness-case "a segment that is not UTF-8 raises, at its % in the path"
      (lambda ()
        (check-uri-error "/x/%FF" (lambda () (uri-path-segments (string->uri "http://a/x/%FF")))
                         'uri-path-segments 'invalid-utf-8 3 "/x/%FF")))))

(harness-group "uri-query-pairs and uri-form-pairs"
  (lambda ()
    (harness-case "an absent or empty query has no pairs"
      (lambda ()
        (check-equal "absent, query" (uri-query-pairs (string->uri "http://a")) '())
        (check-equal "empty, query" (uri-query-pairs (string->uri "http://a?")) '())
        (check-equal "absent, form" (uri-form-pairs (string->uri "http://a")) '())))
    (harness-case "split before decode, absent value, decoded to strings"
      (lambda ()
        (check-equal "q=a%26b&r" (uri-query-pairs (string->uri "http://a?q=a%26b&r"))
                     '(("q" . "a&b") ("r" . #f)))
        (check-equal "k=%C3%A9" (uri-query-pairs (string->uri "http://a?k=%C3%A9"))
                     '(("k" . "\xE9;")))))
    (harness-case "+ is literal in the query reading and a space in the form reading"
      (lambda ()
        (check-equal "query" (uri-query-pairs (string->uri "http://a?x=%2B+y")) '(("x" . "++y")))
        (check-equal "form" (uri-form-pairs (string->uri "http://a?x=%2B+y")) '(("x" . "+ y")))))
    ;; The whole query is judged once, so the offset is into the raw query.
    (harness-case "a value that is not UTF-8 raises, at its % in the query"
      (lambda ()
        (check-uri-error "query" (lambda () (uri-query-pairs (string->uri "http://a?a=%C3&b=%A9")))
                         'uri-query-pairs 'invalid-utf-8 2 "a=%C3&b=%A9")
        (check-uri-error "form" (lambda () (uri-form-pairs (string->uri "http://a?a+b=%FF")))
                         'uri-form-pairs 'invalid-utf-8 4 "a+b=%FF")))))

;; Each row: (encoded decoded), or (encoded #f offset) for a sequence that is not
;; UTF-8, whose offset is the CHARACTER index of the % that begins it.
(define DECODE-ROWS
  '(("%C3%A9" "\xE9;")
    ("%F0%9F%98%80" "\x1F600;")
    ;; the boundaries of each UTF-8 length, valid
    ("%C2%80" "\x80;") ("%DF%BF" "\x7FF;") ("%E0%A0%80" "\x800;") ("%ED%9F%BF" "\xD7FF;")
    ("%EE%80%80" "\xE000;") ("%EF%BF%BF" "\xFFFF;") ("%F0%90%80%80" "\x10000;")
    ("%F4%8F%BF%BF" "\x10FFFF;")
    ;; total: + is literal, a malformed % is itself, non-ASCII passes through
    ("a+b" "a+b") ("%zz" "%zz") ("100%" "100%") ("" "") ("caf\xE9;" "caf\xE9;")
    ;; not UTF-8
    ("%FF" #f 0) ("%FE" #f 0) ("a%FFb" #f 1) ("%80" #f 0)
    ("%C0%AF" #f 0) ("%C1%BF" #f 0) ("%E0%9F%BF" #f 0) ("%F0%8F%BF%BF" #f 0)   ; overlong
    ("%ED%A0%80" #f 0)                                                    ; a surrogate
    ("%F4%90%80%80" #f 0) ("%F5%80%80%80" #f 0)                           ; above U+10FFFF
    ("%E2%82" #f 0) ("%E2%82x" #f 0) ("%C3" #f 0)                         ; truncated
    ("ab%E2%82%AC%FF" #f 11)                                              ; after a valid one
    ("\xE9;%FF" #f 1)))                                                   ; after a 2-byte char

(harness-group "uri-decode: strict UTF-8, never U+FFFD"
  (lambda ()
    (harness-case "the decode table"
      (lambda ()
        (for-each
         (lambda (row)
           (if (cadr row)
               (check-equal (string-append "decode \"" (car row) "\"")
                            (uri-decode (car row)) (cadr row))
               (check-uri-error (string-append "decode \"" (car row) "\"")
                                (lambda () (uri-decode (car row)))
                                'uri-decode 'invalid-utf-8 (caddr row) (car row))))
         DECODE-ROWS)))
    ;; The lossy decode this rules out maps both to U+FFFD and so reads two
    ;; different inputs as one string.
    (harness-case "%FF and %FE are not decoded to the same string"
      (lambda ()
        (let ((a (raised (lambda () (uri-decode "%FF"))))
              (b (raised (lambda () (uri-decode "%FE")))))
          (check "%FF raises" (and a (uri-error? a)))
          (check "%FE raises" (and b (uri-error? b))))))))

(harness-group "uri-encode"
  (lambda ()
    (harness-case "the encode table"
      (lambda ()
        (for-each
         (lambda (row)
           (check-equal (string-append "encode \"" (car row) "\"") (uri-encode (car row)) (cadr row)))
         '(("a b" "a%20b") ("caf\xE9;" "caf%C3%A9") ("a/b?c#d" "a%2Fb%3Fc%23d")
           ("~-._AZaz09" "~-._AZaz09") ("" "") ("\x1F600;" "%F0%9F%98%80") ("+&=" "%2B%26%3D")))))
    ;; Code points drawn from every UTF-8 length, surrogates excluded (they are
    ;; not characters). Seeded, so a failure replays.
    (harness-case "uri-decode undoes uri-encode, and the encoding is a valid path"
      (lambda ()
        (define (code-point s)
          (let-values (((kind s) (prng-next s 5)))
            (case kind
              ((0) (let-values (((k s) (prng-next s #x20))) (values k s)))
              ((1) (let-values (((k s) (prng-next s #x5F))) (values (+ #x20 k) s)))
              ((2) (let-values (((k s) (prng-next s #x780))) (values (+ #x80 k) s)))
              ((3) (let-values (((k s) (prng-next s (- #x10000 #x800 #x800))))
                     (let ((cp (+ #x800 k))) (values (if (>= cp #xD800) (+ cp #x800) cp) s))))
              (else (let-values (((k s) (prng-next s #x100000))) (values (+ #x10000 k) s))))))
        (define (random-string s)
          (let-values (((len s) (prng-next s 13)))
            (let loop ((i 0) (s s) (cps '()))
              (if (= i len)
                  (values (list->string (map integer->char cps)) s)
                  (let-values (((cp s) (code-point s)))
                    (loop (+ i 1) s (cons cp cps)))))))
        (let loop ((n 0) (s (make-prng 20261011)) (bad 0))
          (if (= n 2000)
              (check-equal "every generated string round-trips" bad 0)
              (let-values (((str s) (random-string s)))
                (let* ((enc (uri-encode str))
                       (ok (and (equal? (uri-decode enc) str)
                                (uri-string? (string-append "http://a/" enc)))))
                  (unless ok (check-fail "round trip" (string-append "failed on " enc)))
                  (loop (+ n 1) s (if ok bad (+ bad 1)))))))))))

;;; --- refusals ----------------------------------------------------------------
(harness-group "a wrong argument is an assertion naming the caller"
  (lambda ()
    (harness-case "non-strings and non-Uris"
      (lambda ()
        (check-refuses "string->uri 42" (lambda () (string->uri 42)) 'string->uri)
        (check-refuses "string->uri-reference #f" (lambda () (string->uri-reference #f))
                       'string->uri-reference)
        (check-refuses "string->relative-ref 'g" (lambda () (string->relative-ref 'g))
                       'string->relative-ref)
        (check-refuses "uri-string? 1" (lambda () (uri-string? 1)) 'uri-string?)
        (check-refuses "uri-string? with an unknown mode" (lambda () (uri-string? "g" 'bogus))
                       'uri-string?)
        (check-refuses "uri-host of a string" (lambda () (uri-host "http://a")) 'uri-host)
        (check-refuses "uri-port of a string" (lambda () (uri-port "http://a")) 'uri-port)
        (check-refuses "uri-path-segments of #f" (lambda () (uri-path-segments #f))
                       'uri-path-segments)
        (check-refuses "uri-query-pairs of a string" (lambda () (uri-query-pairs "q=1"))
                       'uri-query-pairs)
        (check-refuses "uri-decode 1" (lambda () (uri-decode 1)) 'uri-decode)
        (check-refuses "uri-encode #\\a" (lambda () (uri-encode #\a)) 'uri-encode)))))

(harness-finish)
