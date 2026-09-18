# Specification: the conformance corpus is what RFC 3986 says, not what
# someone typed.
#
# Decision 0005 makes the RFC's vectors the anchor of the resolution layer and
# says a vector is never edited to make a test pass. That is the single most
# load-bearing claim in the test tree and it is exactly the kind of claim that
# decays silently: one edited expectation turns a red lane green and nothing
# anywhere says so.
#
# So the corpus is DERIVED, and this re-derives it. The same functions
# `make corpus-refresh` runs (cmake/UriCorpus.cmake) are run here against the
# vendored RFC text, and the result is compared byte for byte with what is
# committed. A hand edit to a vector reddens; so does an edit to the RFC text,
# which is why its digest is pinned in the corpus PROVENANCE file rather than
# only in a commit message.
#
# THE TWO DIAGNOSTICS CARRY MARKER TOKENS -- CORPUS-DERIVATION-MISMATCH and
# CORPUS-SOURCE-MISMATCH -- because the mutation suite matches this spec's raw
# output and CMake wraps a long message at an unpredictable column. A phrase
# can be split across two lines and stop matching; a single token cannot. This
# is the same reason the Scheme harness prints PROVENANCE-ERROR.
#
# It needs no Scheme runtime, so it holds under the no-scheme preset too.

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/UriCorpus.cmake")

get_filename_component(_cp_root "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(_cp_rfc "${_cp_root}/test/vendor/rfc3986.txt")
set(_cp_dir "${_cp_root}/test/conformance/rfc3986")

if(NOT EXISTS "${_cp_rfc}")
  spec_record_failure()
  message(SEND_ERROR
    "uri-spec: the vendored RFC text ${_cp_rfc} is missing, so the corpus "
    "cannot be re-derived and its provenance cannot be checked at all.")
  spec_finish("corpus provenance")
  return()
endif()

file(READ "${_cp_rfc}" _cp_text)

uri_corpus_resolution("${_cp_text}" _cp_resolution)
uri_corpus_dot_segments("${_cp_text}" _cp_dots)
uri_corpus_examples("${_cp_text}" _cp_examples)
uri_corpus_abnf("${_cp_text}" _cp_abnf)

# The digest recorded in PROVENANCE is the claim "this corpus came from THAT
# text". Checked here, so replacing the vendored RFC without re-recording is a
# failure rather than a quiet substitution.
file(SHA256 "${_cp_rfc}" _cp_digest)
set(_cp_provenance "${_cp_dir}/PROVENANCE")
if(NOT EXISTS "${_cp_provenance}")
  spec_record_failure()
  message(SEND_ERROR "uri-spec: ${_cp_provenance} is missing.")
else()
  file(READ "${_cp_provenance}" _cp_provenance_text)
  string(FIND "${_cp_provenance_text}" "${_cp_digest}" _cp_found)
  if(_cp_found LESS 0)
    spec_record_failure()
    message(SEND_ERROR
      "uri-spec: CORPUS-SOURCE-MISMATCH -- PROVENANCE does not record the "
      "digest of the RFC text it "
      "sits beside. The vendored text is sha256 ${_cp_digest}; a corpus whose "
      "provenance names a different source is a corpus of unknown origin.")
  endif()
endif()

function(_cp_compare name derived)
  set(path "${_cp_dir}/${name}")
  if(NOT EXISTS "${path}")
    spec_record_failure()
    message(SEND_ERROR "uri-spec: ${path} is missing; run `make corpus-refresh`.")
    return()
  endif()
  file(READ "${path}" committed)
  if(NOT committed STREQUAL derived)
    spec_record_failure()
    message(SEND_ERROR
      "uri-spec: CORPUS-DERIVATION-MISMATCH -- "
      "test/conformance/rfc3986/${name} is not what RFC 3986 says. "
      "Re-deriving it from the vendored text produced different bytes, which "
      "means the committed file was edited by hand, the extractor changed "
      "without a refresh, or the vendored RFC moved. A vector is never edited "
      "to make a test pass (decision 0005 item 2); run `make corpus-refresh` "
      "and review the diff.")
  endif()
endfunction()

_cp_compare("resolution.scm" "${_cp_resolution}")
_cp_compare("dot-segments.scm" "${_cp_dots}")
_cp_compare("example-uris.scm" "${_cp_examples}")
_cp_compare("rfc3986.abnf" "${_cp_abnf}")

spec_finish("corpus provenance (4 files re-derived, digest pinned)")
