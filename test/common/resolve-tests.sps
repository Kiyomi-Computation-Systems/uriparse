#!r6rs
;;; unit.resolve -- RFC 3986 §5.2.2 Transform References, judged at the COMPONENT
;;; level: base components and reference components in, target components out.
;;; The §5.4 corpus (conformance.resolution) drives the same code end-to-end
;;; through the parser and recomposer; this suite isolates §5.2.2's decision tree
;;; so a branch bug cannot hide behind a parse or recompose bug, and it pins the
;;; absent-vs-empty distinctions (decision 0008) the corpus does not reach: an
;;; empty-but-present R.query, and an empty-but-present R.authority.
;;;
;;; STRICT (decision 0015/0001): `http:g` keeps its scheme and resolves to
;;; `http:g`, never the RFC-1630 backward-compatible `http://a/b/c/g`.
;;;
;;; The expected target components are the RFC-derived §5.2.2 hand-traces, graded
;;; independently of the implementation.
(import (rnrs)
        (uri test harness)
        (uri components)
        (uri resolve))

(define (a str) (string->utf8 str))
(define (comp scheme authority path query fragment)
  (make-uri-components scheme authority path query fragment))

;; The §5.4 base: http://a/b/c/d;p?q -- authority "a", path "/b/c/d;p", query "q".
(define base (comp (a "http") (a "a") (a "/b/c/d;p") (a "q") #f))

;; check-resolves : String Components Components -> void
;; Resolve `r` against `base`, and assert the target equals `want` field for
;; field (uri-components=? keeps absent /= empty).
(define (check-resolves label r want)
  (check (string-append label " target")
         (uri-components=? (resolve-components base r) want)))

(harness-begin "unit.resolve")

;;; --- the five §5.2.2 branches, one representative each ----------------------
(harness-group "the §5.2.2 branches"
  (lambda ()
    ;; defined(R.scheme): T is R's own components (path only dot-removed); Base
    ;; contributes nothing, and a rootless path is NOT merged.
    (harness-case "a scheme-bearing reference takes R wholesale"
      (lambda ()
        (check-resolves "g:h"
                        (comp (a "g") #f (a "h") #f #f)
                        (comp (a "g") #f (a "h") #f #f))))

    ;; defined(R.authority): R's authority replaces Base's; only the scheme is
    ;; inherited. `//g` -> http://g, path is R's empty string, not Base.path.
    (harness-case "a network-path reference replaces the authority"
      (lambda ()
        (check-resolves "//g"
                        (comp #f (a "g") (a "") #f #f)
                        (comp (a "http") (a "g") (a "") #f #f))))

    ;; R.path == "" and R.query DEFINED: keep Base.path, take R.query.
    (harness-case "empty path, defined query: keep base path, take R.query"
      (lambda ()
        (check-resolves "?y"
                        (comp #f #f (a "") (a "y") #f)
                        (comp (a "http") (a "a") (a "/b/c/d;p") (a "y") #f))))

    ;; R.path == "" and R.query UNDEFINED: inherit BOTH Base.path and Base.query.
    ;; Fragment is always R's.
    (harness-case "empty path, no query: inherit base path AND base query"
      (lambda ()
        (check-resolves "#s"
                        (comp #f #f (a "") #f (a "s"))
                        (comp (a "http") (a "a") (a "/b/c/d;p") (a "q") (a "s")))))

    ;; The empty reference: path "" and query undefined -> Base.path and
    ;; Base.query; fragment R's (undefined) -> target is Base minus any fragment.
    (harness-case "the empty reference is the base without a fragment"
      (lambda ()
        (check-resolves "(empty)"
                        (comp #f #f (a "") #f #f)
                        (comp (a "http") (a "a") (a "/b/c/d;p") (a "q") #f))))

    ;; R.path rooted: dot-removed directly, NOT merged; authority+scheme from Base.
    (harness-case "an absolute-path reference is not merged"
      (lambda ()
        (check-resolves "/g"
                        (comp #f #f (a "/g") #f #f)
                        (comp (a "http") (a "a") (a "/g") #f #f))))

    ;; R.path relative nonempty: merge onto all-but-last of Base.path, then
    ;; dot-remove. `g` -> /b/c/g.
    (harness-case "a relative-path reference merges onto the base"
      (lambda ()
        (check-resolves "g"
                        (comp #f #f (a "g") #f #f)
                        (comp (a "http") (a "a") (a "/b/c/g") #f #f))))))

;;; --- the sharp cases: strict, and absent vs present-empty -------------------
(harness-group "strict, and absent /= empty"
  (lambda ()
    ;; STRICT: R.scheme == Base.scheme is NOT dropped -- http:g stays scheme
    ;; http + path g, never merged into http://a/b/c/g.
    (harness-case "http:g keeps its scheme and does not merge (strict)"
      (lambda ()
        (check-resolves "http:g"
                        (comp (a "http") #f (a "g") #f #f)
                        (comp (a "http") #f (a "g") #f #f))))

    ;; Excess `..` past root are discarded (§5.2.4 2C pops nothing on empty
    ;; output), so ../../../g -> /g, not /../g (decision 0015 rejects erratum 4547).
    (harness-case "excess up-levels are discarded, not leaked"
      (lambda ()
        (check-resolves "../../../g"
                        (comp #f #f (a "../../../g") #f #f)
                        (comp (a "http") (a "a") (a "/g") #f #f))))

    ;; R.query PRESENT-EMPTY (`?` with nothing after) in the empty-path branch:
    ;; defined, so T.query = R.query = "" -- NOT Base.query. The corpus has no
    ;; such row; this is the decisive absent/empty query distinction.
    (harness-case "an empty-but-present R.query is taken, not the base's"
      (lambda ()
        (check-resolves "? (empty query present)"
                        (comp #f #f (a "") (a "") #f)
                        (comp (a "http") (a "a") (a "/b/c/d;p") (a "") #f))))

    ;; R.authority PRESENT-EMPTY (`//` then nothing) is defined, so it is taken:
    ;; T.authority = "" and T.path = remove-dot-segments("") = "".
    (harness-case "an empty-but-present R.authority is taken"
      (lambda ()
        (check-resolves "// (empty authority present)"
                        (comp #f (a "") (a "") #f #f)
                        (comp (a "http") (a "") (a "") #f #f))))

    ;; T.fragment is ALWAYS R.fragment, never Base's -- pinned by a base that
    ;; carries a fragment and a scheme-bearing reference that has none.
    (harness-case "the target fragment is always the reference's"
      (lambda ()
        (let ((base+frag (comp (a "http") (a "a") (a "/b/c/d;p") (a "q") (a "old"))))
          (check "g:h drops the base fragment"
                 (uri-components=?
                  (resolve-components base+frag (comp (a "g") #f (a "h") #f #f))
                  (comp (a "g") #f (a "h") #f #f))))))))

;;; --- remove-dot-segments reaches every branch the RFC applies it in ---------
;;; The §5.4 corpus only ever feeds scheme- and authority-bearing references
;;; whose paths are dot-free (`g:h`, `//g`), and its base path is non-empty, so
;;; the corpus alone leaves three resolve paths unobserved: remove-dot-segments
;;; in §5.2.2 branch A (l.1746) and branch B (l.1751), and the base-authority
;;; flag resolve threads into merge (branch (a), §5.2.3). These are pinned here
;;; so none can be deleted while the suite stays green.
(harness-group "dot-removal and merge wiring in every branch"
  (lambda ()
    ;; BRANCH A: a scheme-bearing reference's path IS dot-removed.
    (harness-case "branch A dot-removes the reference path"
      (lambda ()
        (check-resolves "g:a/b/../c"
                        (comp (a "g") #f (a "a/b/../c") #f #f)
                        (comp (a "g") #f (a "a/c") #f #f))))

    ;; BRANCH B: a network-path reference's path IS dot-removed.
    (harness-case "branch B dot-removes the reference path"
      (lambda ()
        (check-resolves "//g/a/../b"
                        (comp #f (a "g") (a "/a/../b") #f #f)
                        (comp (a "http") (a "g") (a "/b") #f #f))))

    ;; BRANCH E wiring: resolve passes the base's authority-definedness into
    ;; merge, so a base with authority + EMPTY path takes §5.2.3 branch (a) and
    ;; roots the reference. http://a + g -> http://a/g, not http://ag.
    (harness-case "merge branch (a) fires through resolve for an empty-path base"
      (lambda ()
        (check "http://a + g -> http://a/g"
               (uri-components=?
                (resolve-components (comp (a "http") (a "a") (a "") #f #f)
                                    (comp #f #f (a "g") #f #f))
                (comp (a "http") (a "a") (a "/g") #f #f)))))

    ;; BRANCH C keeps Base.path RAW -- the base is assumed already normalized, so
    ;; a base path carrying a dot-segment is NOT dot-removed by an empty reference.
    (harness-case "branch C keeps the base path raw"
      (lambda ()
        (check "empty ref keeps base's /b/./c raw"
               (uri-components=?
                (resolve-components (comp (a "http") (a "a") (a "/b/./c") (a "q") #f)
                                    (comp #f #f (a "") #f #f))
                (comp (a "http") (a "a") (a "/b/./c") (a "q") #f)))))))

(harness-finish)
