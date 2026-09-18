# Regenerate src/generated/uri-scanner.sls from the grammar.
#
# The determinism lane (uri.determinism.generated-artifact.chez.source) runs the
# SAME emitter and compares the bytes, so this convenience and the check that
# guards it cannot drift -- the whole point of decision 0002 item 4. Run via
# `make parser-refresh` or `cmake -P cmake/UriParserRefresh.cmake`.
cmake_minimum_required(VERSION 3.26)

# Discovery mirrors the build (README: scheme, chez, chezscheme in order), or an
# explicit -DURI_CHEZ_EXECUTABLE overrides it. `cmake -P` runs with no cache, so
# the executable is re-discovered here rather than read from a configured tree.
if(NOT URI_CHEZ_EXECUTABLE)
  find_program(URI_CHEZ_EXECUTABLE NAMES scheme chez chezscheme)
endif()
if(NOT URI_CHEZ_EXECUTABLE)
  message(FATAL_ERROR
    "uri: no Chez Scheme found for the emitter. Point at one with "
    "cmake -DURI_CHEZ_EXECUTABLE=/absolute/path/to/scheme -P cmake/UriParserRefresh.cmake")
endif()

get_filename_component(root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
# Chez separates --libdirs entries with the platform path separator.
if(WIN32)
  set(sep ";")
else()
  set(sep ":")
endif()

execute_process(
  COMMAND "${URI_CHEZ_EXECUTABLE}"
          --libdirs "${root}/src${sep}${root}/vendor/byte-machine/src"
          --script "${root}/tools/emit-machine.ss"
          --output "${root}/src/generated/uri-scanner.sls"
  RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "uri: the URI scanner emitter failed with status ${rc}.")
endif()
