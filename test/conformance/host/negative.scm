;;; M4 negative corpus -- authority inputs RFC 3986's host grammar REJECTS.
;;;
;;; AUTHORED, NOT EXTRACTED. Like test/conformance/charset/ (M3) and unlike
;;; test/conformance/rfc3986/ (derived from the vendored RFC text by
;;; cmake/UriCorpus.cmake), this file is HAND-DERIVED from the ABNF
;;; (test/conformance/rfc3986/rfc3986.abnf §3.2) -- the RFC lists no invalid URIs,
;;; so there is nothing to extract. Its provenance and separate count are recorded
;;; in PROVENANCE beside it (decisions 0005 item 3, 0025 item 7). Every offset is
;;; defended from the ABNF in its note and cross-checked against
;;; (uri test host-oracle), an independent reading of the same ABNF.
;;;
;;; A row is (mode input component code offset note):
;;;   mode      the parse mode (all `uri` here: an explicit scheme + "//" authority)
;;;   input     the bytes to parse -- a STRING (its UTF-8 bytes) for ASCII cases,
;;;             a #vu8(...) bytevector for the > 0x7F and control-byte cases
;;;   component the authority SUB-part the offending byte falls in
;;;             (userinfo / reg-name / port / ip-literal / dec-octet)
;;;   code      the core error code the validator must raise (decision 0025 item 6)
;;;   offset    the ABSOLUTE byte offset in `input` of the offending position --
;;;             the byte itself for a bad literal, the "%" for a malformed
;;;             pct-encoded, and the opening "[" for ANY IP-literal-interior fault
;;;             (including a dec-octet range error) per decision 0025 items 3-4
;;;   note      the ABNF ground for the rejection
;;;
;;; Every input is "http://<authority>...": "http://" is 7 bytes, so the authority
;;; begins at absolute offset 7. authority = [ userinfo "@" ] host [ ":" port ].
;;;
;;; REACHABILITY (decision 0025 item 3): dec-octet is reached ONLY through a
;;; bracketed literal -- a bare `999.1.1.1` is a valid reg-name (§3.2.2
;;; first-match-wins), NOT an error -- so every invalid-dec-octet row is inside
;;; "[" ... "]". The last two rows are TWO-FAULT authorities that pin the
;;; leftmost visit order userinfo → host → port.
(negatives
  ;; --- userinfo = *( unreserved / pct-encoded / sub-delims / ":" ) ----------
  (uri "http://us er@host" userinfo invalid-userinfo 9
       "space (0x20) is not in the userinfo set; it falls before the \"@\" at 12")
  (uri "http://a<b@host" userinfo invalid-userinfo 8
       "\"<\" (0x3C) is outside the URI charset; not unreserved / sub-delim / \":\"")
  (uri "http://a%zz@host" userinfo invalid-pct-encoded 8
       "\"%zz\" in userinfo: \"z\" is not HEXDIG, reported at the \"%\"")

  ;; --- host as reg-name = *( unreserved / pct-encoded / sub-delims ) --------
  (uri "http://exa mple.com" reg-name invalid-reg-name 10
       "space (0x20) is not in the reg-name set (the design's headline host case)")
  (uri "http://h<st" reg-name invalid-reg-name 8
       "\"<\" (0x3C) is neither unreserved nor a sub-delim")
  (uri "http://a@b@c" reg-name invalid-reg-name 10
       "the FIRST \"@\" (8) splits userinfo=\"a\"; the SECOND \"@\" (10) is not reg-name")
  (uri #vu8(104 116 116 112 58 47 47 104 233) reg-name invalid-reg-name 8
       "0xE9 > 0x7F: a non-ASCII byte must be pct-encoded, so it is not reg-name")
  (uri "http://h%g/p" reg-name invalid-pct-encoded 8
       "\"%g\" in reg-name: \"g\" is not HEXDIG; the \"/\" at 10 ends the authority")

  ;; --- port = *DIGIT (reported at the first non-digit) ----------------------
  (uri "http://host:8x0" port invalid-port 13
       "port \"8x0\": \"x\" (0x78) is not a DIGIT; the port \":\" is at 11")
  (uri "http://h:a" port invalid-port 9
       "port \"a\": a bare non-digit port; the port begins right after the \":\" at 8")
  (uri "http://host:12 3" port invalid-port 14
       "port \"12 3\": the space (0x20) is not a DIGIT")

  ;; --- IP-literal = "[" ( IPv6address / IPvFuture ) "]" (reported at "[") ----
  (uri "http://[::1" ip-literal invalid-ip-literal 7
       "unterminated IP-literal: no closing \"]\"")
  (uri "http://[xyz]/p" ip-literal invalid-ip-literal 7
       "\"xyz\" is neither IPv6address nor IPvFuture (\"x\" is not HEXDIG, not \"v\")")
  (uri "http://[1:2:3:4:5:6:7:8:9]" ip-literal invalid-ip-literal 7
       "nine h16 groups and no \"::\": IPv6address is exactly eight 16-bit pieces")
  (uri "http://[12345::1]" ip-literal invalid-ip-literal 7
       "h16 \"12345\" is five HEXDIG; h16 = 1*4HEXDIG")
  (uri "http://[]" ip-literal invalid-ip-literal 7
       "empty IP-literal: the minimal IPv6address is \"::\", never empty")

  ;; --- dec-octet 0-255, reachable ONLY inside a bracketed IPv4 tail ---------
  (uri "http://[::ffff:999.1.1.1]" dec-octet invalid-dec-octet 7
       "embedded IPv4 tail dec-octet \"999\" > 255; bare \"999...\" would be reg-name")
  (uri "http://[::1.2.3.256]" dec-octet invalid-dec-octet 7
       "embedded IPv4 tail dec-octet \"256\" > 255 (the \"25\" %x30-35 edge)")

  ;; --- leftmost wins: two-fault authorities pin userinfo → host → port ------
  (uri "http://us er@ho st:8x" userinfo invalid-userinfo 9
       "userinfo, host AND port are all bad; the leftmost (userinfo space at 9) wins")
  (uri "http://ho st:8x0" reg-name invalid-reg-name 9
       "host AND port are both bad; the leftmost (host space at 9, before the port) wins")
)
