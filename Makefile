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
AKKU ?= akku
CHEZ ?= chez

# The docs site is rendered with chez-cmark-gfm, which is not a dependency of
# the library: name it with CMARK_GFM_ROOT, either a git checkout (its
# libraries are in src/) or a directory where `akku install chez-cmark-gfm`
# ran (they are in .akku/lib/). A checkout wins when both are there, as in
# chez-cmark-gfm's own. CMARK_GFM_LIBDIR is the directory that resolves to; set
# it to name any other. These targets run Chez directly rather than through
# CMake, so the site builds on a distribution's Chez as well as on the version
# the library's own build requires. SITE_REF is the git ref that ../ links in
# docs/ are pinned to on GitHub. test/site/cmark-gfm-root.sh checks the
# resolution.
SITE_REF ?= main
CMARK_GFM_LIBDIR ?= $(firstword $(foreach d,src .akku/lib,$(if $(wildcard $(CMARK_GFM_ROOT)/$(d)/cmark/gfm.sls),$(CMARK_GFM_ROOT)/$(d))))
SITE_LIBDIRS = .:test/site:test/support/harness:$(CMARK_GFM_LIBDIR)

# Bare 'make' prints the target list rather than building; 'make all' still builds.
.DEFAULT_GOAL := help

.PHONY: all help doctor configure build dev test test-all no-scheme prod clean corpus-refresh parser-refresh check-akku site check-site cmark-gfm-root check-help

all: build   ## build the development preset

# 'help' prints every target that carries a '## ' description by scanning this
# Makefile itself, so the descriptions live beside the targets they document
# and cannot drift out of sync with them: add a target with a '## ' note and
# it appears here automatically.
help:   ## list these targets (shown when you run a bare 'make')
	@echo "chez-uri make targets:"
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z][a-zA-Z_-]*:.*## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
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
# hand-edited. This is the only way it is written: the
# initial derivation and every refresh run the same script, and the registered
# lane uri.harness.corpus-provenance runs the same functions and compares, so a
# refresh cannot drift from the check that guards it.
corpus-refresh:   ## re-derive the RFC 3986 corpus from the vendored text
	$(CMAKE) -P cmake/UriCorpusRefresh.cmake

# src/generated/uri-scanner.sls is DERIVED from src/uri/grammar.sls by one
# emitter. This runs that emitter; the determinism lane
# runs the same one and compares, so a grammar edit without a refresh reddens.
parser-refresh:   ## re-emit the committed URI scanner from the grammar
	$(CMAKE) -P cmake/UriParserRefresh.cmake

# Installs this package with Akku as a consumer would, from the files git
# tracks, then checks that exactly the libraries under src/ install and that a
# program reads a URI with only Akku's library path. It is a target, not a
# lane, because it needs akku, which no lane can assume is installed.
check-akku:   ## install with Akku as a consumer would, and check what lands
	@AKKU="$(AKKU)" CHEZ="$(CHEZ)" sh test/akku/check-akku.sh

# Each site target first checks that chez-cmark-gfm was found, so a missing or
# wrong path fails with a sentence rather than a library-not-found.
cmark-gfm-root:   ## check that CMARK_GFM_ROOT names a chez-cmark-gfm checkout or Akku install
	@test -n "$(CMARK_GFM_ROOT)$(CMARK_GFM_LIBDIR)" || { echo "set CMARK_GFM_ROOT to a chez-cmark-gfm checkout, or to where 'akku install chez-cmark-gfm' ran" >&2; exit 2; }
	@test -f "$(CMARK_GFM_LIBDIR)/cmark/gfm.sls" || { echo "$(CMARK_GFM_ROOT) holds neither src/cmark/gfm.sls (a chez-cmark-gfm checkout) nor .akku/lib/cmark/gfm.sls (an 'akku install chez-cmark-gfm')" >&2; exit 2; }

# docs/*.md, rendered to build/site/ through chez-cmark-gfm. docs/README.md
# becomes index.html.
site: cmark-gfm-root   ## render docs/ into build/site/ (needs CMARK_GFM_ROOT)
	@mkdir -p build/site
	@CHEZSCHEMELIBDIRS=$(SITE_LIBDIRS) SITE_REF="$(SITE_REF)" \
	  $(CHEZ) --program build-site.sps
	@cp site/style.css build/site/style.css
	@echo "site: build/site ready (open build/site/index.html)"

# The generator's own suites first, then the real site checked in memory: the
# nav lists exactly docs/*.md, every link and anchor resolves, no .md link
# leaks into the HTML, and preformatted code is never reflowed.
check-site: cmark-gfm-root   ## test the site generator, then check docs/ with it
	@sh test/site/cmark-gfm-root.sh
	@CHEZSCHEMELIBDIRS=$(SITE_LIBDIRS) $(CHEZ) --program test/site/test-site.sps
	@CHEZSCHEMELIBDIRS=$(SITE_LIBDIRS) $(CHEZ) --program test/site/test-site-render.sps
	@CHEZSCHEMELIBDIRS=$(SITE_LIBDIRS) SITE_REF="$(SITE_REF)" \
	  $(CHEZ) --program test/site/site-check.sps

clean:   ## remove all build trees
	$(CMAKE) -E rm -rf build

# CONTRIBUTING.md and the pull-request template tell people which targets to
# run, so each `make TARGET` they quote, in backticks, must be one of these.
# A file that quotes none fails too: a misread file holds no bad target either.
# Every .PHONY target needs a '## ' note, or 'help' leaves it out.
check-help:   ## fail if a target has no description, or the contributor docs quote one that is not a target
	@missing=0; \
	targets=$$(awk '/^\.PHONY:/ { $$1=""; print }' Makefile); \
	for t in $$targets; do \
	  grep -qE "^$$t:.*## " Makefile || { echo "check-help: '$$t' has no '## ' description" >&2; missing=1; }; \
	done; \
	for f in CONTRIBUTING.md .github/PULL_REQUEST_TEMPLATE.md; do \
	  [ -f "$$f" ] || { echo "check-help: $$f is missing" >&2; missing=1; continue; }; \
	  quoted=$$(grep -oE '`[^`]*`' "$$f" | grep -oE '(^|[` ])make [a-z][a-z0-9-]*' | awk '{ print $$2 }' | sort -u); \
	  [ -n "$$quoted" ] || { echo "check-help: $$f quotes no make target, so this check read nothing in it" >&2; missing=1; }; \
	  for t in $$quoted; do \
	    case " $$targets " in \
	      *" $$t "*) ;; \
	      *) echo "check-help: $$f quotes 'make $$t', and $$t is not a target" >&2; missing=1 ;; \
	    esac; \
	  done; \
	done; \
	exit $$missing
