# Deriving this project's conformance corpus from RFC 3986's own text.
#
# Decision 0005 makes the RFC's vectors the anchor of the resolution layer and
# says every vector cites its section. Hand transcription would make that a
# claim; this makes it a derivation. The RFC text is vendored verbatim at
# test/vendor/rfc3986.txt with its digest recorded in the corpus PROVENANCE
# file, and everything under test/conformance/rfc3986/ is produced from it by
# the one function below.
#
# EVERY ANCHOR IS FOUND IN REVERSE. Each heading appears twice in an RFC --
# once in the table of contents and once as the section -- and a forward FIND
# lands on the TOC line, whose "region" contains no vectors at all. The first
# run of this extractor emitted an empty corpus for exactly that reason, which
# is why each function below also refuses a region it found nothing in.
#
# ONE FUNCTION, TWO CALLERS, which is the rule that makes the provenance
# falsifiable rather than asserted: `make corpus-refresh` writes the files
# (UriCorpusRefresh.cmake) and a registered lane re-derives them and compares
# (CorpusProvenanceSpec.cmake). A corpus edited by hand therefore reddens.
#
# SECTION AND STEP LABELS ARE STRINGS, NOT BARE TOKENS. `5.4.1` and `2E` look
# like natural datums and are not: R6RS forbids an identifier beginning with a
# digit, and neither is a number, so a strict reader rejects both. Chez happens
# to accept them; Racket and Guile are the reason not to rely on that
# (decision 0007).
#
# THE SEMICOLON HAZARD. CMake's list separator is `;`, and RFC 3986's vectors
# are full of it -- ";x", "g;x", the base's own "d;p?q". A MATCHALL result
# containing one would split into two elements and silently corrupt a vector.
# Every extracted span is therefore carried with `;` replaced by the sentinel
# below and restored only as it is written out.

include_guard(GLOBAL)

set(URI_CORPUS_SEMI "@URI-SEMI@")

function(_uri_corpus_protect out text)
  string(REPLACE ";" "${URI_CORPUS_SEMI}" protected "${text}")
  set(${out} "${protected}" PARENT_SCOPE)
endfunction()

function(_uri_corpus_restore out text)
  string(REPLACE "${URI_CORPUS_SEMI}" ";" restored "${text}")
  set(${out} "${restored}" PARENT_SCOPE)
endfunction()

# Every `      "<ref>"    =  "<target>"` line in a region, as Scheme rows.
# `[^"]*` rather than a non-greedy quantifier: CMake's regex engine has none.
# An extractor that found nothing must FAIL, not emit an empty corpus that
# every lane over it then passes vacuously. The counts are the RFC's own and
# are the one number in this file that is written down rather than derived --
# which is the point: if the vendored text changes, this is what says so.
function(uri_corpus_require_rows rows expected what)
  string(REGEX MATCHALL "\n" newlines "${rows}")
  list(LENGTH newlines actual)
  if(NOT actual EQUAL expected)
    message(FATAL_ERROR
      "uri-corpus: expected ${expected} rows from ${what}, extracted "
      "${actual}. Either the vendored RFC text changed or this extractor's "
      "anchors no longer describe it; an empty or short corpus must never "
      "be written, because every lane over it would then pass vacuously.")
  endif()
endfunction()

function(_uri_corpus_pairs out region section)
  set(rows "")
  _uri_corpus_protect(region "${region}")
  string(REGEX MATCHALL "\n[ \t]+\"[^\"]*\"[ \t]+=[ \t]+\"[^\"]*\"" hits "${region}")
  foreach(hit IN LISTS hits)
    string(REGEX MATCH "\"([^\"]*)\"[ \t]+=[ \t]+\"([^\"]*)\"" _m "${hit}")
    _uri_corpus_restore(ref "${CMAKE_MATCH_1}")
    _uri_corpus_restore(target "${CMAKE_MATCH_2}")
    string(APPEND rows "  (\"${section}\" \"${ref}\" \"${target}\")\n")
  endforeach()
  set(${out} "${rows}" PARENT_SCOPE)
endfunction()

