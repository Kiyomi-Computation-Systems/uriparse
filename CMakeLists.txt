# chez-uri: an RFC 3986 URI parser for Chez Scheme.
#
# CMake is the canonical build frontend on every platform, with a thin Makefile
# over it for the usual Unix entry points.
#
# The 3.26 floor is set by the preset schema this project uses -- version 6,
# which requires 3.25 -- plus a margin. It is not what enables JUnit output or
# refusing an empty test selection; both of those arrive earlier, in 3.21. Only
# 4.3.3 has actually been exercised, so 3.26 is a declared floor rather than a
# tested one.
#
# LANGUAGES NONE is deliberate: chez-uri has no C of its own, so asking
# CMake for a C compiler would impose a requirement the project does not have.
cmake_minimum_required(VERSION 3.26)

project(chez-uri
  VERSION 0.4.0
  DESCRIPTION "RFC 3986 URI parser for Chez Scheme"
  HOMEPAGE_URL "https://github.com/Kiyomi-Computation-Systems/uriparse"
  LANGUAGES NONE)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake")

option(URI_BUILD_TESTS "Build the test suite" ${PROJECT_IS_TOP_LEVEL})

# Discovery is opt-out so the CMake-layer specifications can be configured and
# run on a host with no Scheme installed. Every lane that needs a runtime is
# registered only when its runtime was found.
option(URI_REQUIRE_CHEZ "Require a usable Chez Scheme at configure time" ON)

include(UriChez)

if(URI_REQUIRE_CHEZ)
  uri_chez_discover()
endif()

# The byte-machine submodule and the emitter landed at M2 (decision 0002 item 2).
# `make parser-refresh` (cmake/UriParserRefresh.cmake) re-emits the committed
# scanner from src/uri/grammar.sls; the determinism lane runs the same emitter
# and compares, so a grammar edit without a refresh reddens.

if(URI_BUILD_TESTS)
  enable_testing()
  # CTest will not create the directory for --output-junit itself.
  file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/test-results")
  include(UriTesting)
  include(UriExpectExit)
  include(UriSchemeLane)
  add_subdirectory(test)
endif()

message(STATUS
  "chez-uri ${PROJECT_VERSION}: tests=${URI_BUILD_TESTS} "
  "chez=${URI_REQUIRE_CHEZ}")
