#!r6rs
;;; (uri resolve): RFC 3986 §5.2.2 reference resolution -- transform a parsed
;;; URI-reference R into its target components T against a base URI's components.
;;;
;;; STRICT (§5.2.2 with strict = true). The non-strict shortcut -- ignore R's
;;; scheme when it equals the base's -- is NOT taken: the one §5.4.2 row it
;;; touches (`http:g`) resolves to `http:g`, not `http://a/b/c/g`, and the RFC
;;; calls the shortcut a backward-compatibility allowance for older parsers
;;; (RFC 1630 partial-URI compatibility is out of scope). The
;;; corpus records the loophole in a `(note ...)` and this project implements the
;;; strict row.
;;;
;;; PURE over `uri-components`: the base and R are the components `(uri
;;; collect)` produces; the target is components, which `(uri recompose)` (§5.3)
;;; renders to a string. Resolution does NOT normalize (§6 is a separate
;;; operation) and does not touch the query or fragment's own bytes -- only the
;;; path is dot-segment-removed, which is why the scanner must have already
;;; split the query and fragment off the path (RFC 3986 §5.2.4's Note), as the
;;; scanner does.
;;;
;;; The absent/empty distinction is load-bearing here: §5.2.2
;;; branches on `defined(R.authority)` and `defined(R.query)` (present, even if
;;; empty), and on `R.path == ""` (present and empty). `http:/p` and `http:///p`
;;; resolve differently precisely because the first has an absent authority and
;;; the second an empty-but-present one.
;;;
;;; A CALLER WANTING NORMALIZED RESULTS normalizes FIRST, then resolves: `(uri
;;; normalize)`'s `pct-normalize` decodes `%2E` to a literal `.`, so a
;;; normalized path can carry dot-segments that §5.2.4 here then removes --
;;; resolving a RAW path would let `%2E%2E%2F` survive as live `../`. This
;;; library resolves whatever components it is given; the composition order is
;;; the caller's to get right, and normalize-before-resolve is the safe one.
;;;
;;; resolve-components : Components Components -> Components
(library (uri resolve)
  (export resolve-components)
  (import (rnrs)
          (uri components)
          (uri path))

  (define SLASH 47)                         ; #\/

  ;; §5.2.2 defined(x): the component is present (a bytevector), not #f.
  (define (defined? v) (uri-component-present? v))

  ;; R.path == "" : the path is present (it always is) and zero-length.
  (define (path-empty? p) (fx=? (bytevector-length p) 0))

  ;; R.path starts-with "/".
  (define (path-rooted? p)
    (and (fx>? (bytevector-length p) 0)
         (fx=? (bytevector-u8-ref p 0) SLASH)))

  ;; resolve-components : Components Components -> Components
  ;; §5.2.2's pseudocode, arm for arm. `base` is the base URI's components (it
  ;; must have a defined scheme to be absolute); `r` is the reference's. Both
  ;; must carry a PRESENT path -- a bytevector, possibly empty, never `#f` --
  ;; which is what `(uri collect)` always produces (a path is never absent);
  ;; §5.2.2 assumes it, so this reads the path unguarded. Returns
  ;; the target's components. T.fragment is always R.fragment.
  (define (resolve-components base r)
    (let ((rs (uri-components-scheme r))    (ra (uri-components-authority r))
          (rp (uri-components-path r))      (rq (uri-components-query r))
          (rf (uri-components-fragment r))
          (bs (uri-components-scheme base))  (ba (uri-components-authority base))
          (bp (uri-components-path base))    (bq (uri-components-query base)))
      (let-values
          (((ts ta tp tq)
            (cond
             ;; if defined(R.scheme): take R's scheme/authority/query wholesale
             ((defined? rs)
              (values rs ra (remove-dot-segments rp) rq))
             ;; else T.scheme = Base.scheme, and the rest by R.authority / R.path:
             ((defined? ra)
              (values bs ra (remove-dot-segments rp) rq))
             ;; R.path == "": keep the base path; keep R.query if defined, else base's
             ((path-empty? rp)
              (values bs ba bp (if (defined? rq) rq bq)))
             ;; R.path nonempty: rooted -> as is; relative -> merge onto base path
             (else
              (let ((path (if (path-rooted? rp)
                              (remove-dot-segments rp)
                              (remove-dot-segments (merge (defined? ba) bp rp)))))
                (values bs ba path rq))))))
        (make-uri-components ts ta tp tq rf)))))
