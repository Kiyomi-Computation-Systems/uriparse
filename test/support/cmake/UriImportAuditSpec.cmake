# Specification: src/ is pure R6RS, asserted rather than trusted.
#
# The shipped surface is portable by default -- every library under src/ imports
# only (rnrs), (byte-machine ...) and this project's own libraries -- but that is
# a property that decays silently: one `(import (chezscheme) ...)` slipped into a
# core library would still run on the single Chez cell and quietly end the
# portability the README is careful not to claim. So it is a registered check
# (AGENTS.md: prefer a check to a comment). Two properties, both cheap and both
# text-level, so this needs no Scheme runtime and holds under the no-scheme
# preset:
#
#   1. Every .sls under src/ LEADS WITH `#!r6rs` (Racket needs the
#      line, Chez and Guile accept it). The generated artifact is the file that
#      most needs to read on another implementation, and it is included here.
#   2. No .sls under src/ names `(chezscheme)`. Chez belongs in the harness, the
#      emitter, a bench runner and the probe -- never in the shipped libraries.
#
# It does not whitelist the full import set; those two are the load-bearing
# properties, and a broader import audit can extend this spec when one is needed.

cmake_minimum_required(VERSION 3.26)

include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/SpecSupport.cmake")

get_filename_component(_ia_root "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(_ia_src "${_ia_root}/src")

set(_ia_scanned 0)
if(IS_DIRECTORY "${_ia_src}")
  file(GLOB_RECURSE _ia_files "${_ia_src}/*.sls")
  foreach(_ia_file IN LISTS _ia_files)
    math(EXPR _ia_scanned "${_ia_scanned} + 1")
    file(READ "${_ia_file}" _ia_content)
    file(RELATIVE_PATH _ia_rel "${_ia_root}" "${_ia_file}")

    string(FIND "${_ia_content}" "#!r6rs" _ia_at)
    if(NOT _ia_at EQUAL 0)
      spec_record_failure()
      message(SEND_ERROR
        "uri-spec: '${_ia_rel}' does not lead with '#!r6rs'. Every .sls under "
        "src/ must, so it reads on Racket and Guile as well as Chez. "
        "A generated artifact gets its line from the emitter (tools/emit-machine.ss).")
    endif()

    string(TOLOWER "${_ia_content}" _ia_lower)
    if(_ia_lower MATCHES "\\(chezscheme")
      spec_record_failure()
      message(SEND_ERROR
        "uri-spec: '${_ia_rel}' names (chezscheme). src/ is pure R6RS: "
        "it imports only (rnrs), (byte-machine ...) and this "
        "project's own libraries. Chez belongs in the harness, the emitter, a "
        "bench runner or the probe -- move the code there.")
    endif()
  endforeach()
endif()

# An audit that scanned nothing proves nothing (the empty-selection rule, one
# layer up). src/ holds product libraries.
if(_ia_scanned EQUAL 0)
  spec_record_failure()
  message(SEND_ERROR
    "uri-spec: the src import audit scanned zero files, so it verified nothing. "
    "src/ no longer holds the libraries this audit is meant to guard.")
endif()

spec_finish("src import audit (${_ia_scanned} files pure R6RS)")
