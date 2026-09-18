#!r6rs
;;; (uri grammar): the byte-machine source machine for the URI scanner.
;;;
;;; Build-time only (design §5): this library constructs the machine that the
;;; emitter renders to `(generated uri-scanner)`. It imports `(byte-machine
;;; graph)` (the builder) and `(uri vocabulary)` (the agreed integers), and it is
;;; never on the shipped runtime path.
;;;
;;; SLICE ① scope: modes 1 (URI) and 2 (relative-ref), delimiter-only. It opens
;;; five spans -- scheme, host, path, query, fragment -- and fires the `on-rooted`
;;; verdict event. The `host` span is the WHOLE authority (userinfo/host/port are
;;; not sub-split until Slice ①b); this is exact wherever an authority is just a
;;; host. Mode 3 (uri-reference) and the leading-token span are Slice ②.
;;;
;;; THE `//` IMPOSSIBILITY AND `on-rooted` (decision 0018). A leading `/` after a
;;; scheme is a delimiter in `//h` but path content in `/p`, and byte-machine
;;; cannot keep it both ways (forward-only, no rewind, the span mark is the
;;; cursor at open). So the host span carries authority presence byte-perfectly
;;; and a path-absolute's leading `/` is dropped from the path span and recovered
;;; by the zero-width `on-rooted` event, which `(uri collect)` reads to prepend
;;; the `/`. Verified in the session's verdict-spike; the pre-open alternative
;;; fires a phantom `//` path fragment on every authority case and is worse.
;;;
;;; GRAMMAR-AUTHOR RULE (verify.sls, non-eof-into-finish): a byte edge may not
;;; target `finish`; only an EOF transition may. Every arm reaches `done` through
;;; a dispatch's eof-target and a zero-width span chain, never a byte edge.
(library (uri grammar)
  (export make-uri-scanner-machine)
  (import (rnrs)
          (byte-machine graph)
          (uri vocabulary))

  ;; --- delimiter bytes -----------------------------------------------------
  (define SLASH 47)    (define QUESTION 63)
  (define HASH 35)     (define COLON 58)

  ;; --- construction shorthands --------------------------------------------
  (define (adv t) (make-edge t 'advance))
  (define (rex t) (make-edge t 'reexecute))
  (define (one b) (make-exact-byte-matcher b))
  (define (set* . bs) (make-byte-set-matcher bs))
  (define (kase m e) (make-byte-case m e #f))
  ;; a dispatch that consumes exactly one known byte, then goes to `next`
  (define (eat name next) (make-byte-dispatch-node name '() (adv next) #f #f))
  ;; a dispatch that consumes every byte until eof (the delimiter cases lead out)
  (define (scan name cases eof) (make-byte-dispatch-node name cases (adv name) eof #f))

  (define (make-uri-scanner-machine)
    (make-machine
     'uri-scanner 'm-dispatch
     ;; fields: the mode selector (decision 0004), width from the vocabulary
     (list (make-uint-field 'mode uri-mode-width 0 #t #f))
     ;; callbacks: five spans' data+complete, and the rooted verdict event
     (list (make-callback-declaration 'on-scheme-data     'span-data     #f '() #f #f)
           (make-callback-declaration 'on-scheme-complete  'span-complete #f '() #f #f)
           (make-callback-declaration 'on-host-data        'span-data     #f '() #f #f)
           (make-callback-declaration 'on-host-complete    'span-complete #f '() #f #f)
           (make-callback-declaration 'on-path-data        'span-data     #f '() #f #f)
           (make-callback-declaration 'on-path-complete    'span-complete #f '() #f #f)
           (make-callback-declaration 'on-query-data       'span-data     #f '() #f #f)
           (make-callback-declaration 'on-query-complete   'span-complete #f '() #f #f)
           (make-callback-declaration 'on-fragment-data    'span-data     #f '() #f #f)
           (make-callback-declaration 'on-fragment-complete 'span-complete #f '() #f #f)
           (make-callback-declaration 'on-rooted           'event         #f '() #f #f))
     ;; spans (Slice ① subset): each carries both callbacks (decision 0008 item 5)
     (list (make-span-declaration 'scheme   'on-scheme-data   'on-scheme-complete   #f)
           (make-span-declaration 'host     'on-host-data     'on-host-complete     #f)
           (make-span-declaration 'path     'on-path-data     'on-path-complete     #f)
           (make-span-declaration 'query    'on-query-data    'on-query-complete    #f)
           (make-span-declaration 'fragment 'on-fragment-data 'on-fragment-complete #f))
     ;; errors: the Slice ① reachable set (decision 0009). invalid-ip-literal is
     ;; Slice ①b's; unexpected-eof is the mandatory machine default.
     (list (make-error-declaration 'e-mode-unset      'mode-unset      "no parse mode was chosen" #f)
           (make-error-declaration 'e-scheme-required 'scheme-required "expected a scheme terminated by \":\"" #f)
           (make-error-declaration 'e-scheme-forbidden 'scheme-forbidden "a \":\" in the first segment of a relative reference" #f)
           (make-error-declaration 'e-eof             'unexpected-eof  "input ended inside an unsatisfiable production" #f))
     (list
      ;; --- mode dispatch (zero-width, at offset 0) -------------------------
      (make-field-branch-node 'm-dispatch 'equal (list 'mode (uri-mode-value 'uri))
                              'uri-scheme-open 'm-try2 #f)
      (make-field-branch-node 'm-try2 'equal (list 'mode (uri-mode-value 'relative-ref))
                              'hier2 'e-mode-unset #f)
      ;; mode 0 (unset), 3 (uri-reference; Slice ②) and any other value fall to
      ;; e-mode-unset here. Slice ② replaces m-try2's false arm with the mode-3
      ;; leading-token scanner.

      ;; --- mode 1: the scheme ---------------------------------------------
      (make-span-start-node 'uri-scheme-open 'scheme 'scheme-scan #f)
      (make-byte-dispatch-node 'scheme-scan
        (list (kase (one COLON) (rex 'scheme-close))
              (kase (set* SLASH QUESTION HASH) (rex 'e-scheme-required)))
        (adv 'scheme-scan) 'e-scheme-required #f)
      (make-span-end-node 'scheme-close 'scheme 'eat-colon #f)
      (eat 'eat-colon 'hier)                    ; consume the ":"

      ;; --- the hier junction (after ":" in mode 1, at start in mode 2) -----
      ;; The two modes differ only in the fallback: mode 1's leading token is a
      ;; rootless path (":" is a legal pchar), mode 2's is a path-noscheme whose
      ;; first segment forbids ":".
      (make-byte-dispatch-node 'hier
        (list (kase (one SLASH) (adv 'hier-slash1)))
        (rex 'path-open) 'path-open #f)
      (make-byte-dispatch-node 'hier2
        (list (kase (one SLASH) (adv 'hier-slash1)))
        (rex 'path-nc-open) 'path-open #f)

      ;; --- the leading slash: "//" (authority) vs "/" (path-absolute) ------
      (make-byte-dispatch-node 'hier-slash1
        (list (kase (one SLASH) (adv 'auth-open)))    ; "//" => authority
        (rex 'say-rooted) 'say-rooted #f)             ; "/x" or "/"<eof> => path-absolute
      ;; the dropped leading "/" is announced here, then path opens past it
      (make-callback-node 'say-rooted 'on-rooted 'path-open '() 'path-open #f)

      ;; --- the authority as one host span (Slice ①) ------------------------
      (make-span-start-node 'auth-open 'host 'host-scan #f)
      (scan 'host-scan (list (kase (set* SLASH QUESTION HASH) (rex 'host-close))) 'host-close)
      (make-span-end-node 'host-close 'host 'path-open #f)

      ;; --- the path (shared; ":" is a legal pchar) -------------------------
      (make-span-start-node 'path-open 'path 'path-scan #f)
      (make-byte-dispatch-node 'path-scan
        (list (kase (one QUESTION) (rex 'path-close-q))
              (kase (one HASH) (rex 'path-close-f)))
        (adv 'path-scan) 'path-close-end #f)
      (make-span-end-node 'path-close-q 'path 'query-at #f)
      (make-span-end-node 'path-close-f 'path 'frag-at #f)
      (make-span-end-node 'path-close-end 'path 'done #f)

      ;; --- mode 2's path-noscheme first segment (":" forbidden) ------------
      (make-span-start-node 'path-nc-open 'path 'path-nc-first #f)
      (make-byte-dispatch-node 'path-nc-first
        (list (kase (one COLON) (rex 'e-scheme-forbidden))   ; ":" before any "/" => scheme-forbidden
              (kase (one SLASH) (adv 'path-scan))            ; first segment done; ":" now legal
              (kase (one QUESTION) (rex 'path-close-q))
              (kase (one HASH) (rex 'path-close-f)))
        (adv 'path-nc-first) 'path-close-end #f)

      ;; --- the query ("?" and "/" are content; "#" ends it) ----------------
      (eat 'query-at 'query-open)               ; consume the "?"
      (make-span-start-node 'query-open 'query 'query-scan #f)
      (make-byte-dispatch-node 'query-scan
        (list (kase (one HASH) (rex 'query-close-f)))
        (adv 'query-scan) 'query-close-end #f)
      (make-span-end-node 'query-close-f 'query 'frag-at #f)
      (make-span-end-node 'query-close-end 'query 'done #f)

      ;; --- the fragment (nothing but EOF ends it) --------------------------
      (eat 'frag-at 'frag-open)                 ; consume the "#"
      (make-span-start-node 'frag-open 'fragment 'frag-scan #f)
      (make-byte-dispatch-node 'frag-scan '() (adv 'frag-scan) 'frag-close-end #f)
      (make-span-end-node 'frag-close-end 'fragment 'done #f)

      ;; --- terminals -------------------------------------------------------
      (make-finish-node 'done #f)
      (make-error-node 'e-mode-unset 'e-mode-unset #f)
      (make-error-node 'e-scheme-required 'e-scheme-required #f)
      (make-error-node 'e-scheme-forbidden 'e-scheme-forbidden #f))
     'e-eof #f)))
