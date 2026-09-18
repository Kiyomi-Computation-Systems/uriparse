# chez-uri test tree.
#
# Slice 1 registers the harness and build-layer surface only: the CMake-layer
# specifications (the build's own discovery and registration logic, which
# decides what every later lane can even see), the Scheme harness self lanes,
# the launcher refusals, provenance, and the two mutation suites. Parser lanes
# arrive with the first grammar slice.

# The registration helper decides which tests exist at all, so its functional
# core is specified before anything relies on it.
uri_add_test(
  NAME uri.harness.cmake-testing.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/UriTestingSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# Runtime discovery reads key=value probe output. Reading it wrong yields a
# plausible answer rather than an error, so the accessor is specified before
# either runtime module relies on it.
uri_add_test(
  NAME uri.harness.cmake-probe.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/UriProbeSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# Chez discovery must reject Petite, which cannot run the ahead-of-time lane,
# and must not mistake an unrelated `scheme` on PATH for Chez.
uri_add_test(
  NAME uri.harness.cmake-chez.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/UriChezSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# Every assertion in every specification above routes through SpecSupport, so a
# silent break there would leave all of them green while checking nothing. This
# is the only specification that may not use the helpers it tests.
uri_add_test(
  NAME uri.harness.cmake-spec-support.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/SpecSupportSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# The harness in this tree arrived as a bulk copy from a sibling repository
# under decision 0001 item 1's rename map. A rule that lives only in a review
# checklist decays the moment the next file is copied, so it is a registered
# check: nothing in the build/test tree may mention the sibling by name. It
# needs no Scheme runtime, so it also holds under the no-scheme preset.
uri_add_test(
  NAME uri.harness.rename-audit.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/RenameAuditSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# src/ is pure R6RS (decision 0007): every .sls leads with #!r6rs and none names
# (chezscheme). Asserted, not trusted -- and, like the rename audit, it needs no
# Scheme runtime, so it also holds under the no-scheme preset.
uri_add_test(
  NAME uri.harness.import-audit.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/UriImportAuditSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# uri_mutation_verdict decides whether a mutation was caught, and for
# the declared reason -- the decision every specification in this tree is
# ultimately trusted through, including the mutation suite below, which
# mutates it. Specified here, immediately before that suite, for the same
# reason SpecSupportSpec precedes it: a mutation against machinery a proof
# depends on must not be judged by the very thing it just broke.
uri_add_test(
  NAME uri.harness.cmake-mutation-runner.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/MutationRunnerSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# A passing specification proves nothing by itself. This breaks each decision in
# each module in turn, on a staged copy, and requires the owning specification to
# notice. It runs under `ctest` because evidence that only exists in someone's
# terminal cannot fail when the code changes.
uri_add_test(
  NAME uri.harness.cmake-mutation.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/MutationSuite.cmake"
  TIMEOUT 600
  LABELS unit)

# The exact-status assertion decides whether every expected-red test below is
# checking anything at all, so its functional core is specified before any of
# them relies on it.
uri_add_test(
  NAME uri.harness.cmake-expect-exit.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/UriExpectExitSpec.cmake"
  TIMEOUT 120
  LABELS unit)

# A lane's command line decides whether a source lane is really a source lane.
# Specified before any lane is registered against it.
uri_add_test(
  NAME uri.harness.cmake-scheme-lane.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/UriSchemeLaneSpec.cmake"
  TIMEOUT 120
  LABELS unit)




# --- Harness paths ---------------------------------------------------------

set(URI_HARNESS_DIR "${CMAKE_CURRENT_LIST_DIR}/support/harness")
set(URI_HARNESS_SELF_DIR "${URI_HARNESS_DIR}/self")
set(URI_HARNESS_CHEZ_LIBRARY_ROOT "${URI_HARNESS_DIR}")
set(URI_HARNESS_CHEZ_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/chez-source.ss")

# Per-runtime, per-machine object roots for the AOT lane. Keyed this way so a
# parallel build cannot race and an object built by one Chez is never loaded by
# another; nothing is written into the source tree.
set(URI_CHEZ_OBJECT_ROOT
    "${CMAKE_BINARY_DIR}/chez-objects/${URI_CHEZ_VERSION}/${URI_CHEZ_MACHINE_TYPE}")
# The keying above is only as real as these two variables. Empty, every Chez
# version and every machine type would share one object root, a `.so` built by
# a different Chez could be loaded as though it were current, and every AOT
# lane would stay green while proving nothing about the runtime that actually
# ran it -- the exact defect this slice exists to prevent. No task in its plan
# re-derives URI_CHEZ_VERSION or URI_CHEZ_MACHINE_TYPE to
# catch a regression here, so this is the one place that can. Guarded on
# URI_CHEZ_EXECUTABLE: on a host with no Chez neither variable is
# ever set, no AOT lane is registered, and an empty root is inert rather than
# a keying failure.
if(URI_CHEZ_EXECUTABLE)
  if(NOT URI_CHEZ_VERSION OR NOT URI_CHEZ_MACHINE_TYPE)
    message(FATAL_ERROR
      "uri: URI_CHEZ_VERSION ('${URI_CHEZ_VERSION}') "
      "and URI_CHEZ_MACHINE_TYPE ('${URI_CHEZ_MACHINE_TYPE}') "
      "must both be non-empty once a Chez has been discovered. They key "
      "URI_CHEZ_OBJECT_ROOT so a compiled object can never outlive "
      "the runtime that produced it; empty, every AOT lane would share one "
      "root across every Chez version and machine type ever built here, and a "
      "stale object could load silently while every lane stayed green.")
  endif()
endif()
set(URI_HARNESS_CHEZ_AOT_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/chez-aot.ss")
set(URI_HARNESS_CHEZ_COMPILE_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/chez-compile.ss")

# The object guard is what makes the Chez source lane honest: Chez looks for a
# compiled library only in the object half of a library-directories pair, so
# pairing the source root with a directory that is always empty makes a stale
# .so unloadable. It lives in the build tree precisely because nothing may ever
# be written into it.
set(URI_HARNESS_OBJECT_GUARD_DIR "${CMAKE_BINARY_DIR}/chez-object-guard")
file(MAKE_DIRECTORY "${URI_HARNESS_OBJECT_GUARD_DIR}")

# --- Source tree paths -----------------------------------------------------
#
# Read by uri_scheme_lane_command. src/ holds the product libraries;
# the harness above is test infrastructure. A lane imports from both, which is
# why the launcher takes repeatable roots. src/ is empty until the first
# parser slice lands; the lane machinery requires the directory to exist.
set(URI_SRC_CHEZ_LIBRARY_ROOT "${CMAKE_SOURCE_DIR}/src")

# --- The generator (decision 0002) -----------------------------------------
#
# byte-machine is a submodule pinned by gitlink at vendor/byte-machine. Its src
# is the library root for `(byte-machine ...)`; the collection under it is where
# the .sls files live. Setting this root is what puts the generator on every
# Chez lane's library path (uri_scheme_lane_command adds it when set) and turns
# the aot generator object-dir on. It arrives now, in the first slice that
# invokes the emitter -- an unexercised root rots exactly as an unexercised pin
# does (decision 0002 item 2). A set-but-missing root is a checkout mistake the
# lane machinery reports; the submodule is committed, so `git submodule update
# --init` is the fix.
set(URI_GENERATOR_CHEZ_LIBRARY_ROOT "${CMAKE_SOURCE_DIR}/vendor/byte-machine/src")
set(URI_GENERATOR_COLLECTION
    "${CMAKE_SOURCE_DIR}/vendor/byte-machine/src/byte-machine")
# The generator libraries a lane executes, in dependency order -- the order is
# load-bearing because the fingerprint combine is order-sensitive. Named
# explicitly rather than globbed: the fingerprint must describe exactly the text
# the pin carries, and a glob would silently absorb a file the pin added.
set(URI_GENERATOR_SOURCES
    "${URI_GENERATOR_COLLECTION}/private/conditions.sls"
    "${URI_GENERATOR_COLLECTION}/private/names.sls"
    "${URI_GENERATOR_COLLECTION}/private/ir.sls"
    "${URI_GENERATOR_COLLECTION}/private/normal-ir.sls"
    "${URI_GENERATOR_COLLECTION}/runtime.sls"
    "${URI_GENERATOR_COLLECTION}/graph.sls"
    "${URI_GENERATOR_COLLECTION}/verify.sls"
    "${URI_GENERATOR_COLLECTION}/interpret.sls"
    "${URI_GENERATOR_COLLECTION}/compile.sls")

# The sources every harness lane executes -- the two libraries; each lane
# appends its own program. Named once: a lane that listed them itself would
# drift, and a manifest that drifts is one that quietly stops describing the
# run.
set(URI_HARNESS_MANIFEST
    "${URI_HARNESS_CHEZ_LIBRARY_ROOT}/uri/test/fingerprint.sls"
    "${URI_HARNESS_CHEZ_LIBRARY_ROOT}/uri/test/harness.sls")

# --- Build-time fingerprint expectations -----------------------------------

set(URI_FINGERPRINT_LAUNCHER
    "${CMAKE_CURRENT_LIST_DIR}/support/launchers/fingerprint-manifest.ss")
set(URI_FINGERPRINT_DIR "${CMAKE_BINARY_DIR}/fingerprints")

# uri_expected_fingerprint(<name> <out_var> <source>...)
#
# Produce, at build time, the combined fingerprint the named lane must report,
# and set <out_var> to the file holding it.
#
# A build output rather than a configure-time value, because a registration's
# environment is fixed when CMake configures and this must be recomputed
# whenever a source changes -- which is precisely the case it exists to catch.
# The DEPENDS list is what makes that true, so a source added to a manifest
# without being added there produces an expectation that silently never
# refreshes.
#
# Keyed by a digest of the manifest, not by lane name: the value depends only on
# the manifest, and keying by name would spawn one Chez process per lane to
# produce a handful of distinct answers while hiding which lanes claim to run
# the same text.
function(uri_expected_fingerprint name out_var)
  if(NOT ARGN)
    message(FATAL_ERROR
      "uri: '${name}' asked for a fingerprint expectation over no "
      "sources. An empty manifest fingerprints to the seed on every lane, "
      "which would compare equal forever and check nothing.")
  endif()

  string(JOIN "|" manifest ${ARGN})
  string(SHA256 manifest_digest "${manifest}")
  string(SUBSTRING "${manifest_digest}" 0 16 manifest_key)
  set(expect_file "${URI_FINGERPRINT_DIR}/${manifest_key}.fingerprint")

  # add_custom_command rejects a second rule for the same OUTPUT, so the first
  # lane to need a manifest creates the rule and the rest reuse it.
  get_property(known GLOBAL PROPERTY URI_FINGERPRINT_MANIFESTS)
  if(NOT manifest_key IN_LIST known)
    set_property(GLOBAL APPEND PROPERTY URI_FINGERPRINT_MANIFESTS
                 "${manifest_key}")

    add_custom_command(
      OUTPUT "${expect_file}"
      COMMAND "${CMAKE_COMMAND}" -E make_directory "${URI_FINGERPRINT_DIR}"
      COMMAND "${URI_CHEZ_EXECUTABLE}" --script
              "${URI_FINGERPRINT_LAUNCHER}"
              "${URI_HARNESS_CHEZ_LIBRARY_ROOT}"
              "${URI_HARNESS_OBJECT_GUARD_DIR}"
              "${expect_file}"
              ${ARGN}
      DEPENDS ${ARGN}
              "${URI_FINGERPRINT_LAUNCHER}"
              "${URI_HARNESS_CHEZ_LIBRARY_ROOT}/uri/test/fingerprint.sls"
      COMMENT "uri: fingerprint manifest ${manifest_key} (first needed by ${name})"
      VERBATIM)

    add_custom_target("uri_fingerprint_${manifest_key}"
                      DEPENDS "${expect_file}")
    if(NOT TARGET uri_fingerprints)
      add_custom_target(uri_fingerprints ALL)
    endif()
    add_dependencies(uri_fingerprints
                     "uri_fingerprint_${manifest_key}")
  endif()

  set(${out_var} "${expect_file}" PARENT_SCOPE)
endfunction()

# A deliberately wrong expectation, so the provenance check is proved to fire by
# a registered lane rather than by editing a build artifact during a mutation
# gate. It is not a fingerprint of anything and cannot become one: every real
# value is lowercase hex, so no manifest can ever produce this text.
function(uri_wrong_fingerprint name out_var)
  set(expect_file "${URI_FINGERPRINT_DIR}/${name}.wrong")
  file(MAKE_DIRECTORY "${URI_FINGERPRINT_DIR}")
  file(WRITE "${expect_file}" "not-a-fingerprint")
  set(${out_var} "${expect_file}" PARENT_SCOPE)
endfunction()

# --- Harness lanes ---------------------------------------------------------

# The harness must be able to fail before it can be trusted to pass. This is
# that proof: a program that fails one assertion, with the exact status
# compared from outside, because a program cannot report its own exit status.
uri_add_scheme_lane(
  NAME uri.harness.failing-body.chez.source
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-failing.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-failing.sps"
  EXPECT_EXIT 1
  TIMEOUT 120
  LABELS expected-red)

# The runner cannot be its own only witness. This judges its primitives with
# raw conditionals, using none of the facilities it is checking.
uri_add_scheme_lane(
  NAME uri.harness.bootstrap.chez.source
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
  TIMEOUT 120)

# The runner tested with the runner. Safe only because the bootstrap already
# established its primitives, and because every deliberate failure here runs
# inside a probe.
uri_add_scheme_lane(
  NAME uri.harness.self.chez.source
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  TIMEOUT 120)

# A duplicate id is a defect in the suite, not a failing assertion: one
# registration silently became unreachable. Status 2, distinct from 1.
uri_add_scheme_lane(
  NAME uri.harness.duplicate-case.chez.source
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-duplicate-case.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-duplicate-case.sps"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red)

# A suite that selected nothing must not report success, for the same reason
# the presets refuse an empty CTest selection one layer up.
uri_add_scheme_lane(
  NAME uri.harness.empty-selection.chez.source
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-empty-selection.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-empty-selection.sps"
  EXPECT_EXIT 2
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "URI_TEST_FILTER=no-case-has-this-in-its-name")

# --- The verbose pass line -------------------------------------------------
#
# URI_TEST_VERBOSE makes the runner announce every passing case.
# Nothing else in this tree sets it, so without this lane the feature would
# never be executed by any test at all: the environment read, the empty-string
# rule, and the print itself would first run for whoever turned the variable on,
# and a typo in any of them would surface there rather than here.
#
# One registration is enough: the decision lives in the runner section of
# harness.sls, which reads nothing runtime-specific to make it, so a second lane
# would not exercise a different code path -- the same argument the mutation
# suite's first pass makes for every other decision in it.
#
# What this lane cannot check is that the line was printed. The adapter
# protocol exposes no output-capture service, and the runner may not reach past
# its protocol for one -- so it has no way to read back its own output, and the
# registration layer asserts exit status, not output. Both decisions are
# therefore declared survivors in SchemeMutationSuite.cmake with their reason
# recorded, alongside probe output suppression, which is unwitnessable for
# exactly the same reason.
uri_add_scheme_lane(
  NAME uri.harness.verbose.chez.source
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  TIMEOUT 120
  ENVIRONMENT "URI_TEST_VERBOSE=1")

# --- The Chez launcher's refusals ------------------------------------------
#
# The launcher decides whether a lane runs at all, and its object guard is the
# sole mechanism that makes `mode=source` an honest claim. Three places in this
# tree say so -- the spec's section 7.1, UriSchemeLane.cmake, and the
# Chez adapter -- and until these lanes existed none of them checked it: every
# decision in the launcher could be deleted, and a file dropped into the guard
# directory, with all twenty tests still green, because a healthy lane never
# reaches a refusal.
#
# One lane per `die` path, each asserting status 2 exactly. Registered through
# the exact-status helper directly rather than through
# uri_add_scheme_lane, whose whole purpose is to build the one correct
# command line; these three need deliberately wrong ones. Guarded on a
# discovered Chez the same way the mutation suite below is, so
# `ctest --preset no-scheme` stays green on a host with no Scheme runtime.
if(URI_CHEZ_EXECUTABLE)
  # A guard directory that has acquired a file is no longer a guard. The file is
  # written into the build tree rather than committed: a file checked into the
  # source tree solely to make a directory non-empty is one every future glob,
  # packaging step, and reader has to be told to ignore.
  set(URI_HARNESS_DIRTY_GUARD_DIR
      "${CMAKE_BINARY_DIR}/chez-object-guard-dirty")
  file(MAKE_DIRECTORY "${URI_HARNESS_DIRTY_GUARD_DIR}")
  file(WRITE "${URI_HARNESS_DIRTY_GUARD_DIR}/stray-object.so"
    "Not a compiled library. Its only job is to stop this directory being empty,\n"
    "so uri.harness.launcher-dirty-guard.chez.source can prove the\n"
    "launcher refuses a guard directory that has acquired a file.\n")

  # Deliberately never created. The launcher must refuse a guard directory that
  # is not there rather than assume it, since `directory-list` on a missing path
  # raises and would report a crash where a named harness error belongs.
  set(URI_HARNESS_ABSENT_GUARD_DIR
      "${CMAKE_BINARY_DIR}/chez-object-guard-absent")

  # A launcher invoked with nothing at all. Replaces the exact-arity refusal the
  # positional protocol had; with flags, "no arguments" is the natural form of
  # the same mistake.
  uri_add_exit_code_test(
    NAME uri.harness.launcher-no-program.chez.source
    COMMAND "${URI_CHEZ_EXECUTABLE}"
            "--script" "${URI_HARNESS_CHEZ_LAUNCHER}"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red)

  uri_add_exit_code_test(
    NAME uri.harness.launcher-absent-guard.chez.source
    COMMAND "${URI_CHEZ_EXECUTABLE}"
            "--script" "${URI_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${URI_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${URI_HARNESS_ABSENT_GUARD_DIR}"
            "--program" "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "URI_EXECUTION_MODE=source")

  uri_add_exit_code_test(
    NAME uri.harness.launcher-dirty-guard.chez.source
    COMMAND "${URI_CHEZ_EXECUTABLE}"
            "--script" "${URI_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${URI_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${URI_HARNESS_DIRTY_GUARD_DIR}"
            "--program" "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "URI_EXECUTION_MODE=source")

  # One lane per parse decision. A correctly set-up lane never reaches a
  # refusal, so nothing else in this tree can notice one being deleted. Each
  # names a real program where it can, so that deleting the refusal produces a
  # lane that runs and exits 0 rather than one that fails for another reason.
  uri_add_exit_code_test(
    NAME uri.harness.launcher-unknown-flag.chez.source
    COMMAND "${URI_CHEZ_EXECUTABLE}"
            "--script" "${URI_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${URI_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${URI_HARNESS_OBJECT_GUARD_DIR}"
            "--librarie-root" "${URI_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--program" "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "URI_EXECUTION_MODE=source")

  # A trailing flag. Without this refusal it would mean "no program" and be
  # reported as a missing required flag, sending the reader to the wrong line.
  uri_add_exit_code_test(
    NAME uri.harness.launcher-missing-value.chez.source
    COMMAND "${URI_CHEZ_EXECUTABLE}"
            "--script" "${URI_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${URI_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${URI_HARNESS_OBJECT_GUARD_DIR}"
            "--program"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red)

  uri_add_exit_code_test(
    NAME uri.harness.launcher-repeated-flag.chez.source
    COMMAND "${URI_CHEZ_EXECUTABLE}"
            "--script" "${URI_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${URI_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${URI_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
            "--program" "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "URI_EXECUTION_MODE=source")

  # The lane above witnesses the single-valued-flag check only through
  # --program; --object-guard has never been exercised as a repeated flag.
  # Both occurrences name the same real, empty guard directory -- the check
  # counts occurrences, not distinct values, so that is enough to trigger it.
  uri_add_exit_code_test(
    NAME uri.harness.launcher-repeated-object-guard.chez.source
    COMMAND "${URI_CHEZ_EXECUTABLE}"
            "--script" "${URI_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${URI_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--object-guard" "${URI_HARNESS_OBJECT_GUARD_DIR}"
            "--object-guard" "${URI_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "URI_EXECUTION_MODE=source")

  # The three remaining required-flag entries. Each is a separate lane because
  # required-flags is a list: an entry dropped from it is invisible to every
  # lane but the one that omits that flag.
  uri_add_exit_code_test(
    NAME uri.harness.launcher-no-library-root.chez.source
    COMMAND "${URI_CHEZ_EXECUTABLE}"
            "--script" "${URI_HARNESS_CHEZ_LAUNCHER}"
            "--object-guard" "${URI_HARNESS_OBJECT_GUARD_DIR}"
            "--program" "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "URI_EXECUTION_MODE=source")

  uri_add_exit_code_test(
    NAME uri.harness.launcher-no-object-guard.chez.source
    COMMAND "${URI_CHEZ_EXECUTABLE}"
            "--script" "${URI_HARNESS_CHEZ_LAUNCHER}"
            "--library-root" "${URI_HARNESS_CHEZ_LIBRARY_ROOT}"
            "--program" "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 120
    LABELS expected-red
    ENVIRONMENT "URI_EXECUTION_MODE=source")
endif()

# A lane that is set up correctly never reaches a launcher refusal, so each one
# needs a lane of its own or a deleted refusal is invisible. The same argument
# the nine chez-source.ss refusals above are registered under.
#
# Three lanes, not one per refusal in these files. The flag-vocabulary
# refusals below the parser, and --source-guard's own absent-directory check,
# are the same shape as refusals chez-source.ss already carries and already
# has lanes for; re-proving a verbatim shape in a new file buys nothing. These
# three are what is actually new here: chez-aot.ss's missing-program check,
# chez-compile.ss's unpaired-roots check, and --source-guard's non-empty-guard
# check -- the one that most directly proves the hazard the flag exists to
# close.
if(URI_CHEZ_EXECUTABLE)
  uri_add_exit_code_test(
    NAME uri.harness.chez-aot-launcher-missing-program.chez.aot
    COMMAND "${URI_CHEZ_EXECUTABLE}" --script
            "${URI_HARNESS_CHEZ_AOT_LAUNCHER}"
            --object-dir "${CMAKE_BINARY_DIR}"
            --source-guard "${URI_HARNESS_OBJECT_GUARD_DIR}"
            --program "${CMAKE_BINARY_DIR}/no-such-program.so"
    EXPECT_EXIT 2
    TIMEOUT 60
    LABELS expected-red)

  uri_add_exit_code_test(
    NAME uri.harness.chez-compile-launcher-unpaired-roots.chez.aot
    COMMAND "${URI_CHEZ_EXECUTABLE}" --script
            "${URI_HARNESS_CHEZ_COMPILE_LAUNCHER}"
            --library-root "${URI_HARNESS_CHEZ_LIBRARY_ROOT}"
            --library-root "${URI_SRC_CHEZ_LIBRARY_ROOT}"
            --object-dir "${CMAKE_BINARY_DIR}"
            --program "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
            --output "${CMAKE_BINARY_DIR}/unused.so"
    EXPECT_EXIT 2
    TIMEOUT 60
    LABELS expected-red)

  # The one new decision --source-guard's own checks add over chez-source.ss's
  # object-guard shape: chez-source.ss's launcher-dirty-guard.chez.source lane
  # already proves this die branch works when a guard has acquired a file, but
  # only for chez-source.ss's own copy of the check. Reuses
  # URI_HARNESS_DIRTY_GUARD_DIR rather than declaring a second dirty
  # directory: both are the same fixture -- a build-tree directory holding one
  # stray file for the sole purpose of not being empty.
  uri_add_exit_code_test(
    NAME uri.harness.chez-aot-launcher-dirty-source-guard.chez.aot
    COMMAND "${URI_CHEZ_EXECUTABLE}" --script
            "${URI_HARNESS_CHEZ_AOT_LAUNCHER}"
            --object-dir "${CMAKE_BINARY_DIR}"
            --source-guard "${URI_HARNESS_DIRTY_GUARD_DIR}"
            --program "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
    EXPECT_EXIT 2
    TIMEOUT 60
    LABELS expected-red)
endif()

# --- Chez ahead-of-time lanes ----------------------------------------------
#
# Two of the programs the source lanes run, compiled. Nothing about the
# sources changes; what changes is that the text reaching the process came
# out of objects built earlier, which is why these lanes measure the copies
# the compile step kept rather than the repository sources. Two lanes, not
# one per source lane: bootstrap (the runner's primitives with no runner)
# and self (the runner on itself).
uri_add_scheme_lane(
  NAME uri.harness.bootstrap.chez.aot
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-bootstrap.sps"
  TIMEOUT 120)

uri_add_scheme_lane(
  NAME uri.harness.self.chez.aot
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  TIMEOUT 120)

# --- Mutation proof for the harness ----------------------------------------

# The harness is the instrument every later milestone is measured with, so a
# passing self-test suite is not evidence until something has proved it can
# fail. This breaks each decision in the runner on a staged copy and requires
# the self-tests to notice. Registered only when a Chez was discovered: it runs
# a real lane and cannot be verified under the no-scheme preset.
#
# The self-tests load the fingerprint fixture through adapter-file-bytes; staged
# lanes inherit this process's environment through execute_process, so the
# variable must be set here.
if(URI_CHEZ_EXECUTABLE)
  uri_add_test(
    NAME uri.harness.scheme-mutation.cmake.direct
    COMMAND "${CMAKE_COMMAND}"
            "-DURI_CHEZ_EXECUTABLE=${URI_CHEZ_EXECUTABLE}"
            -P "${CMAKE_CURRENT_LIST_DIR}/support/cmake/SchemeMutationSuite.cmake"
    TIMEOUT 900
    LABELS unit
    ENVIRONMENT "URI_EXECUTION_MODE=source"
                "URI_FINGERPRINT_SAMPLE=${CMAKE_SOURCE_DIR}/test/fixtures/fingerprint-sample.bin")
endif()

# --- Provenance ------------------------------------------------------------
#
# Every lane above checks the fingerprint of the text it ran against the value
# the build computed. These prove that check can fail. Without them the
# mechanism would be a claim: protium recorded two occasions where two of its
# lanes printed different digests for text both said they ran, and the suite
# stayed green, because nothing read the values back.
#
# Status 3 is what makes them falsifiable. Several lanes in this tree
# legitimately expect 1 or 2, so a provenance failure sharing either status
# would be indistinguishable from those fixtures' own expected outcomes.
uri_add_scheme_lane(
  NAME uri.harness.provenance.chez.source
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  WRONG_FINGERPRINT
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)

# Two more refusals. Neither is wrapped in if(URI_CHEZ_EXECUTABLE):
# each is a BACKEND chez lane, so uri_add_scheme_lane's own
# no-runtime return already skips it on a Chez-less host, the same mechanism
# that skips the lane above.

# The build never produced this file, and never will: no rule names it as an
# output. That is the "you did not build before running the tests" case, which
# would otherwise escape as a raw I/O condition and a status outside the
# vocabulary.
uri_add_scheme_lane(
  NAME uri.harness.provenance-absent-expectation.chez.source
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "URI_EXPECT_FINGERPRINT_FILE=${CMAKE_BINARY_DIR}/fingerprints/never-produced.fingerprint")

# A manifest naming a source that is not there. What fails is reading the text,
# before any comparison happens.
uri_add_scheme_lane(
  NAME uri.harness.provenance-missing-body.chez.source
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red
  ENVIRONMENT "URI_FINGERPRINT_FILES=${CMAKE_BINARY_DIR}/fingerprints/no-such-body.scm")

# Provenance configured and never performed. SOURCES guarantees the
# environment carries a manifest; nothing until now guaranteed anything read
# it. This program reaches harness-summary without ever reaching
# harness-verify-provenance!, which is precisely the shape harness-bootstrap
# would have had if its hand-placed call had been forgotten -- and that would
# have run un-provenanced with nothing failing.
#
# A real manifest, deliberately: with none, the run is a process no lane
# registration started, and skipping is correct rather than a defect.
#
# Not wrapped in if(URI_CHEZ_EXECUTABLE): this is a BACKEND chez
# lane, so uri_add_scheme_lane's own no-runtime return already skips
# it on a Chez-less host.
uri_add_scheme_lane(
  NAME uri.harness.unreached-provenance.chez.source
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-unreached-provenance.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-unreached-provenance.sps"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)

# An artifact built from text this registration does not declare. The
# expectation comes from the real harness.sls; the compile step resolves
# (uri test harness) from a divergent fixture copy instead and
# keeps that copy as what the run measures. The two disagree, so the lane
# exits 3. This is the only lane in the tree that can fail when a compiled
# lane's fingerprint stops describing its artifact -- a lane rather than a
# mutation because the Scheme mutation suite stages one already-mutated
# tree per pass and cannot express "built before the edit, run after it"
# (design W12, slice 5a task 6).
uri_add_scheme_lane(
  NAME uri.harness.stale-artifact.chez.aot
  BACKEND chez
  PROGRAM "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          "${URI_HARNESS_SELF_DIR}/harness-self-tests.sps"
  STALE_LIBRARY_ROOT "${CMAKE_CURRENT_LIST_DIR}/fixtures/stale-root"
  EXPECT_EXIT 3
  TIMEOUT 120
  LABELS expected-red)

# --- The corpus harness (M1) ------------------------------------------------
#
# Decision 0005 makes RFC 3986's own vectors the anchor of the resolution
# layer, which puts the reading of them on the critical path: a loader that is
# one row off makes every later comparison wrong and the failure reads as a
# parser defect. These lanes judge the reading machinery -- loader, comparator,
# ratchet -- on the committed corpus and on hand-built inputs, before any URI
# is parsed.

set(URI_CORPUS_DIR "${CMAKE_CURRENT_LIST_DIR}/conformance/rfc3986")
set(URI_RATCHET_FILE "${CMAKE_CURRENT_LIST_DIR}/conformance/ratchet.txt")
set(URI_CORPUS_LIB
    "${URI_HARNESS_CHEZ_LIBRARY_ROOT}/uri/test/corpus.sls")
set(URI_RATCHET_LIB
    "${URI_HARNESS_CHEZ_LIBRARY_ROOT}/uri/test/ratchet.sls")

foreach(mode source aot)
  uri_add_scheme_lane(
    NAME uri.unit.corpus.chez.${mode}
    BACKEND chez
    PROGRAM "${CMAKE_CURRENT_LIST_DIR}/common/corpus-tests.sps"
    SOURCES ${URI_HARNESS_MANIFEST}
            ${URI_CORPUS_LIB}
            ${URI_RATCHET_LIB}
            "${CMAKE_CURRENT_LIST_DIR}/common/corpus-tests.sps"
    ENVIRONMENT "URI_CORPUS_DIR=${URI_CORPUS_DIR}"
                "URI_RATCHET_FILE=${URI_RATCHET_FILE}"
    TIMEOUT 120
    LABELS unit)
endforeach()

# --- The M2 pure seam ------------------------------------------------------
#
# The first product code (decision 0008, 0004, 0009): the vocabulary the
# grammar, the harness and an embedder agree on, and the components type the
# scanner fills and the core reads. Both are pure `(rnrs)` libraries under src/,
# so the src library root the lane already passes resolves them, and both run in
# source and aot modes like every other Scheme lane. No grammar and no
# generator are imported here -- these are the parts of M2 that stand alone.
foreach(mode source aot)
  uri_add_scheme_lane(
    NAME uri.unit.vocabulary.chez.${mode}
    BACKEND chez
    PROGRAM "${CMAKE_CURRENT_LIST_DIR}/common/vocabulary-tests.sps"
    SOURCES ${URI_HARNESS_MANIFEST}
            "${URI_SRC_CHEZ_LIBRARY_ROOT}/uri/vocabulary.sls"
            "${CMAKE_CURRENT_LIST_DIR}/common/vocabulary-tests.sps"
    TIMEOUT 120
    LABELS unit)

  uri_add_scheme_lane(
    NAME uri.unit.components.chez.${mode}
    BACKEND chez
    PROGRAM "${CMAKE_CURRENT_LIST_DIR}/common/components-tests.sps"
    SOURCES ${URI_HARNESS_MANIFEST}
            "${URI_SRC_CHEZ_LIBRARY_ROOT}/uri/components.sls"
            "${CMAKE_CURRENT_LIST_DIR}/common/components-tests.sps"
    TIMEOUT 120
    LABELS unit)
endforeach()

# The generator ABI (decision 0002 item 3), the first of the two lanes it asks
# for. This one reads the ABI out of a FRESHLY emitted smoke machine; the second
# reads it out of the committed artifact and arrives with the grammar. Source
# only: the lane asks "is the pin wired and speaking ABI 9", which is the same
# question in both modes, and an aot twin would compile the whole generator per
# lane to re-answer it. The source/aot pair returns with the first real grammar,
# where it has something to prove.
uri_add_scheme_lane(
  NAME uri.unit.generator-abi.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_CURRENT_LIST_DIR}/common/generator-abi-tests.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          ${URI_GENERATOR_SOURCES}
          "${CMAKE_CURRENT_LIST_DIR}/common/generator-abi-tests.sps"
  TIMEOUT 180
  LABELS unit)

# --- The grammar (M2 Slice ①) ----------------------------------------------
#
# `(uri grammar)` imports `(uri vocabulary)`, so a lane that had one and not the
# other would build against a stale table. The scanner is judged through the
# reference interpreter against the split oracle -- the decompositions were
# derived from RFC 3986's ABNF independently of this grammar.
set(URI_VOCABULARY "${URI_SRC_CHEZ_LIBRARY_ROOT}/uri/vocabulary.sls")
set(URI_GRAMMAR ${URI_VOCABULARY} "${URI_SRC_CHEZ_LIBRARY_ROOT}/uri/grammar.sls")
set(URI_GENERATED_PARSER "${URI_SRC_CHEZ_LIBRARY_ROOT}/generated/uri-scanner.sls")

foreach(mode source aot)
  uri_add_scheme_lane(
    NAME uri.unit.grammar.chez.${mode}
    BACKEND chez
    PROGRAM "${CMAKE_CURRENT_LIST_DIR}/common/grammar-tests.sps"
    SOURCES ${URI_HARNESS_MANIFEST}
            ${URI_GENERATOR_SOURCES}
            ${URI_GRAMMAR}
            "${CMAKE_CURRENT_LIST_DIR}/common/grammar-tests.sps"
    TIMEOUT 180
    LABELS unit)
endforeach()

# The scanner ships as a checked-in derived artifact, committed so it is
# reviewable as a diff and loadable without a generator (decision 0002 item 4).
# This lane re-emits and compares bytes, reads the ABI out of the committed text,
# and runs the ARTIFACT ITSELF against the interpreter -- so a grammar edit
# without a `make parser-refresh`, a hand-edited artifact, and a stale ABI all
# redden. Source only: it re-emits, which needs the compiler; the aot twin would
# compile the whole generator to re-answer the same question.
uri_add_scheme_lane(
  NAME uri.determinism.generated-artifact.chez.source
  BACKEND chez
  PROGRAM "${CMAKE_CURRENT_LIST_DIR}/common/generated-artifact-tests.sps"
  SOURCES ${URI_HARNESS_MANIFEST}
          ${URI_GENERATOR_SOURCES}
          ${URI_GRAMMAR}
          ${URI_GENERATED_PARSER}
          "${CMAKE_CURRENT_LIST_DIR}/common/generated-artifact-tests.sps"
  ENVIRONMENT "URI_GENERATED_PARSER=${URI_GENERATED_PARSER}"
  TIMEOUT 180
  LABELS determinism)

# --- (uri collect): the shell (M2 Slice ③) ---------------------------------
#
# The imperative shell: it feeds bytes to the committed scanner and assembles a
# five-field uri-components, reading the on-rooted and verdict signals. Judged on
# the assembly (the scanner is judged in unit.grammar), plus the section 1.1.2
# example URIs parsing through it from the derived corpus.
set(URI_COLLECT ${URI_VOCABULARY}
                "${URI_SRC_CHEZ_LIBRARY_ROOT}/uri/components.sls"
                "${URI_SRC_CHEZ_LIBRARY_ROOT}/uri/collect.sls")

foreach(mode source aot)
  uri_add_scheme_lane(
    NAME uri.unit.collect.chez.${mode}
    BACKEND chez
    PROGRAM "${CMAKE_CURRENT_LIST_DIR}/common/collect-tests.sps"
    SOURCES ${URI_HARNESS_MANIFEST}
            ${URI_GENERATOR_SOURCES}
            ${URI_COLLECT}
            ${URI_GENERATED_PARSER}
            ${URI_CORPUS_LIB}
            "${CMAKE_CURRENT_LIST_DIR}/common/collect-tests.sps"
    ENVIRONMENT "URI_CORPUS_DIR=${URI_CORPUS_DIR}"
    TIMEOUT 180
    LABELS unit)
endforeach()

# The corpus is DERIVED from the vendored RFC text (decision 0005). This lane
# re-derives it and compares, so a hand edit to a vector -- the one thing that
# would make a green lane meaningless -- reddens instead. It runs the same
# functions `make corpus-refresh` runs, and needs no Scheme runtime, so it also
# holds under the no-scheme preset.
uri_add_test(
  NAME uri.harness.corpus-provenance.cmake.direct
  COMMAND "${CMAKE_COMMAND}" -P
          "${CMAKE_CURRENT_LIST_DIR}/support/cmake/CorpusProvenanceSpec.cmake"
  TIMEOUT 120
  LABELS unit)
