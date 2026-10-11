;;; Authority-form corpus -- RFC 9112 §3.2.3 CONNECT request-targets.
;;;
;;; AUTHORED, NOT EXTRACTED. RFC 9112 is not vendored (only RFC 3986 is), so -- like
;;; test/conformance/host/ and test/conformance/charset/ -- this file is
;;; HAND-DERIVED from RFC 9112 §3.2.3 (`authority-form = uri-host ":" port`), which
;;; reuses RFC 3986 §3.2's `host` and `port`. Its provenance and separate count are
;;; recorded in PROVENANCE beside it.
;;;
;;; It grades BOTH entry points at once. A row is (input lenient strict note):
;;;   input    the raw authority-form target -- a STRING (its UTF-8 bytes). NO scheme,
;;;            NO "//", NO "http://" prefix: the authority begins at OFFSET 0, so every
;;;            offset below is already in the caller's coordinates.
;;;   lenient  the expected `uri-parse-authority-form` result: `ok`, or (code offset).
;;;   strict   the expected `uri-parse-authority-form-validate` result: `ok`, or
;;;            (code offset).
;;;   note     the RFC 9112 §3.2.3 (or reused RFC 3986 §3.2) ground for the verdict.
;;;
;;; authority-form is a strict SUBSET of RFC 3986 `authority = [ userinfo "@" ] host
;;; [ ":" port ]`: NO userinfo, a REQUIRED non-empty port, and -- being neither a URI
;;; nor a relative-ref -- NO path/query/fragment. The lenient parse is non-validating
;;; (like uri-parse): it splits the authority and rejects only a trailing
;;; path/query/fragment (`not-authority-form`). The strict form adds, LEFTMOST-first,
;;; `userinfo-forbidden` -> the host grammar (validate-authority) -> `port-required`.
(authority-form
  ;; --- valid CONNECT targets: accepted by BOTH -----------------------------
  ("example.com:443"    ok                     ok                     "canonical DNS host:port")
  ("[::1]:443"          ok                     ok                     "IPv6 literal host")
  ("[2001:db8::1]:8080" ok                     ok                     "full IPv6 literal host:port")
  ("192.168.1.1:8080"   ok                     ok                     "IPv4address host:port")

  ;; --- trailing component: NOT authority-form, both reject -----------------
  ;; the fault is the first byte past the authority = the authority's length.
  ("host:443/p"         (not-authority-form 8) (not-authority-form 8) "trailing path -- authority-form has no path")
  ("host:443?q"         (not-authority-form 8) (not-authority-form 8) "trailing query -- authority-form has no query")
  ("host:443#f"         (not-authority-form 8) (not-authority-form 8) "trailing fragment -- authority-form has no fragment")

  ;; --- lenient accepts (a bare authority); strict enforces §3.2.3 ----------
  ("user@host:443"      ok                     (userinfo-forbidden 4) "userinfo -- §3.2.3 drops the [ userinfo \"@\" ] prefix; the \"@\" at 4")
  ("host"               ok                     (port-required 4)      "no port -- §3.2.3 is host \":\" port; reported at the end")
  ("host:"              ok                     (port-required 5)      "empty port -- valid RFC 3986 (*DIGIT), INVALID RFC 9112")
  ("ho st:443"          ok                     (invalid-reg-name 2)   "space in host -- lenient is non-validating; strict runs the host grammar")
  ("ho st"              ok                     (invalid-reg-name 2)   "bad host AND no port: the host fault (2) is leftmost, before the port -- pins host < port")

  ;; --- leftmost order: the fault is reported userinfo -> host -> port -------
  ("user@ho st:443"     ok                     (userinfo-forbidden 4) "userinfo AND a host space: userinfo (\"@\" at 4) beats the host fault (7)")
  ("user@host"          ok                     (userinfo-forbidden 4) "userinfo AND no port: userinfo (\"@\" at 4) beats the missing port")

  ;; --- an \"@\" inside an IP-literal is NOT userinfo (bracket-aware) ----------
  ("user@[::1]:443"     ok                     (userinfo-forbidden 4) "REAL userinfo before an IP-literal host: the \"@\" (4) precedes the \"[\"")
  ("[a@b]:443"          ok                     (invalid-userinfo 0)   "an \"@\" INSIDE \"[...]\" is literal, not a delimiter: a malformed literal -> the host grammar (invalid-userinfo), NOT userinfo-forbidden")

  ;; --- empty target: an empty authority, but §3.2.3 wants a port -----------
  (""                   ok                     (port-required 0)      "empty target -- no host, no port"))
