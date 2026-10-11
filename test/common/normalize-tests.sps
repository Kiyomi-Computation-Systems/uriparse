#!r6rs
;;; unit.normalize -- RFC 3986 §6.2.2 syntax-based normalization, the §6 policy
;;; over `(uri percent)`'s mechanics. Graded against an oracle (derived from
;;; RFC 3986 independently of this code): the §6.2.2.1a scheme AND host fold
;;; (userinfo case is preserved, a `%XX` triplet's hex kept uppercase), the
;;; §6.2.2.1b hex-uppercasing, the §6.2.2.2 unreserved decoding, and the one
;;; deliberate omission pinned as a test -- dot-segments are not removed (that
;;; is resolution's job, §5.2.4). The percent codec is judged in
;;; unit.percent; here the question is the §6 policy and the assembly.
(import (rnrs)
        (uri test harness)
        (uri normalize)
        (uri components))

(define (a str) (string->utf8 str))
(define (bytes . lst) (u8-list->bytevector lst))
;; a components from strings/#f, and the "want" it should normalize to
(define (sb s) (and s (string->utf8 s)))
(define (comp scheme authority path query fragment)
  (make-uri-components (sb scheme) (sb authority) (sb path) (sb query) (sb fragment)))

;; check-components: per-field check-equal, so a mismatch names the field and
;; shows the bytes rather than "expected a true value". `equal?` keeps absent
;; (#f) distinct from empty (#vu8()), so this pins the absent/empty distinction
;; per field as well as the byte content.
(define (check-components label r scheme authority path query fragment)
  (check-equal (string-append label ": scheme")    (uri-components-scheme r)    (sb scheme))
  (check-equal (string-append label ": authority") (uri-components-authority r) (sb authority))
  (check-equal (string-append label ": path")      (uri-components-path r)      (sb path))
  (check-equal (string-append label ": query")     (uri-components-query r)     (sb query))
  (check-equal (string-append label ": fragment")  (uri-components-fragment r)  (sb fragment)))

(harness-begin "unit.normalize")

;;; --- §6.2.2.1a: the scheme folds to lowercase (ASCII, by hand) --------------
(harness-group "normalize-scheme"
  (lambda ()
    (harness-case "an all-caps scheme lowercases"
      (lambda () (check-equal "HTTP -> http" (normalize-scheme (a "HTTP")) (a "http"))))
    (harness-case "a mixed-case scheme lowercases"
      (lambda ()
        (check-equal "eXAMPLE -> example" (normalize-scheme (a "eXAMPLE")) (a "example"))
        (check-equal "HtTpS -> https"     (normalize-scheme (a "HtTpS")) (a "https"))))
    (harness-case "an already-lower scheme is unchanged"
      (lambda () (check-equal "http" (normalize-scheme (a "http")) (a "http"))))
    ;; The scheme's non-letter members (DIGIT, +, -, .) have no case; they and a
    ;; stray non-ASCII byte must pass through the ASCII-only fold untouched.
    (harness-case "digits and + - . are untouched, and the fold is ASCII-only"
      (lambda ()
        (check-equal "a+b-2.0" (normalize-scheme (a "a+b-2.0")) (a "a+b-2.0"))
        (check-equal "high byte 0xC0 untouched"
                     (normalize-scheme (bytes 65 192 90)) (bytes 97 192 122))))
    (harness-case "empty scheme in, empty out"
      (lambda () (check-equal "empty" (normalize-scheme (a "")) (a ""))))
    ;; Purity: the fold allocates a fresh bytevector and never mutates its input.
    (harness-case "the input bytevector is not mutated"
      (lambda ()
        (let ((in (a "HTTP")))
          (normalize-scheme in)
          (check-equal "input still HTTP" in (a "HTTP")))))
    ;; The named witness: the UTF-8 encoding of U+212A KELVIN
    ;; SIGN (E2 84 AA) must survive the hand-written fold byte-identical. A
    ;; `string-downcase`-based fold would map it to ASCII `k` (Unicode folding),
    ;; corrupting a host that contains it -- exactly why the fold avoids
    ;; `(rnrs unicode)`. `ascii-downcase` is that fold (shared with the host).
    (harness-case "U+212A KELVIN SIGN survives the fold byte-identical"
      (lambda ()
        (check-equal "E2 84 AA unchanged"
                     (normalize-scheme (bytes 226 132 170)) (bytes 226 132 170))))))

;;; --- §6.2.2.1b + §6.2.2.2: percent normalization ----------------------------
(harness-group "pct-normalize"
  (lambda ()
    ;; decode the unreserved octets (§6.2.2.2 + §2.3): ALPHA, DIGIT, the 4 marks
    (harness-case "an unreserved %XX decodes to its character"
      (lambda ()
        (check-equal "%41 -> A" (pct-normalize (a "%41")) (a "A"))
        (check-equal "%61 -> a" (pct-normalize (a "%61")) (a "a"))
        (check-equal "%30 -> 0" (pct-normalize (a "%30")) (a "0"))
        (check-equal "%2D -> -" (pct-normalize (a "%2D")) (a "-"))
        (check-equal "%2E -> ." (pct-normalize (a "%2E")) (a "."))
        (check-equal "%5F -> _" (pct-normalize (a "%5F")) (a "_"))
        (check-equal "%7E -> ~" (pct-normalize (a "%7E")) (a "~"))))
    ;; a RESERVED octet stays encoded, but its hex is uppercased (§6.2.2.1b)
    (harness-case "a reserved %XX stays encoded, hex uppercased"
      (lambda ()
        (check-equal "%2F stays" (pct-normalize (a "%2F")) (a "%2F"))
        (check-equal "%3A stays" (pct-normalize (a "%3A")) (a "%3A"))
        (check-equal "%3a -> %3A" (pct-normalize (a "%3a")) (a "%3A"))))
    ;; an "other" octet (neither reserved nor unreserved) -- brace -- same rule
    (harness-case "an \"other\" %XX stays encoded, hex uppercased"
      (lambda ()
        (check-equal "%7b -> %7B" (pct-normalize (a "%7b")) (a "%7B"))
        (check-equal "%7d -> %7D" (pct-normalize (a "%7d")) (a "%7D"))
        (check-equal "%ab -> %AB (a letter in the high nibble too)"
                     (pct-normalize (a "%ab")) (a "%AB"))
        (check-equal "%63 -> c (contrast: c IS unreserved)"
                     (pct-normalize (a "%63")) (a "c"))))
    ;; total: a malformed % is left byte-for-byte
    (harness-case "a malformed % is left byte-for-byte"
      (lambda ()
        (check-equal "%ZZ" (pct-normalize (a "%ZZ")) (a "%ZZ"))
        (check-equal "%GG" (pct-normalize (a "%GG")) (a "%GG"))
        (check-equal "%4Z (first hex, second not)" (pct-normalize (a "%4Z")) (a "%4Z"))
        (check-equal "%A"  (pct-normalize (a "%A"))  (a "%A"))
        (check-equal "trailing %" (pct-normalize (a "abc%")) (a "abc%"))
        (check-equal "%%41 (% then a valid triple)" (pct-normalize (a "%%41")) (a "%A"))))
    ;; `+` is a sub-delim, never touched -- RFC 3986 has no +<->space rule
    (harness-case "a literal + is left alone (not RFC 3986's job)"
      (lambda () (check-equal "a+b" (pct-normalize (a "a+b")) (a "a+b"))))
    (harness-case "a mix of decode / keep / literal in one component"
      (lambda ()
        (check-equal "/%7Efoo%2Fbar%7b -> /~foo%2Fbar%7B"
                     (pct-normalize (a "/%7efoo%2fbar%7b")) (a "/~foo%2Fbar%7B"))))
    ;; Normalization CREATES dot-segments: `.` (%2E) is an unreserved mark, so
    ;; it decodes. This is exactly why resolution must run AFTER normalization:
    ;; a resolver on raw components would let encoded `../` survive as live path
    ;; traversal.
    (harness-case "an unreserved-mark %XX manufactures a literal dot-segment"
      (lambda ()
        (check-equal "/a/%2E%2E/b -> /a/../b" (pct-normalize (a "/a/%2E%2E/b")) (a "/a/../b"))
        (check-equal "%2E%2E%2F -> ..%2F (%2F reserved, stays)"
                     (pct-normalize (a "%2E%2E%2F")) (a "..%2F"))))
    ;; Single pass, never recursive (RFC 3986 §2.4: do not decode more than once).
    ;; %2541: %25 -> `%` (reserved, kept encoded as %25), then the trailing `41`
    ;; are literal bytes -- never re-read as a fresh triple. A "decode to fixpoint"
    ;; rewrite would break this while every other case stayed green.
    (harness-case "decoding is single-pass, not recursive (RFC 3986 §2.4)"
      (lambda ()
        (check-equal "%2541 stays %2541" (pct-normalize (a "%2541")) (a "%2541"))))
    (harness-case "empty in, empty out; and no-% passes through"
      (lambda ()
        (check-equal "empty" (pct-normalize (a "")) (a ""))
        (check-equal "plain" (pct-normalize (a "abc")) (a "abc"))))
    ;; §6.2.2.2 is idempotent: a decoded/uppercased result normalizes to itself.
    (harness-case "pct-normalize is idempotent"
      (lambda ()
        (for-each
         (lambda (s)
           (let ((once (pct-normalize (a s))))
             (check-equal (string-append "twice = once: " s)
                          (pct-normalize once) once)))
         '("%41" "%3a" "%7b" "/%7efoo%2fbar" "%ZZ" "a+b"))))))

;;; --- normalize-components: §6.2.2 per component, and no further --------------
(harness-group "normalize-components"
  (lambda ()
    ;; The §6.2.2 worked example, minus dot-segment removal. RFC 3986 §6.2.2 gives
    ;; `eXAMPLE://a/./b/../b/%63/%7bfoo%7d` == `example://a/b/c/%7Bfoo%7D`.
    ;; normalize-components does the scheme fold and the percent transforms but
    ;; NOT dot-segment removal (that is §6.2.2.3 = §5.2.4, resolution's job), so
    ;; the dots MUST survive here.
    (harness-case "the §6.2.2 example: scheme + percent normalized, dot-segments kept"
      (lambda ()
        (check-components "§6.2.2 example"
          (normalize-components (comp "eXAMPLE" "a" "/./b/../b/%63/%7bfoo%7d" #f #f))
          "example" "a" "/./b/../b/c/%7Bfoo%7D" #f #f)))
    ;; HOST CASE: the HOST folds to lowercase, but case-sensitive userinfo is left
    ;; ALONE. `User:S3cret` survives; `Example.COM` -> `example.com`. A regression
    ;; to lowercasing the WHOLE authority (corrupting userinfo) reddens here.
    (harness-case "the host case-folds to lowercase, userinfo case is preserved"
      (lambda ()
        (check-components "host-case normalized"
          (normalize-components (comp "HTTP" "User:S3cret@Example.COM" "/" #f #f))
          "http" "User:S3cret@example.com" "/" #f #f)))
    ;; An IPv6 IP-literal host folds too (its hex is case-insensitive, §6.2.2.1a;
    ;; lowercase is canonical, RFC 5952), and there is no userinfo to protect.
    (harness-case "an IPv6 IP-literal host folds to lowercase"
      (lambda ()
        (check-components "ipv6 host"
          (normalize-components (comp "s" "[2001:DB8::Ab]:80" "/" #f #f))
          "s" "[2001:db8::ab]:80" "/" #f #f)))
    ;; percent AND host case interact: the host's literal bytes fold, but a `%XX`
    ;; triplet keeps its (uppercased, §6.2.2.1b) hex -- `H%2Fx` -> `h%2Fx`, never
    ;; `h%2fx` -- while userinfo `Us~r` (from `Us%7Er`) keeps its case.
    (harness-case "the host folds but its %XX hex stays uppercase; userinfo untouched"
      (lambda ()
        (check-components "host fold + pct"
          (normalize-components (comp "s" "Us%7Er@H%2Fx" "/" #f #f))
          "s" "Us~r@h%2Fx" "/" #f #f)))
    ;; A reserved octet that percent-DECODES to a delimiter stays encoded, so
    ;; whole-authority normalization can never synthesize or destroy a `@`/`:`
    ;; boundary before the host split. The RFC 6874 IPv6 zone-id `%25` is the
    ;; sharp case: `%25` decodes to `%` (0x25), which is not unreserved, so it is
    ;; kept encoded rather than collapsed.
    (harness-case "a reserved-decoding %XX in the authority stays encoded (zone-id safe)"
      (lambda ()
        (check-components "zone-id"
          (normalize-components (comp "s" "[fe80::1%25eth0]" "/p" #f #f))
          "s" "[fe80::1%25eth0]" "/p" #f #f)))
    ;; every component that carries pct-encoding is normalized
    (harness-case "path, query and fragment are all percent-normalized"
      (lambda ()
        (check-components "path/query/fragment"
          (normalize-components (comp "s" #f "/%7Ep" "%61=%2F" "%62"))
          "s" #f "/~p" "a=%2F" "b")))
    ;; A scheme-LESS reference (RFC 3986 §4.2) exercises the absent-scheme guard:
    ;; normalize-scheme raises on #f, so the field MUST be guarded, and the other
    ;; components still normalize.
    (harness-case "an absent scheme stays absent while the rest normalize"
      (lambda ()
        (check-components "relative-ref"
          (normalize-components (comp #f "a" "/%7Ep" "%61" #f))
          #f "a" "/~p" "a" #f)))
    ;; absent is not empty, and normalization preserves BOTH, per field.
    (harness-case "an absent field stays absent, per field"
      (lambda ()
        (let ((r (normalize-components (comp #f #f "/p" #f #f))))
          (check "scheme absent"    (uri-component-absent? (uri-components-scheme r)))
          (check "authority absent" (uri-component-absent? (uri-components-authority r)))
          (check "query absent"     (uri-component-absent? (uri-components-query r)))
          (check "fragment absent"  (uri-component-absent? (uri-components-fragment r))))))
    (harness-case "an empty field stays empty, per field (never folded to absent)"
      (lambda ()
        (let ((r (normalize-components (comp "" "" "" "" ""))))
          (check "scheme empty"    (uri-component-empty? (uri-components-scheme r)))
          (check "authority empty" (uri-component-empty? (uri-components-authority r)))
          (check "path empty"      (uri-component-empty? (uri-components-path r)))
          (check "query empty"     (uri-component-empty? (uri-components-query r)))
          (check "fragment empty"  (uri-component-empty? (uri-components-fragment r))))))
    ;; idempotence at the components level
    (harness-case "normalize-components is idempotent"
      (lambda ()
        (let* ((in (comp "HtTp" "a%7Eb" "/%63/%7b" "%41" "%2f"))
               (once (normalize-components in)))
          (check "twice = once"
                 (uri-components=? (normalize-components once) once)))))))

(harness-finish)
