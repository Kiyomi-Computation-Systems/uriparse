#!r6rs
;;; unit.abnf-oracle -- the whole-URI recognizer graded on its OWN, before it is
;;; ever run against the product (the RFC 3986 conformance audit, decision 0028,
;;; Slice ⓪).
;;;
;;; One artifact lands in Slice ⓪ and this lane grades it two ways, exactly as the
;;; corpus loader and the two component oracles were graded before any validator
;;; existed (decision 0005): (uri test abnf-oracle), an INDEPENDENT reading of RFC
;;; 3986 Appendix A's structural grammar composed with the audited M3/M4 component
;;; oracles, must ACCEPT every positive corpus -- the §1.1.2 example URIs, the §5.4
;;; base, references, and targets -- and must REJECT a hand-built structural
;;; negative set that walks each way the structure can be violated (a bad scheme,
;;; a mode/production mismatch, an invalid authority, a per-component charset
;;; fault, and the URI / relative-ref disambiguation). NO differential against
;;; uri-parse-validate here: that is Slice ①, once the oracle itself is trusted.
;;;
;;; The positives are the RFC's own vectors, read through (uri test corpus); the
;;; structural cases are authored here, small and legible, one class per case.
(import (rnrs)
        (uri test harness)
        (uri test corpus)
        (uri test abnf-oracle))

(define (corpus-path name)
  (string-append (adapter-environment-variable "URI_CORPUS_DIR") "/" name))

