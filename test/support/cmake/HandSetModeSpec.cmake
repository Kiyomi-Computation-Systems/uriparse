# Specification: every registration in test/CMakeLists.txt that sets
# URI_EXECUTION_MODE by hand sets the mode its name declares.
#
# uri_add_scheme_lane derives URI_EXECUTION_MODE from the lane name, so a lane
# it registers cannot claim one mode and run another. A registration that
# bypasses it and writes ENVIRONMENT "URI_EXECUTION_MODE=..." itself gets no
# such guarantee: the name says `.chez.source`, the environment could say
# anything, and every lane would stay green. This holds those registrations to
# the same rule, as text.
#
# THE RULE. A registration whose name has the `chez` backend must hand-set the
# mode its name ends in. A registration with any other backend has no Scheme
# mode in its name to agree with -- `uri.harness.scheme-mutation.cmake.direct`
# sets "source" for the lanes it stages, not for itself -- so it is allowed only
# when it is listed in _hsm_exemptions below with the mode it sets. An exemption
# that matches no registration is itself a finding, so the list cannot outlive
# what it excuses. A mode set outside any registration call is a finding too:
# it belongs to no name, so nothing could vouch for it.
#
# The extraction is the part that fails silently, by matching less than it
# should. So the driver refuses a tree in which it finds no hand-set mode at
# all, and one witness case runs the audit over the real test/CMakeLists.txt
# with a single mode swapped, so the real text is shown to be read, not only
# synthetic text.
#
# It needs no Scheme runtime, so it holds under the no-scheme preset too.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

set(SPEC_SELF "${CMAKE_CURRENT_LIST_FILE}")