# uri_corpus_resolution(<rfc-text> <out>)
#
# RFC 3986 section 5.4: the reference-resolution vectors, all against the one
# base the section declares. Section 5.4.1 is "Normal Examples" and 5.4.2 is
# "Abnormal Examples"; the split is the RFC's own and is carried per row.
function(uri_corpus_resolution rfc out)
  string(FIND "${rfc}" "5.4.1.  Normal Examples" a REVERSE)
  string(FIND "${rfc}" "5.4.2.  Abnormal Examples" b REVERSE)
  string(FIND "${rfc}" "6.  Normalization and Comparison" c REVERSE)
  if(a LESS 0 OR b LESS 0 OR c LESS 0)
    message(FATAL_ERROR
      "uri-corpus: RFC 3986 section 5.4 was not found in the vendored text. "
      "The extractor's anchors no longer describe the source, so it would "
      "otherwise emit an empty corpus and every lane over it would pass.")
  endif()
  math(EXPR normal_len "${b} - ${a}")
  math(EXPR abnormal_len "${c} - ${b}")
  string(SUBSTRING "${rfc}" ${a} ${normal_len} normal)
  string(SUBSTRING "${rfc}" ${b} ${abnormal_len} abnormal)

  _uri_corpus_pairs(normal_rows "${normal}" "5.4.1")
  _uri_corpus_pairs(abnormal_rows "${abnormal}" "5.4.2")
  uri_corpus_require_rows("${normal_rows}" 23 "section 5.4.1")
  uri_corpus_require_rows("${abnormal_rows}" 19 "section 5.4.2")

  set(${out}
";;; RFC 3986 section 5.4 -- Reference Resolution Examples.
;;;
;;; DERIVED from test/vendor/rfc3986.txt by cmake/UriCorpus.cmake. Do not edit:
;;; `make corpus-refresh` rewrites this file and a lane re-derives it and
;;; compares, so a hand edit reddens rather than surviving (decision 0005).
;;;
;;; Each row is (<section> <reference> <target>), resolved against the base
;;; section 5.4 declares. Decision 0015 rejects erratum 4547, which would
;;; rewrite two of the 5.4.2 rows; they are here exactly as published.
(base \"http://a/b/c/d;p?q\")
(vectors
${normal_rows}${abnormal_rows})
;;; The one row in section 5.4.2 for which the RFC gives TWO answers. Strict
;;; resolution (section 5.2.2 with strict = true) is what this project
;;; implements and is the row above; the loophole is recorded rather than
;;; silently dropped, because a reader who finds it in the RFC will look for it
;;; here. RFC 1630 partial-URI compatibility is out of scope (decision 0001).
(note (\"5.4.2\" \"http:g\" backward-compatible \"http://a/b/c/g\"))
" PARENT_SCOPE)
endfunction()

# uri_corpus_examples(<rfc-text> <out>)
#
# RFC 3986 section 1.1.2: example URIs across ftp, http, ldap, mailto, news,
# tel, telnet and urn. This is the scheme diversity a corpus drawn from HTTP
# traffic does not have, and the smoke set for path-rootless.
function(uri_corpus_examples rfc out)
  string(FIND "${rfc}" "1.1.2.  Examples" a REVERSE)
  string(FIND "${rfc}" "1.1.3.  URI, URL, and URN" b REVERSE)
  if(a LESS 0 OR b LESS 0)
    message(FATAL_ERROR
      "uri-corpus: RFC 3986 section 1.1.2 was not found in the vendored text.")
  endif()
  math(EXPR len "${b} - ${a}")
  string(SUBSTRING "${rfc}" ${a} ${len} region)
  _uri_corpus_protect(region "${region}")
  string(REGEX MATCHALL "\n      [a-z]+:[^ \n]+" hits "${region}")
  set(rows "")
  foreach(hit IN LISTS hits)
    string(STRIP "${hit}" uri)
    _uri_corpus_restore(uri "${uri}")
    string(APPEND rows "  (\"1.1.2\" \"${uri}\")\n")
  endforeach()
  uri_corpus_require_rows("${rows}" 8 "section 1.1.2")
  set(${out}
";;; RFC 3986 section 1.1.2 -- example URIs across eight schemes.
;;;
;;; DERIVED from test/vendor/rfc3986.txt by cmake/UriCorpus.cmake. Do not edit.
;;;
;;; Each row is (<section> <uri>). These carry no expected decomposition: the
;;; RFC gives them as illustrations, not as vectors, so what a lane may assert
;;; over them is that they parse -- never a component boundary the RFC never
;;; stated (decision 0005 item 3).
(uris
${rows})
" PARENT_SCOPE)
endfunction()

# uri_corpus_dot_segments(<rfc-text> <out>)
#
# RFC 3986 section 5.2.4: remove_dot_segments worked by hand on two inputs,
# step by step. Transcribed AS STEP TRACES and not only as end results
# (decision 0005), because the end result of the first example is reachable by
# several wrong algorithms and the trace is not.
function(uri_corpus_dot_segments rfc out)
  string(FIND "${rfc}" "5.2.4.  Remove Dot Segments" a REVERSE)
  string(FIND "${rfc}" "5.3.  Component Recomposition" b REVERSE)
  if(a LESS 0 OR b LESS 0)
    message(FATAL_ERROR
      "uri-corpus: RFC 3986 section 5.2.4 was not found in the vendored text.")
  endif()
  math(EXPR len "${b} - ${a}")
  string(SUBSTRING "${rfc}" ${a} ${len} region)
  _uri_corpus_protect(region "${region}")
  # THE TABLE HAS FIXED COLUMNS, AND TOKEN ORDER IS NOT ENOUGH. Step 1's row
  # carries ONE field and it is the INPUT buffer (the output buffer starts
  # empty); a trace's LAST row also carries one field and it is the OUTPUT
  # buffer. Splitting on whitespace reads the first as an output and inverts
  # the whole first row, which is what the first run of this extractor did.
  #
  # So the fields are read by column, and the columns are CHECKED against the
  # table's own header rather than trusted: "OUTPUT BUFFER" begins at 13 and
  # "INPUT BUFFER" at 35 on every row of both traces.
  string(REGEX MATCH "\n( +)STEP( +)OUTPUT BUFFER( +)INPUT BUFFER" header "${region}")
  if(NOT header)
    message(FATAL_ERROR
      "uri-corpus: section 5.2.4's step table header was not found, so the "
      "column offsets the rows are read at cannot be confirmed.")
  endif()
  string(FIND "${header}" "OUTPUT BUFFER" out_col)
  string(FIND "${header}" "INPUT BUFFER" in_col)
  math(EXPR out_col "${out_col} - 1")   # the matched span carries a leading newline
  math(EXPR in_col "${in_col} - 1")
  if(NOT out_col EQUAL 13 OR NOT in_col EQUAL 35)
    message(FATAL_ERROR
      "uri-corpus: section 5.2.4's step table columns moved -- output at "
      "${out_col}, input at ${in_col}, expected 13 and 35. The rows below are "
      "read by column, so a moved table would be transcribed wrong rather "
      "than not at all.")
  endif()
  math(EXPR out_width "${in_col} - ${out_col}")

  string(REGEX MATCHALL "\n +[12][A-E ]?:[^\n]*" hits "${region}")
  set(rows "")
  set(trace 0)
  foreach(hit IN LISTS hits)
    string(SUBSTRING "${hit}" 1 -1 line)          # drop the leading newline
    string(REGEX MATCH "^ +([12][A-E ]?):" _m "${line}")
    string(STRIP "${CMAKE_MATCH_1}" step)
    string(LENGTH "${line}" line_len)
    set(output "")
    set(input "")
    if(line_len GREATER out_col)
      math(EXPR take "${line_len} - ${out_col}")
      if(take GREATER out_width)
        set(take ${out_width})
      endif()
      string(SUBSTRING "${line}" ${out_col} ${take} output)
      string(STRIP "${output}" output)
    endif()
    if(line_len GREATER in_col)
      math(EXPR take "${line_len} - ${in_col}")
      string(SUBSTRING "${line}" ${in_col} ${take} input)
      string(STRIP "${input}" input)
    endif()
    _uri_corpus_restore(output "${output}")
    _uri_corpus_restore(input "${input}")
    if(step STREQUAL "1")
      math(EXPR trace "${trace} + 1")
    endif()
    string(APPEND rows "  (${trace} \"${step}\" \"${output}\" \"${input}\")\n")
  endforeach()
  uri_corpus_require_rows("${rows}" 13 "section 5.2.4")
  set(${out}
";;; RFC 3986 section 5.2.4 -- remove_dot_segments, worked step by step.
;;;
;;; DERIVED from test/vendor/rfc3986.txt by cmake/UriCorpus.cmake. Do not edit.
;;;
;;; Each row is (<trace> <step> <output-buffer> <input-buffer>): the state of
;;; the two buffers AFTER the named step of the algorithm. Trace 1 is
;;; /a/b/c/./../../g and trace 2 is mid/content=5/../6. The last row of a trace
;;; carries an empty input buffer and its output buffer is the result.
(steps
${rows})
" PARENT_SCOPE)
endfunction()