;; accepts / rejects: the oracle's verdict on a STRING vector in a given mode.
(define (accepts label mode s) (check label (oracle-recognize-string? mode s)))
(define (rejects label mode s) (check-equal label (oracle-recognize-string? mode s) #f))

(harness-begin "unit.abnf-oracle")

;; --- the positive corpora, all recognized --------------------------------
;;
;; The RFC's own vectors are the strongest positives: an oracle that rejects one
;; is reading the ABNF wrong. §1.1.2's eight URIs are URIs (and, by the union,
;; URI-references); §5.4's base and 43 targets are URIs; §5.4's references are
;; URI-references (most relative, a few -- "g:h", "http:g" -- absolute).
(harness-group "the positive corpora are all recognized"
  (lambda ()
    (define examples (corpus-load-examples (corpus-path "example-uris.scm")))
    (define res (corpus-load-resolution (corpus-path "resolution.scm")))
    (define base (resolution-base res))
    (define rows (resolution-vectors res))
    (harness-case "the §1.1.2 example URIs are URIs and URI-references"
      (lambda ()
        (for-each
         (lambda (u)
           (accepts (string-append "uri: " u) 'uri u)
           (accepts (string-append "uri-reference: " u) 'uri-reference u))
         examples)))
    (harness-case "the §5.4 base and every target is a URI"
      (lambda ()
        (accepts (string-append "base: " base) 'uri base)
        (for-each
         (lambda (r) (accepts (string-append "target: " (rv-target r)) 'uri (rv-target r)))
         rows)))
    (harness-case "every §5.4 reference is a URI-reference"
      (lambda ()
        (for-each
         (lambda (r)
           (accepts (string-append "ref: [" (rv-reference r) "]") 'uri-reference (rv-reference r)))
         rows)))))

;; --- the five path-types and the empty/edge shapes -----------------------
;;
;; The corpus exercises these, but implicitly; these pin each path-type and the
;; empty shapes by name, so a mutation that collapses one arm reddens HERE with a
;; legible label rather than only through some corpus row that happens to use it.
(harness-group "the five path-types and edge shapes are accepted"
  (lambda ()
    (harness-case "URI hier-part arms"
      (lambda ()
        (accepts "path-empty:     a:"        'uri "a:")
        (accepts "path-rootless:  a:b"       'uri "a:b")
        (accepts "rootless colon: a:b:c"     'uri "a:b:c")
        (accepts "path-absolute:  a:/b"      'uri "a:/b")
        (accepts "authority+abe:  a://h/p"   'uri "a://h/p")
        (accepts "authority host: a://h"     'uri "a://h")
        (accepts "authority port: a://h:9/p" 'uri "a://h:9/p")
        (accepts "empty authority a:///p"    'uri "a:///p")))
    (harness-case "relative-ref relative-part arms"
      (lambda ()
        (accepts "path-empty:      (empty)"  'relative-ref "")
        (accepts "path-noscheme:   g/h"      'relative-ref "g/h")
        (accepts "noscheme late-:  a/b:c"    'relative-ref "a/b:c")
        (accepts "path-absolute:   /p"       'relative-ref "/p")
        (accepts "authority:       //h/p"    'relative-ref "//h/p")
        (accepts "query only:      ?q"       'relative-ref "?q")
        (accepts "fragment only:   #f"       'relative-ref "#f")
        (accepts "query+fragment:  ?q#f"     'relative-ref "?q#f")))))

;; --- the URI / relative-ref disambiguation -------------------------------
;;
;; The one structural fork (decision 0028's worked example): a colon-bearing first
;; segment is a URI's scheme, never a relative-ref's first path segment. So each
;; of these is a URI, is NOT a relative-ref, and is a URI-reference only through
;; the URI arm. This is the property the audit most needs the oracle to get right.
(harness-group "the URI / relative-ref disambiguation"
  (lambda ()
    (harness-case "a colon-first-segment resolves to URI, never relative-ref"
      (lambda ()
        (accepts "g:h is a URI"                 'uri "g:h")
        (rejects "g:h is not a relative-ref"    'relative-ref "g:h")
        (accepts "g:h is a URI-reference"       'uri-reference "g:h")
        (accepts "a:/b is a URI"                'uri "a:/b")
        (rejects "a:/b is not a relative-ref"   'relative-ref "a:/b")
        (accepts "a:/b is a URI-reference"      'uri-reference "a:/b")))
    (harness-case "a relative reference is not an absolute URI"
      (lambda ()
        (rejects "g is not a URI"        'uri "g")
        (accepts "g is a URI-reference"  'uri-reference "g")
        (rejects "/p is not a URI"       'uri "/p")
        (rejects "../g is not a URI"     'uri "../g")
        (rejects "//h is not a URI"      'uri "//h")))))

;; --- the structural negatives, one class per case ------------------------
;;
;; Each is a distinct way the STRUCTURE (not just a byte) can be wrong. The audit
;; hunts subtle deviations; these coarse ones pin the recognizer's rejection side
;; so a mutation that makes it accept-everything reddens here.
(harness-group "structural negatives are rejected"
  (lambda ()
    (harness-case "a bad scheme means not-a-URI"
      (lambda ()
        (rejects "digit-first scheme:   1abc:x"  'uri "1abc:x")
        (rejects "empty scheme:          :x"      'uri ":x")
        (rejects "space in scheme:       a b:c"   'uri "a b:c")
        ;; the 0028 example: 1abc:x is neither URI (bad scheme) nor relative-ref
        ;; (first segment "1abc:x" bears a colon), so not a URI-reference either.
        (rejects "1abc:x not a URI-reference" 'uri-reference "1abc:x")))
    (harness-case "a mode / production mismatch is rejected"
      (lambda ()
        (rejects "URI given as relative-ref:      g:h"      'relative-ref "g:h")
        (rejects "scheme'd given as relative-ref: http://a" 'relative-ref "http://a")
        (rejects "relative given as URI:          a/b"      'uri "a/b")))
    (harness-case "an invalid authority is rejected"
      (lambda ()
        (rejects "unterminated IP-literal: //[bad"   'uri-reference "//[bad")
        (rejects "userinfo in the host:    //a<b@h"  'uri-reference "//a<b@h")))
    (harness-case "a per-component charset fault is rejected"
      (lambda ()
        (rejects "gen-delim in path:  a<b"    'uri-reference "a<b")
        (rejects "bad pct in path:    a%zz"   'uri-reference "a%zz")
        (rejects "space in query:     a?x y"  'uri-reference "a?x y")
        (rejects "space in fragment:  a#x y"  'uri-reference "a#x y")))
    (harness-case "a non-ASCII byte is rejected"
      (lambda ()
        ;; 0x80 is not in any RFC 3986 byte set; a string literal cannot carry it,
        ;; so this vector is raw bytes: "a" then 0x80, as a path.
        (check-equal "0x80 in a path"
                     (oracle-recognize? 'uri-reference (u8-list->bytevector '(97 128))) #f)))))

(harness-finish)
