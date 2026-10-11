# Specification for the functional core of cmake/UriTesting.cmake.
#
# The registration helper decides which tests exist at all, so a defect here is
# invisible in the worst way: a malformed or duplicated registration produces a
# suite that runs fewer tests than it appears to and still reports success. Each
# rule is therefore enforced at configure time and specified before anything
# relies on it.

cmake_minimum_required(VERSION 3.26)

include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/UriTesting.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

set(SPEC_SELF "${CMAKE_CURRENT_LIST_FILE}")

if(DEFINED URI_SPEC_CASE)
  set(c "${URI_SPEC_CASE}")

  # add_test and set_tests_properties belong to a project context this script
  # does not have. Stubbing both lets the registrar's own validation be
  # exercised: without it a case would die on that unrelated error instead of
  # falling through to the "must be rejected" check.
  function(add_test)
  endfunction()
  function(set_tests_properties)
  endfunction()

  if(c STREQUAL "too-few-segments")
    uri_test_name_parse("uri.unit.graph.chez" l f b m)
  elseif(c STREQUAL "uppercase")
    uri_test_name_parse("uri.unit.Graph.chez.source" l f b m)
  elseif(c STREQUAL "wrong-prefix")
    uri_test_name_parse("httpparse.unit.graph.chez.source" l f b m)
  elseif(c STREQUAL "unknown-layer")
    uri_test_name_parse("uri.smoke.graph.chez.source" l f b m)
  elseif(c STREQUAL "unknown-backend")
    uri_test_name_parse("uri.unit.graph.guile.source" l f b m)
  elseif(c STREQUAL "incompatible-mode")
    # Chez has no .o1 lane; the mode exists but not for this backend.
    uri_test_name_parse("uri.unit.graph.chez.o1" l f b m)
  elseif(c STREQUAL "feature-leading-hyphen")
    uri_test_name_parse("uri.unit.-graph.chez.source" l f b m)
  elseif(c STREQUAL "feature-trailing-hyphen")
    uri_test_name_parse("uri.unit.graph-.chez.source" l f b m)
  elseif(c STREQUAL "unknown-label")
    uri_test_validate_labels(unit bogus)
  elseif(c STREQUAL "duplicate-name")
    uri_test_reserve_name("uri.unit.graph.chez.source")
    uri_test_reserve_name("uri.unit.graph.chez.source")
  elseif(c STREQUAL "missing-timeout")
    uri_test_require_timeout("" "uri.unit.graph.chez.source")
  elseif(c STREQUAL "zero-timeout")
    uri_test_require_timeout("0" "uri.unit.graph.chez.source")
  elseif(c STREQUAL "noninteger-timeout")
    uri_test_require_timeout("30s" "uri.unit.graph.chez.source")
  elseif(c STREQUAL "registration-rejects-absent-working-directory")
    uri_add_test(
      NAME uri.harness.example.cmake.direct
      COMMAND "/bin/true"
      TIMEOUT 10
      WORKING_DIRECTORY "/there/is/no/such/directory")
  else()
    message(FATAL_ERROR "uri-spec: unknown case '${c}'")
  endif()

  message(FATAL_ERROR "uri-spec: case '${c}' was accepted but must be rejected")
endif()

# --- Positive --------------------------------------------------------------

uri_test_name_parse("uri.unit.graph.chez.source" l f b m)
spec_check_equal("${l}" "unit" "layer")
spec_check_equal("${f}" "graph" "feature")
spec_check_equal("${b}" "chez" "backend")
spec_check_equal("${m}" "source" "mode")

# Every backend/mode pair the project actually has a lane for must parse. These
# are the three lanes of the execution model, and a helper that rejected one
# would silently delete that lane's coverage.
foreach(pair "chez.source" "chez.aot" "cmake.direct")
  uri_test_name_parse("uri.unit.graph.${pair}" l f b m)
endforeach()

# A multi-word feature with interior hyphens is fine; only the edges are barred.
uri_test_name_parse("uri.differential.span-boundary.chez.aot" l f b m)
spec_check_equal("${f}" "span-boundary" "hyphenated feature")

uri_test_validate_labels(unit chez source)
uri_test_reserve_name("uri.unit.unique-one.chez.source")
uri_test_reserve_name("uri.unit.unique-two.chez.source")
uri_test_require_timeout("120" "uri.unit.graph.chez.source")

# --- The run directory ------------------------------------------------------
#
# The directory a lane launches from can be changed per lane. Specified against
# the pure function rather than through uri_add_test: the registrar calls
# add_test, which script mode does not have, and creates directories, which a
# specification must not do to whatever tree it happens to be run from.
uri_test_run_directory("uri.harness.example.cmake.direct" "" derived)
spec_check_equal("${derived}" "${CMAKE_BINARY_DIR}/test-run/uri.harness.example.cmake.direct"
  "with no override, the run directory is derived from the test name")

uri_test_run_directory("uri.harness.example.cmake.direct" "/some/where" chosen)
spec_check_equal("${chosen}" "/some/where" "an override is used verbatim")

# The empty string is the shape a caller that omitted WORKING_DIRECTORY produces,
# and it must mean "derive", not "launch from the filesystem root".
uri_test_run_directory("uri.harness.other.cmake.direct" "" empty_override)
spec_check_equal("${empty_override}" "${CMAKE_BINARY_DIR}/test-run/uri.harness.other.cmake.direct"
  "an empty override still derives, and derives from this name")

# --- Negative --------------------------------------------------------------

set(negative_cases
  "too-few-segments|uri: malformed test name"
  "uppercase|uri: malformed test name"
  "wrong-prefix|uri: malformed test name"
  "unknown-layer|uri: unknown test layer 'smoke'"
  "unknown-backend|uri: unknown test backend 'guile'"
  "incompatible-mode|uri: incompatible backend/mode"
  "feature-leading-hyphen|Feature segment '-graph' must not begin or end with a hyphen"
  "feature-trailing-hyphen|Feature segment 'graph-' must not begin or end with a hyphen"
  "unknown-label|uri: unknown test label 'bogus'"
  "duplicate-name|uri: duplicate test name"
  "missing-timeout|uri: TIMEOUT is required"
  "zero-timeout|uri: TIMEOUT for .* must be a positive whole number"
  "noninteger-timeout|uri: TIMEOUT for .* must be a positive whole number"
  "registration-rejects-absent-working-directory|is not an existing directory")

spec_expect_all_rejected("${SPEC_SELF}" ${negative_cases})

spec_finish("UriTesting")
