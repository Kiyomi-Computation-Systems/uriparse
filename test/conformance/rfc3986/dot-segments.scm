;;; RFC 3986 section 5.2.4 -- remove_dot_segments, worked step by step.
;;;
;;; DERIVED from test/vendor/rfc3986.txt by cmake/UriCorpus.cmake. Do not edit.
;;;
;;; Each row is (<trace> <step> <output-buffer> <input-buffer>): the state of
;;; the two buffers AFTER the named step of the algorithm. Trace 1 is
;;; /a/b/c/./../../g and trace 2 is mid/content=5/../6. The last row of a trace
;;; carries an empty input buffer and its output buffer is the result.
(steps
  (1 "1" "" "/a/b/c/./../../g")
  (1 "2E" "/a" "/b/c/./../../g")
  (1 "2E" "/a/b" "/c/./../../g")
  (1 "2E" "/a/b/c" "/./../../g")
  (1 "2B" "/a/b/c" "/../../g")
  (1 "2C" "/a/b" "/../g")
  (1 "2C" "/a" "/g")
  (1 "2E" "/a/g" "")
  (2 "1" "" "mid/content=5/../6")
  (2 "2E" "mid" "/content=5/../6")
  (2 "2E" "mid/content=5" "/../6")
  (2 "2C" "mid" "/6")
  (2 "2E" "mid/6" "")
)
