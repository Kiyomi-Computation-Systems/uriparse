# chez-uri canonical entry points.
#
# Development and CI both use these targets and the checked-in CMake presets.
# Windows has no make in the base install, so these are a convenience over the
# presets, never the only way in: `cmake --preset dev` and `ctest --preset pr`
# work identically everywhere.
#
# An empty selection is a failure, never a silent pass. That rule lives in the
# test presets themselves (execution.noTestsAction), not only here, or the
# preset path documented above would quietly accept what this path rejects --
# and the whole point of the paragraph above is that the two are equivalent.
# CTEST_FLAGS keeps --no-tests=error as well so an older CTest still refuses.

CMAKE ?= cmake
CTEST ?= ctest
CTEST_FLAGS ?= --output-on-failure --no-tests=error

# Bare 'make' prints the target list rather than building; 'make all' still builds.
.DEFAULT_GOAL := help

.PHONY: all help doctor configure build dev test test-all no-scheme prod clean corpus-refresh parser-refresh

all: build   ## build the development preset

# 'help' prints every target that carries a '## ' description by scanning this
# Makefile itself, so the descriptions live beside the targets they document
# and cannot drift out of sync with them: add a target with a '## ' note and
# it appears here automatically.
help:   ## list these targets (shown when you run a bare 'make')
	@echo "chez-uri make targets:"
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z][a-zA-Z_-]*:.*## / {printf "  %-11s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "If discovery cannot find a runtime, point it at one explicitly:"
	@echo "  cmake --preset dev -DURI_CHEZ_EXECUTABLE=/absolute/path/to/scheme"

# Configure is where discovery runs and where every toolchain diagnostic is
# emitted, so 'doctor' is just a configure whose output is the point.
doctor:   ## report the discovered Chez toolchain, then stop
	$(CMAKE) --preset dev

configure:   ## configure the development preset without building
	$(CMAKE) --preset dev

build: configure   ## configure and build the development preset
	$(CMAKE) --build --preset dev

dev: build   ## build, then run the harness and build-layer self-tests
	$(CTEST) --preset harness $(CTEST_FLAGS)

test: build   ## build, then run the pull-request selection
	$(CTEST) --preset pr $(CTEST_FLAGS)

test-all: build   ## build, then run the complete selection
	$(CTEST) --preset release $(CTEST_FLAGS)

# The CMake layer decides what every other lane can even see, so it is checked
# on a host with no Scheme at all -- which is also the cell that proves the
# build does not silently require one.
no-scheme:   ## run the CMake-layer specifications with no Scheme runtime
	$(CMAKE) --preset no-scheme
	$(CTEST) --preset no-scheme $(CTEST_FLAGS)

prod:   ## configure and build the release preset
	$(CMAKE) --preset prod
	$(CMAKE) --build --preset prod

# test/conformance/rfc3986/ is DERIVED from the vendored RFC text and is never
# hand-edited (decision 0005 item 2). This is the only way it is written: the
# initial derivation and every refresh run the same script, and the registered
# lane uri.harness.corpus-provenance runs the same functions and compares, so a
# refresh cannot drift from the check that guards it.
corpus-refresh:   ## re-derive the RFC 3986 corpus from the vendored text
	$(CMAKE) -P cmake/UriCorpusRefresh.cmake

# src/generated/uri-scanner.sls is DERIVED from src/uri/grammar.sls by one
# emitter (decision 0002 item 4). This runs that emitter; the determinism lane
# runs the same one and compares, so a grammar edit without a refresh reddens.
parser-refresh:   ## re-emit the committed URI scanner from the grammar
	$(CMAKE) -P cmake/UriParserRefresh.cmake

clean:   ## remove all build trees
	$(CMAKE) -E rm -rf build
