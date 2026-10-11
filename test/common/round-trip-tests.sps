#!r6rs
;;; property.round-trip -- RFC 3986's round-trip property.
;;;
;;; THE INVARIANT, one step, a SINGLE normalization:
;;;   r0 = uri-parse(m, x)                     ; require ok
;;;   n0 = normalize-components(components r0)  ; §6.2.2, applied ONCE
;;;   s  = recompose(n0)                        ; §5.3
;;;   r1 = uri-parse(m, s)                      ; SAME mode m; require ok
;;;   HOLDS iff uri-components=?(components r1, n0)
;;; So n0 is the fixed point of the parse-recompose round trip, reached after one
;;; normalization -- NOT a fixed point of normalize (which is not idempotent over
;;; the non-validating domain: %%341 -> %41 -> A). The second
;;; parse re-splits bytes; it does not re-normalize.
;;;
;;; This suite grades the NORMATIVE corpora -- the §1.1.2 example URIs and
;;; the 42 §5.4 resolution targets, all absolute, in mode `uri` -- plus hand
;;; vectors that the committed corpora (all lowercase, no `%`) cannot reach: the
;;; normalize delta and the absent/empty distinction put through the loop, the
;;; exhaustive empty/absent matrix, positive RELATIVE-reference round trips (mode
;;; `uri-reference`), the `%%341` non-idempotence pin, the §4.2/§3.3
;;; recompose boundary over hand-built components, and the §3.3 shape that
;;; §5.2.2 resolution reaches from a base with no authority.
;;;
;;; A universal property, not a ratchet: red iff any in-scope vector fails.
(import (rnrs)
        (uri test harness)
        (uri test corpus)
        (uri components)
        (uri collect)
        (uri normalize)
        (uri resolve)
        (uri recompose))

(define (corpus-path name)
  (string-append (adapter-environment-variable "URI_CORPUS_DIR") "/" name))