get_filename_component(_hsm_root "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(_hsm_tests "${_hsm_root}/test/CMakeLists.txt")

# <name>=<mode> for each non-Scheme registration allowed to hand-set a mode.
set(_hsm_exemptions
  # Sets "source" for the Scheme lanes it stages and runs; its own name's mode
  # field is "direct", a CMake-backend value with nothing to agree with.
  "uri.harness.scheme-mutation.cmake.direct=source")

# --- The audit, as a function of text --------------------------------------
#
# hand_set_mode_audit(<text> <exemptions> <out-findings> <out-checked> <out-exempted>)
#
# Findings are computed from text alone, which is what lets the witness cases
# below drive this same code with synthetic registrations. <out-checked> is the
# number of Scheme registrations whose hand-set mode agreed with the name;
# <out-exempted> the number allowed by an exemption.
function(hand_set_mode_audit text exemptions out_findings out_checked out_exempted)
  # One element per line. Semicolons would split a line in two, and nothing
  # this reads depends on them.
  string(REPLACE ";" "," text "${text}")
  string(REPLACE "\n" ";" lines "${text}")

  set(findings "")
  set(checked 0)
  set(exempted 0)
  set(used_exemptions "")
  set(in_call FALSE)
  set(depth 0)
  set(lineno 0)

  foreach(line IN LISTS lines)
    math(EXPR lineno "${lineno} + 1")
    string(STRIP "${line}" stripped)
    if(stripped MATCHES "^#")
      continue()
    endif()

    if(NOT in_call AND stripped MATCHES "^uri_add_[a-z_]*test[ \t]*\\(")
      set(in_call TRUE)
      set(depth 0)
      set(name "")
      set(modes "")
      set(start ${lineno})
    endif()

    string(REGEX MATCHALL "URI_EXECUTION_MODE=[A-Za-z0-9_-]*" sets "${line}")
    if(NOT in_call)
      foreach(s IN LISTS sets)
        list(APPEND findings
             "line ${lineno} sets ${s} outside any registration call, so no name vouches for it")
      endforeach()
      continue()
    endif()

    foreach(s IN LISTS sets)
      string(REPLACE "URI_EXECUTION_MODE=" "" m "${s}")
      list(APPEND modes "${m}")
    endforeach()
    if(name STREQUAL "" AND stripped MATCHES "(^|[ \t(])NAME[ \t]+\"?([^ \t\")]+)")
      set(name "${CMAKE_MATCH_2}")
    endif()

    # Parentheses inside quoted strings and trailing comments do not nest.
    string(REGEX REPLACE "\"[^\"]*\"" "" code "${line}")
    string(REGEX REPLACE "#.*$" "" code "${code}")
    string(REGEX MATCHALL "\\(" opens "${code}")
    string(REGEX MATCHALL "\\)" closes "${code}")
    list(LENGTH opens n_open)
    list(LENGTH closes n_close)
    math(EXPR depth "${depth} + ${n_open} - ${n_close}")
    if(depth GREATER 0)
      continue()
    endif()

    # The call ended on this line: judge it.
    set(in_call FALSE)
    if(NOT modes)
      continue()
    endif()
    if(name STREQUAL "")
      list(APPEND findings
           "the registration starting at line ${start} sets URI_EXECUTION_MODE but has no NAME")
      continue()
    endif()
    if(NOT name MATCHES "^uri\\.[a-z0-9-]+\\.[a-z0-9-]+\\.([a-z0-9-]+)\\.([a-z0-9-]+)$")
      list(APPEND findings "${name}: not a five-segment uri.<layer>.<feature>.<backend>.<mode> name")
      continue()
    endif()
    set(backend "${CMAKE_MATCH_1}")
    set(lane_mode "${CMAKE_MATCH_2}")
    foreach(m IN LISTS modes)
      if(backend STREQUAL "chez")
        if(m STREQUAL lane_mode)
          math(EXPR checked "${checked} + 1")
        else()
          list(APPEND findings
               "${name}: its name declares mode '${lane_mode}', but it hand-sets URI_EXECUTION_MODE=${m}")
        endif()
      elseif("${name}=${m}" IN_LIST exemptions)
        math(EXPR exempted "${exempted} + 1")
        list(APPEND used_exemptions "${name}=${m}")
      else()
        list(APPEND findings
             "${name}: backend '${backend}' has no Scheme mode to agree with URI_EXECUTION_MODE=${m}. Register it through uri_add_scheme_lane or add an exemption with its reason")
      endif()
    endforeach()
  endforeach()

  if(in_call)
    list(APPEND findings "the registration starting at line ${start} never closes")
  endif()
  foreach(e IN LISTS exemptions)
    if(NOT e IN_LIST used_exemptions)
      list(APPEND findings "the exemption '${e}' matches no registration, so remove it")
    endif()
  endforeach()

  set(${out_findings} "${findings}" PARENT_SCOPE)
  set(${out_checked} "${checked}" PARENT_SCOPE)
  set(${out_exempted} "${exempted}" PARENT_SCOPE)
endfunction()

# --- Witness cases ---------------------------------------------------------
#
# Driven as child processes by the driver below. Each must be rejected; without
# these, an audit that accepted everything would leave this lane green.
set(_hsm_open "uri_add_exit_code_test(\n  NAME ")
if(DEFINED URI_SPEC_CASE)
  set(c "${URI_SPEC_CASE}")
  set(exemptions "")

  if(c STREQUAL "rejects-a-source-lane-that-sets-aot")
    set(text "${_hsm_open}uri.harness.x.chez.source\n  COMMAND a\n  ENVIRONMENT \"URI_EXECUTION_MODE=aot\")\n")
  elseif(c STREQUAL "rejects-an-unexempted-non-scheme-lane")
    set(text "${_hsm_open}uri.harness.x.cmake.direct\n  ENVIRONMENT \"URI_EXECUTION_MODE=source\")\n")
  elseif(c STREQUAL "rejects-a-mode-set-outside-a-registration")
    set(text "set_tests_properties(t PROPERTIES\n  ENVIRONMENT \"URI_EXECUTION_MODE=source\")\n")
  elseif(c STREQUAL "rejects-a-stale-exemption")
    set(text "${_hsm_open}uri.harness.x.chez.source\n  ENVIRONMENT \"URI_EXECUTION_MODE=source\")\n")
    set(exemptions "uri.harness.gone.cmake.direct=source")
  elseif(c STREQUAL "rejects-the-real-tree-with-one-mode-swapped")
    file(READ "${_hsm_tests}" text)
    set(needle "\"URI_EXECUTION_MODE=source\")")
    string(FIND "${text}" "${needle}" at)
    if(at EQUAL -1)
      message(FATAL_ERROR "uri-spec: case '${c}' found no hand-set source mode to swap")
    endif()
    string(SUBSTRING "${text}" 0 ${at} head)
    string(LENGTH "${needle}" n)
    math(EXPR after "${at} + ${n}")
    string(SUBSTRING "${text}" ${after} -1 tail)
    set(text "${head}\"URI_EXECUTION_MODE=aot\")${tail}")
    set(exemptions ${_hsm_exemptions})
  else()
    message(FATAL_ERROR "uri-spec: unknown case '${c}'")
  endif()

  hand_set_mode_audit("${text}" "${exemptions}" findings checked exempted)
  if(findings)
    list(JOIN findings "\n  " joined)
    message(FATAL_ERROR "uri-spec: hand-set mode audit rejected this case:\n  ${joined}")
  endif()
  message(FATAL_ERROR "uri-spec: case '${c}' was accepted but must be rejected")
endif()

# --- Driver ----------------------------------------------------------------

# The shapes that must be accepted: a matching Scheme lane, an exempted
# non-Scheme lane, a call whose quoted arguments hold parentheses, and a
# registration that sets no mode at all.
hand_set_mode_audit(
  "${_hsm_open}uri.harness.x.chez.source\n  ENVIRONMENT \"URI_EXECUTION_MODE=source\")\n"
  "" _ok1 _ok1_checked _ok1_exempted)
hand_set_mode_audit(
  "${_hsm_open}uri.harness.y.cmake.direct\n  COMMAND \"a(b\" -P \"c)\"\n  ENVIRONMENT \"URI_EXECUTION_MODE=source\"\n            \"OTHER=1\")\n"
  "uri.harness.y.cmake.direct=source" _ok2 _ok2_checked _ok2_exempted)
hand_set_mode_audit("${_hsm_open}uri.harness.z.chez.aot\n  COMMAND a)\n" "" _ok3 _ok3_checked _ok3_exempted)
spec_check_equal("${_ok1}" "" "a Scheme lane that sets its own mode is accepted")
spec_check_equal("${_ok1_checked}" "1" "a Scheme lane that sets its own mode is counted")
spec_check_equal("${_ok2}" "" "an exempted non-Scheme lane is accepted across quoted parentheses")
spec_check_equal("${_ok2_exempted}" "1" "an exempted non-Scheme lane is counted")
spec_check_equal("${_ok3}" "" "a registration that sets no mode is accepted")

file(READ "${_hsm_tests}" _hsm_text)
hand_set_mode_audit("${_hsm_text}" "${_hsm_exemptions}" _hsm_findings _hsm_checked _hsm_exempted)
foreach(_f IN LISTS _hsm_findings)
  spec_record_failure()
  message(SEND_ERROR "uri-spec: test/CMakeLists.txt: ${_f}")
endforeach()
if(_hsm_checked EQUAL 0)
  spec_record_failure()
  message(SEND_ERROR
    "uri-spec: no Scheme registration in test/CMakeLists.txt hand-sets "
    "URI_EXECUTION_MODE, so the recogniser no longer describes the tree. Fix "
    "the extraction before trusting this lane.")
endif()

spec_expect_all_rejected("${SPEC_SELF}"
  "rejects-a-source-lane-that-sets-aot|uri.harness.x.chez.source: its name declares mode 'source', but it hand-sets URI_EXECUTION_MODE=aot"
  "rejects-an-unexempted-non-scheme-lane|uri.harness.x.cmake.direct: backend 'cmake' has no Scheme mode to agree with"
  "rejects-a-mode-set-outside-a-registration|line 2 sets URI_EXECUTION_MODE=source outside any registration call"
  "rejects-a-stale-exemption|the exemption 'uri.harness.gone.cmake.direct=source' matches no registration"
  "rejects-the-real-tree-with-one-mode-swapped|chez.source: its name declares mode 'source', but it hand-sets URI_EXECUTION_MODE=aot")

spec_finish("hand-set execution modes (${_hsm_checked} Scheme registrations agree with their names, ${_hsm_exempted} exempted)")
