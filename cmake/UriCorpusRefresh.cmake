# Re-derive the conformance corpus from the vendored RFC 3986 text.
#
#   cmake -P cmake/UriCorpusRefresh.cmake
#
# This is the ONLY way test/conformance/rfc3986/*.scm is written: the initial
# derivation and every refresh run the same code, so a refresh cannot drift
# from however the first copy happened to be made. The registered lane
# CorpusProvenanceSpec.cmake calls the same functions and compares.
cmake_minimum_required(VERSION 3.26)

get_filename_component(_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
include("${CMAKE_CURRENT_LIST_DIR}/UriCorpus.cmake")

set(_rfc_file "${_root}/test/vendor/rfc3986.txt")
if(NOT EXISTS "${_rfc_file}")
  message(FATAL_ERROR "uri-corpus: ${_rfc_file} is missing.")
endif()
file(READ "${_rfc_file}" _rfc)

uri_corpus_resolution("${_rfc}" _resolution)
uri_corpus_dot_segments("${_rfc}" _dots)
uri_corpus_examples("${_rfc}" _examples)
uri_corpus_abnf("${_rfc}" _abnf)

set(_out "${_root}/test/conformance/rfc3986")
file(MAKE_DIRECTORY "${_out}")
file(WRITE "${_out}/resolution.scm" "${_resolution}")
file(WRITE "${_out}/dot-segments.scm" "${_dots}")
file(WRITE "${_out}/example-uris.scm" "${_examples}")
file(WRITE "${_out}/rfc3986.abnf" "${_abnf}")

file(SHA256 "${_rfc_file}" _digest)
message(STATUS "uri-corpus: derived from rfc3986.txt (sha256 ${_digest})")
