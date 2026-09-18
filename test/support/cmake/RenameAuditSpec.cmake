# Specification: no upstream project token survives in the build/test tree.
#
# This harness was ported from a sibling repository under a mechanical rename
# (decision 0001 item 1: machine tokens use the bare stem `uri`). A rule like
# that decays the moment it lives only in a review checklist -- the next file
# copied from the sibling reintroduces the name and nothing fails -- so it is a
# registered check instead (AGENTS.md: prefer a check to a comment). The whole
# harness arrived in one bulk copy, which is exactly the event this audit
# exists to make safe to repeat.
#
# WHAT IS SCANNED. The build/test tree: the top-level build files, cmake/,
# test/, and .github/. The documentation and attribution surfaces (.plans/,
# README.org, CHANGELOG.md, AGENTS.md, LICENSE, docs/) are exempt -- the
# decision records discuss the sibling by name constantly and must be able to.
# A scan root that does not exist is skipped, not an error: under the mutation
# engine's staged tree only cmake/ and test/support/cmake/ are present, and the
# audit must still judge those.
#
# THERE IS NO ALLOWLIST, which is the one way this audit is SIMPLER than the
# sibling's. chez-uri does not depend on the sibling in any form: no
# submodule path, no R6RS library reference, no vendored artifact. Every
# occurrence is therefore a leak, with no legitimate shape to carve out. The
# dependency this project DOES have -- byte-machine (decision 0002) -- is named
# freely and is not what this audit hunts.
#
# WHY THE STEM IS ASSEMBLED AT RUN TIME. This file must never contain the
# forbidden text it hunts, or it would convict itself; string(CONCAT) builds it
# from halves. Matching is done on a LOWERCASED copy of each file, so every
# case mixture -- the function prefix, the cache variable, the module
# CamelCase, the hyphenated prose form -- reduces to the one stem below.

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

get_filename_component(_audit_root "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

# The single lowercase stem every observed shape of the sibling's name reduces
# to once the content is lowercased: `uri_*`'s predecessor, the `URI_*` cache
# variable's predecessor, the `Uri*` module filename's predecessor, and the
# hyphenated `chez-` prose form all contain it.
string(CONCAT _audit_stem "htt" "parse")

set(_audit_files
  "${_audit_root}/Makefile"
  "${_audit_root}/CMakeLists.txt"
  "${_audit_root}/CMakePresets.json"
  "${_audit_root}/.gitignore"
  "${_audit_root}/.gitattributes")

foreach(_audit_dir cmake test .github)
  if(IS_DIRECTORY "${_audit_root}/${_audit_dir}")
    file(GLOB_RECURSE _audit_found "${_audit_root}/${_audit_dir}/*")
    list(APPEND _audit_files ${_audit_found})
  endif()
endforeach()

set(_audit_scanned 0)
foreach(_audit_file IN LISTS _audit_files)
  if(NOT EXISTS "${_audit_file}" OR IS_DIRECTORY "${_audit_file}")
    continue()
  endif()
  math(EXPR _audit_scanned "${_audit_scanned} + 1")
  file(READ "${_audit_file}" _audit_content)
  string(TOLOWER "${_audit_content}" _audit_lower)
  if(_audit_lower MATCHES "${_audit_stem}")
    spec_record_failure()
    file(RELATIVE_PATH _audit_rel "${_audit_root}" "${_audit_file}")
    message(SEND_ERROR
      "uri-spec: upstream project token leaked into '${_audit_rel}'. "
      "The build/test tree must carry no reference to the sibling repository "
      "this harness was ported from; rename it per the decision 0001 item 1 "
      "map (uri_* / URI_* / Uri* / bare uri), or, if this file is genuinely "
      "attribution or discussion, move the mention to an exempt surface "
      "(.plans/, README.org, CHANGELOG.md, AGENTS.md, docs/). There is no "
      "legitimate form of this token here, and adding one means amending "
      "decision 0001 rather than widening this audit quietly.")
  endif()
endforeach()

# An audit that scanned nothing proves nothing -- the same reason an empty test
# selection and an empty mutation suite are failures elsewhere in this tree.
# Even the staged mutation tree carries this spec's own directory, so zero
# files means the roots were mislocated, not that the tree is clean.
if(_audit_scanned EQUAL 0)
  spec_record_failure()
  message(SEND_ERROR
    "uri-spec: the rename audit scanned zero files, so it verified "
    "nothing. The scan roots no longer describe the tree.")
endif()

spec_finish("rename audit (${_audit_scanned} files clean)")
