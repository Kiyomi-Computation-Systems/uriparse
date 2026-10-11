;;; RFC 3986 section 5.4 -- Reference Resolution Examples.
;;;
;;; DERIVED from test/vendor/rfc3986.txt by cmake/UriCorpus.cmake. Do not edit:
;;; `make corpus-refresh` rewrites this file and a lane re-derives it and
;;; compares, so a hand edit reddens rather than surviving.
;;;
;;; Each row is (<section> <reference> <target>), resolved against the base
;;; section 5.4 declares. Erratum 4547, which would rewrite two of the 5.4.2
;;; rows, is not adopted; they are here exactly as published.
(base "http://a/b/c/d;p?q")
(vectors
  ("5.4.1" "g:h" "g:h")
  ("5.4.1" "g" "http://a/b/c/g")
  ("5.4.1" "./g" "http://a/b/c/g")
  ("5.4.1" "g/" "http://a/b/c/g/")
  ("5.4.1" "/g" "http://a/g")
  ("5.4.1" "//g" "http://g")
  ("5.4.1" "?y" "http://a/b/c/d;p?y")
  ("5.4.1" "g?y" "http://a/b/c/g?y")
  ("5.4.1" "#s" "http://a/b/c/d;p?q#s")
  ("5.4.1" "g#s" "http://a/b/c/g#s")
  ("5.4.1" "g?y#s" "http://a/b/c/g?y#s")
  ("5.4.1" ";x" "http://a/b/c/;x")
  ("5.4.1" "g;x" "http://a/b/c/g;x")
  ("5.4.1" "g;x?y#s" "http://a/b/c/g;x?y#s")
  ("5.4.1" "" "http://a/b/c/d;p?q")
  ("5.4.1" "." "http://a/b/c/")
  ("5.4.1" "./" "http://a/b/c/")
  ("5.4.1" ".." "http://a/b/")
  ("5.4.1" "../" "http://a/b/")
  ("5.4.1" "../g" "http://a/b/g")
  ("5.4.1" "../.." "http://a/")
  ("5.4.1" "../../" "http://a/")
  ("5.4.1" "../../g" "http://a/g")
  ("5.4.2" "../../../g" "http://a/g")
  ("5.4.2" "../../../../g" "http://a/g")
  ("5.4.2" "/./g" "http://a/g")
  ("5.4.2" "/../g" "http://a/g")
  ("5.4.2" "g." "http://a/b/c/g.")
  ("5.4.2" ".g" "http://a/b/c/.g")
  ("5.4.2" "g.." "http://a/b/c/g..")
  ("5.4.2" "..g" "http://a/b/c/..g")
  ("5.4.2" "./../g" "http://a/b/g")
  ("5.4.2" "./g/." "http://a/b/c/g/")
  ("5.4.2" "g/./h" "http://a/b/c/g/h")
  ("5.4.2" "g/../h" "http://a/b/c/h")
  ("5.4.2" "g;x=1/./y" "http://a/b/c/g;x=1/y")
  ("5.4.2" "g;x=1/../y" "http://a/b/c/y")
  ("5.4.2" "g?y/./x" "http://a/b/c/g?y/./x")
  ("5.4.2" "g?y/../x" "http://a/b/c/g?y/../x")
  ("5.4.2" "g#s/./x" "http://a/b/c/g#s/./x")
  ("5.4.2" "g#s/../x" "http://a/b/c/g#s/../x")
  ("5.4.2" "http:g" "http:g")
)
;;; The one row in section 5.4.2 for which the RFC gives TWO answers. Strict
;;; resolution (section 5.2.2 with strict = true) is what this project
;;; implements and is the row above; the loophole is recorded rather than
;;; silently dropped, because a reader who finds it in the RFC will look for it
;;; here. RFC 1630 partial-URI compatibility is out of scope.
(note ("5.4.2" "http:g" backward-compatible "http://a/b/c/g"))