;; round-trip-diff : Symbol Bytevector -> (Option String)
;; #f when the one-step invariant holds for `x` in mode `m`; otherwise a
;; diagnostic naming where it broke. Absent (#f) stays distinct from empty via
;; uri-components=?.
(define (round-trip-diff m x)
  (let ((r0 (uri-parse m x)))
    (cond
     ((not (uri-parse-ok? r0))
      (string-append "first parse failed (code "
                     (symbol->string (or (uri-parse-error-code r0) 'none)) ")"))
     (else
      (let* ((n0 (normalize-components (uri-parse-components r0)))
             (s  (recompose n0))
             (r1 (uri-parse m s)))
        (cond
         ((not (uri-parse-ok? r1))
          (string-append "reparse of \"" (utf8->string s) "\" failed"))
         ((uri-components=? (uri-parse-components r1) n0) #f)
         (else
          (string-append "round trip broke: \"" (utf8->string x)
                         "\" normalized+recomposed to \"" (utf8->string s)
                         "\" which reparsed to different components"))))))))

;; check-round-trips : String Symbol String -> void
;; One check per vector: the diagnostic on a break, a plain pass otherwise.
(define (check-round-trips label m x-str)
  (let ((d (round-trip-diff m (string->utf8 x-str))))
    (if d (check-fail label d) (check label #t))))

;; Helpers for the §4.2/§3.3 boundary group, which works over HAND-BUILT
;; components (not parse outputs) to show where recompose is not invertible.
(define (a str) (string->utf8 str))
(define (comp s au p q f) (make-uri-components s au p q f))
;; recompose c, reparse in mode m, return the reparsed components (or #f).
(define (recompose-reparse m c)
  (let ((r (uri-parse m (recompose c))))
    (and (uri-parse-ok? r) (uri-parse-components r))))
;; parse s in mode m and return its components (assumes ok).
(define (parse-components m s) (uri-parse-components (uri-parse m (a s))))

(harness-begin "property.round-trip")

;;; --- the normative corpora: every committed URI is a fixed point ------------
(harness-group "§1.1.2 example URIs round-trip (mode uri)"
  (lambda ()
    (define uris (corpus-load-examples (corpus-path "example-uris.scm")))
    (harness-case "all eight example URIs are fixed points"
      (lambda ()
        (check-equal "example count" (length uris) 8)   ; the property over ∅ is vacuous
        (for-each (lambda (u) (check-round-trips u 'uri u)) uris)))))

(harness-group "§5.4 resolution targets round-trip (mode uri)"
  (lambda ()
    (define c (corpus-load-resolution (corpus-path "resolution.scm")))
    (harness-case "all 42 resolved targets are fixed points"
      (lambda ()
        (check-equal "target count" (length (resolution-vectors c)) 42)
        (for-each
         (lambda (v) (check-round-trips (rv-id v) 'uri (rv-target v)))
         (resolution-vectors c))))))

;;; --- the normalize delta, put through the loop ------------------------------
;;; The committed corpora are all lowercase with no `%`, so normalization is the
;;; identity on them and the corpus groups above exercise the round trip only in
;;; the no-delta region. These carry a real §6.2.2 change (scheme fold, unreserved
;;; decode, reserved-hex uppercasing, a created dot-segment) so the round trip is
;;; exercised over normalized OUTPUT too.
;;;
;;; HONEST SCOPE: the property tests recompose∘parse STABILITY on n0, not
;;; normalize CORRECTNESS (unit.normalize's job), and it is INHERENTLY blind
;;; to a normalize that does nothing -- identity output always round-trips, so
;;; the first four cases are COVERAGE (the round trip holds over normalized
;;; output), not a witness of normalize. The ONE normalize fault the property is
;;; sensitive to is a normalization that decodes a RESERVED octet into a
;;; component delimiter; the last case pins exactly that.
(harness-group "a normalized result is a fixed point"
  (lambda ()
    (harness-case "scheme case fold survives the round trip"
      (lambda () (check-round-trips "HTTP://a/b" 'uri "HTTP://a/b")))
    (harness-case "an unreserved %XX is decoded and survives"
      (lambda () (check-round-trips "%7Efoo -> ~foo" 'uri "http://a/%7Efoo")))
    (harness-case "a reserved %XX keeps its hex, uppercased, and survives"
      (lambda () (check-round-trips "%2f -> %2F" 'uri "http://a/%2f")))
    ;; %2E decodes to a literal '.', which normalize CREATES but
    ;; does not remove -- the round trip (no resolution in the loop) keeps it.
    (harness-case "a decoded dot-segment is created and round-trips as-is"
      (lambda () (check-round-trips "%2E -> ." 'uri "http://a/b/%2E/c")))
    ;; TEETH: %23 is '#', a reserved gen-delim. It MUST stay encoded through
    ;; normalization; a normalize that decoded it would recompose "http://a?x#y",
    ;; which re-parses with the query split at the '#' and a fragment "y" -- so
    ;; the round trip breaks. This is the one class of normalize fault the
    ;; property catches, and it makes the normalize half non-decorative.
    (harness-case "an encoded reserved delimiter stays encoded (query %23)"
      (lambda () (check-round-trips "?x%23y keeps %23 encoded" 'uri "http://a?x%23y")))
    ;; the same teeth in another position: %2F ('/') in the AUTHORITY. If
    ;; normalize decoded it, "a%2Fb" -> "a/b" recomposes to "http://a/b", which
    ;; re-parses with authority "a" and path "/b" -- so the round trip breaks. A
    ;; decoded '/' in the PATH stays path content, so only a delimiter-bearing
    ;; position (authority here, query above) has teeth.
    (harness-case "an encoded reserved delimiter stays encoded (authority %2F)"
      (lambda () (check-round-trips "%2F in authority stays encoded" 'uri "http://a%2Fb")))
    ;; the delta reaching the authority and the fragment, not just the path
    (harness-case "an unreserved %XX in the authority decodes and survives"
      (lambda () (check-round-trips "%41 in authority" 'uri "http://%41b")))
    (harness-case "an unreserved %XX in the fragment decodes and survives"
      (lambda () (check-round-trips "%7E in fragment" 'uri "http://a#%7Efoo")))))

;;; --- the empty/absent matrix, exhaustive ------------------------------------
;;; Every component's present-empty vs absent pair recovered through
;;; recompose→reparse, plus the §3.2 case that is the whole reason absent ≠ empty:
;;; http:///p (empty authority, absolute path) vs http:/p (no authority).
(harness-group "the empty/absent matrix survives the round trip"
  (lambda ()
    (harness-case "an empty-but-present fragment round-trips (http://a#)"
      (lambda () (check-round-trips "http://a# (fragment present, empty)" 'uri "http://a#")))
    (harness-case "an absent fragment round-trips (http://a)"
      (lambda () (check-round-trips "http://a (fragment absent)" 'uri "http://a")))
    ;; the §3.2 distinction: an empty authority with an absolute path, vs none.
    (harness-case "an empty authority before an absolute path round-trips (http:///p)"
      (lambda () (check-round-trips "http:///p (authority present, empty)" 'uri "http:///p")))
    (harness-case "an absent authority before an absolute path round-trips (http:/p)"
      (lambda () (check-round-trips "http:/p (authority absent)" 'uri "http:/p")))
    (harness-case "empty query AND empty fragment both round-trip (http://a?#)"
      (lambda () (check-round-trips "http://a?# (query and fragment present, empty)" 'uri "http://a?#")))
    (harness-case "a fragment with no authority round-trips (http:#)"
      (lambda () (check-round-trips "http:# (fragment present, no authority)" 'uri "http:#")))))

;;; --- positive relative-reference round trips --------------------------------
;;; The property holds in EVERY mode, not only mode `uri`.
;;; The committed corpora are all absolute, so relative references are MEASURED
;;; here, reparsed in mode `uri-reference`. None reaches the §4.2/§3.3 boundary:
;;; a parse never emits a colon-first-segment scheme-absent path (`./a:b` is
;;; SAFE -- its colon is in the second segment) or a //-leading no-authority
;;; path, so the round trip over parse outputs is total in this mode too.
(harness-group "relative references round-trip (mode uri-reference)"
  (lambda ()
    (harness-case "a spread of relative references are fixed points"
      (lambda ()
        (for-each
         (lambda (ref) (check-round-trips (string-append "ref \"" ref "\"") 'uri-reference ref))
         (list "g" "g/h" "../g" "./g" "/g" "?q" "#f" ""
               "g;x=1/../y" "a/b?c#d" "./a:b"))))))

;;; --- the absent/empty distinction, recovered through reparse ------------
(harness-group "absent vs present-empty survives recompose then reparse"
  (lambda ()
    (harness-case "an empty-but-present authority round-trips (http://)"
      (lambda () (check-round-trips "http:// (authority present, empty)" 'uri "http://")))
    (harness-case "an absent authority round-trips (http:)"
      (lambda () (check-round-trips "http: (authority absent)" 'uri "http:")))
    (harness-case "an empty-but-present query round-trips (http://a?)"
      (lambda () (check-round-trips "http://a? (query present, empty)" 'uri "http://a?")))
    (harness-case "an absent query round-trips (http://a)"
      (lambda () (check-round-trips "http://a (query absent)" 'uri "http://a")))))

;;; --- normalize is NOT idempotent -- why the invariant is one-step ------------
;;; The round trip applies normalize ONCE. It must, because normalize is not
;;; idempotent over the non-validating domain: a malformed `%`
;;; adjacent to a triple realigns on a second pass. This pins that fact directly
;;; (non-load-bearing for the round trip, but it is the reason the round trip
;;; cannot be stated as a normalize fixed point) and confirms the ONE-STEP round
;;; trip still HOLDS for such an input.
(harness-group "normalize is not idempotent; the one-step round trip still holds"
  (lambda ()
    (harness-case "%%341 normalizes to %41, and %41 normalizes on to A"
      (lambda ()
        ;; pass 1: the leading literal % is kept (next byte is not hex), then
        ;; %34 decodes to '4' -> %41. pass 2: %41 is now a valid triple -> A.
        (check-equal "once"  (pct-normalize (a "%%341")) (a "%41"))
        (check-equal "twice" (pct-normalize (pct-normalize (a "%%341"))) (a "A"))
        (check "so N is not idempotent here"
               (not (bytevector=? (pct-normalize (a "%%341"))
                                  (pct-normalize (pct-normalize (a "%%341"))))))))
    ;; The ONE normalize step gives n0 path "/%41"; recompose→reparse is the
    ;; identity on THAT, so the round trip holds even though n0 is not a
    ;; normalize fixed point (a second normalize would give "/A").
    (harness-case "the one-step round trip holds for http://h/%%341"
      (lambda () (check-round-trips "http://h/%%341" 'uri "http://h/%%341")))))

;;; --- the §4.2/§3.3 recompose boundary, over HAND-BUILT components ------------
;;; recompose is a faithful inverse of parse for every PARSE OUTPUT, but NOT over
;;; arbitrary components. Two scheme-absent shapes break
;;; parse(recompose(c)) = c -- and both are UNREACHABLE from parsing (§3.3 forbids
;;; a //-leading no-authority path, and a parse never emits a colon-first-segment
;;; scheme-absent path), so the round trip over parse outputs never meets them.
;;; §5.3 recompose deliberately omits §4.2's disambiguating "./"; adding it would
;;; diverge from §5.3 as the RFC writes it, and that disambiguation is the
;;; reference PRODUCER's job -- a relative-reference serializer layered above
;;; recompose, not the generic renderer. Pinned as expected non-round-trips, the
;;; analog of the §5.4.2 http:g loophole the corpus records.
(harness-group "the §4.2 / §3.3 recompose boundary is documented, not faked"
  (lambda ()
    ;; §4.2: {scheme=#f, path="a:b"} is not a parse output. recompose gives
    ;; "a:b", which re-parses as a SCHEME. (rp is a components;
    ;; the guard names a recompose regression instead of erroring.)
    (harness-case "§4.2 colon-first-segment: recompose is not invertible here"
      (lambda ()
        (let ((rp (recompose-reparse 'uri-reference (comp #f #f (a "a:b") #f #f))))
          (check "the recomposition re-parses" (uri-components? rp))
          (check "the hand-built shape does NOT round-trip"
                 (not (uri-components=? rp (comp #f #f (a "a:b") #f #f))))
          (check-equal "it re-parses with scheme \"a\"" (uri-components-scheme rp) (a "a")))))
    (harness-case "§4.2: the parser never emits {scheme=#f, path=\"a:b\"}"
      (lambda ()
        (let ((c (parse-components 'uri-reference "a:b")))
          (check-equal "\"a:b\" parses as scheme a" (uri-components-scheme c) (a "a"))
          (check-equal "with path b" (uri-components-path c) (a "b")))))
    ;; §3.3: {authority=#f, path="//x"} is not a parse output. recompose gives
    ;; "//x", which re-parses with the "//" as the authority delimiter.
    (harness-case "§3.3 //-leading path: recompose is not invertible here"
      (lambda ()
        (let ((rp (recompose-reparse 'uri-reference (comp #f #f (a "//x") #f #f))))
          (check "the recomposition re-parses" (uri-components? rp))
          (check "the hand-built shape does NOT round-trip"
                 (not (uri-components=? rp (comp #f #f (a "//x") #f #f))))
          (check-equal "it re-parses with authority \"x\"" (uri-components-authority rp) (a "x"))
          (check-equal "and an empty path" (uri-components-path rp) (a "")))))
    (harness-case "§3.3: the parser never emits {authority=#f, path=\"//x\"}"
      (lambda ()
        (let ((c (parse-components 'uri-reference "//x")))
          (check-equal "\"//x\" parses with authority x" (uri-components-authority c) (a "x"))
          (check-equal "and an empty path" (uri-components-path c) (a "")))))))

;;; --- §5.2.2 resolution reaches the §3.3 shape, from a no-authority base -----
;;; The §3.3 shape above is unreachable from PARSING, but not from RESOLUTION.
;;; §5.2.4 rewrites "/./" to "/", so a reference whose path (merged or rooted)
;;; begins "/.//" resolves to a path beginning "//". With no authority in the
;;; base, §5.3 emits that path straight after "foo:", and the result re-parses
;;; with the "//" as the authority delimiter: a different URI. An authority in
;;; the base keeps the "//" inside the path, so http-style bases never meet it.
;;; (uri resolve) and (uri recompose) follow the RFC's algorithms as written, so
;;; this is pinned as an expected non-round-trip: a change to either must
;;; redden here rather than drift.
(harness-group "§5.2.2 resolution reaches the §3.3 shape from a no-authority base"
  (lambda ()
    (define (resolve-strings base ref)
      (resolve-components (parse-components 'uri base)
                          (parse-components 'uri-reference ref)))
    (for-each
     (lambda (ref)
       (harness-case (string-append "foo:/a + " ref " resolves to a //-leading path that does not round-trip")
         (lambda ()
           (let* ((t (resolve-strings "foo:/a" ref))
                  (rp (recompose-reparse 'uri t)))
             (check "the target is {foo, no authority, \"//bar\"}"
                    (uri-components=? t (comp (a "foo") #f (a "//bar") #f #f)))
             (check-equal "it recomposes to foo://bar" (recompose t) (a "foo://bar"))
             (check "the recomposition re-parses" (uri-components? rp))
             (check "the target does NOT round-trip" (not (uri-components=? rp t)))
             (check-equal "it re-parses with authority \"bar\""
                          (uri-components-authority rp) (a "bar"))))))
     (list ".//bar" "/.//bar"))
    (harness-case "an authority in the base keeps the // inside the path"
      (lambda ()
        (let* ((t (resolve-strings "http://h/a" "/.//bar"))
               (rp (recompose-reparse 'uri t)))
          (check-equal "the path is //bar" (uri-components-path t) (a "//bar"))
          (check "and the target round-trips"
                 (and (uri-components? rp) (uri-components=? rp t))))))))

(harness-finish)
