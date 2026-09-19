;;; M3 negative corpus -- inputs RFC 3986's charset productions REJECT.
;;;
;;; AUTHORED, NOT EXTRACTED. Unlike test/conformance/rfc3986/, which is derived
;;; from the vendored RFC text by cmake/UriCorpus.cmake, this file is HAND-DERIVED
;;; from the ABNF (test/conformance/rfc3986/rfc3986.abnf) -- the RFC lists no
;;; invalid URIs, so there is nothing to extract. Its provenance and separate
;;; count are recorded in PROVENANCE beside it (decisions 0005 item 3, 0024 item
;;; 6). Every offset is defended from the ABNF in its note and cross-checked
;;; against (uri test charset-oracle), an independent reading of the same ABNF.
;;;
;;; A row is (mode input component code offset note):
;;;   mode      the parse mode the scanner runs in (uri / relative-ref / uri-reference)
;;;   input     the bytes to parse -- a STRING (its UTF-8 bytes) for ASCII cases,
;;;             a #vu8(...) bytevector for the > 0x7F and control-byte cases a
;;;             string cannot carry
;;;   component the M3 component the offending byte falls in
;;;   code      the core error code the validator must raise (decision 0024 item 5)
;;;   offset    the ABSOLUTE byte offset in `input` of the offending position --
;;;             the byte itself for a bad literal, the "%" for a malformed
;;;             pct-encoded (decision 0024 item 3)
;;;   note      the ABNF ground for the rejection
;;;
;;; SCOPE (decision 0024 item 2): scheme, path, query, fragment, pct-encoded only.
;;; port and the authority-interior charsets are M4.
(negatives
  ;; --- scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." ) ------------------
  (uri ":x"      scheme invalid-scheme 0
       "empty scheme: the production requires a leading ALPHA, and there is none")
  (uri "1a:x"    scheme invalid-scheme 0
       "scheme first byte \"1\" (0x31) is DIGIT; the first byte must be ALPHA")
  (uri "a*b:x"   scheme invalid-scheme 1
       "\"*\" (0x2A) is a sub-delim, not one of ALPHA / DIGIT / \"+\" / \"-\" / \".\"")
  (uri "ab_c:x"  scheme invalid-scheme 2
       "\"_\" (0x5F) is unreserved but is NOT admitted by scheme")

  ;; --- path = *( pchar / "/" );  pchar = unreserved / pct-encoded / sub-delims / ":" / "@"
  (uri "http://h/a b" path invalid-pchar 10
       "space (0x20) is not pchar; the path byte at offset 10 is a raw space")
  (relative-ref "a<b" path invalid-pchar 1
       "\"<\" (0x3C) is neither unreserved, sub-delim, \":\", \"@\" nor \"/\"")
  (uri #vu8(104 116 116 112 58 47 47 104 47 233) path invalid-pchar 9
       "0xE9 > 0x7F: a non-ASCII byte must be pct-encoded, so it is not pchar")
  (uri #vu8(104 116 116 112 58 47 47 104 47 9) path invalid-pchar 9
       "0x09 (TAB) is a control byte, not pchar")

  ;; --- pct-encoded = "%" HEXDIG HEXDIG (reported at the "%") ----------------
  (uri "http://h/a%" path invalid-pct-encoded 10
       "\"%\" at end of input: no HEXDIG follows")
  (uri "http://h/%g0/y" path invalid-pct-encoded 9
       "\"%g0\": \"g\" (0x67) is not HEXDIG (HEXDIG is 0-9 A-F a-f)")
  (uri "http://h/%4G" path invalid-pct-encoded 9
       "\"%4G\": the second digit \"G\" (0x47) is not HEXDIG")
  (uri "http://h/%A" path invalid-pct-encoded 9
       "\"%A\": only one HEXDIG follows the \"%\", not two")

  ;; --- query = *( pchar / "/" / "?" ) --------------------------------------
  (uri "http://h/p?a b" query invalid-query 12
       "space (0x20) is not in the query set")

  ;; --- fragment = *( pchar / "/" / "?" ) -----------------------------------
  (uri "http://h/p#a b" fragment invalid-fragment 12
       "space (0x20) is not in the fragment set")
  (uri #vu8(104 116 116 112 58 47 47 104 47 112 35 233) fragment invalid-fragment 11
       "0xE9 > 0x7F: a non-ASCII byte must be pct-encoded, so it is not in the fragment set")
)
