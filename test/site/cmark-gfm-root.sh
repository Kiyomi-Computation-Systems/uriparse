#!/bin/sh
# Which chez-cmark-gfm the site targets load, for each shape CMARK_GFM_ROOT can
# name. Run by `make check-site` before the suites, from the repository root;
# needs make and sh, not Chez or chez-cmark-gfm.
#
#   - a git checkout: the libraries are in src/;
#   - a directory where `akku install chez-cmark-gfm` ran: they are in .akku/lib/;
#   - both (chez-cmark-gfm's own checkout carries an .akku/): the checkout wins;
#   - neither: refused, naming both shapes, before Chez ever runs;
#   - CMARK_GFM_LIBDIR set: used as it is.
#
# Each case reads the CHEZSCHEMELIBDIRS that `make -n site` would run Chez
# with, so it judges the value the recipe uses, not a copy of the logic.
set -u
fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

fixture() {  # fixture <dir> <libdir-relative-to-it>
  mkdir -p "$1/$2/cmark"
  : > "$1/$2/cmark/gfm.sls"
}

libdirs() {  # the library path `make site` would hand Chez
  make -n -s --no-print-directory site "$@" 2>/dev/null |
    sed -n 's/.*CHEZSCHEMELIBDIRS=\([^ ]*\).*/\1/p' | head -1
}

expect() {  # expect <label> <wanted> <make args...>
  label=$1 wanted=$2; shift 2
  got=$(libdirs "$@")
  if [ "$got" = "$wanted" ]; then
    echo "cmark-gfm-root: ok $label"
  else
    echo "cmark-gfm-root: FAIL $label: wanted CHEZSCHEMELIBDIRS=$wanted, got '$got'" >&2
    fail=1
  fi
}

base=.:test/site:test/support/harness

fixture "$tmp/checkout" src
expect "a checkout loads its src/" "$base:$tmp/checkout/src" CMARK_GFM_ROOT="$tmp/checkout"

fixture "$tmp/akku" .akku/lib
expect "an Akku install loads its .akku/lib/" "$base:$tmp/akku/.akku/lib" CMARK_GFM_ROOT="$tmp/akku"

fixture "$tmp/both" src
fixture "$tmp/both" .akku/lib
expect "a checkout with an .akku/ loads its src/" "$base:$tmp/both/src" CMARK_GFM_ROOT="$tmp/both"

expect "CMARK_GFM_LIBDIR is used as it is" "$base:$tmp/akku/.akku/lib" \
  CMARK_GFM_ROOT="$tmp/checkout" CMARK_GFM_LIBDIR="$tmp/akku/.akku/lib"

mkdir -p "$tmp/neither"
if out=$(make -s --no-print-directory cmark-gfm-root CMARK_GFM_ROOT="$tmp/neither" 2>&1); then
  echo "cmark-gfm-root: FAIL a root with neither shape was accepted" >&2
  fail=1
else
  case "$out" in
    *src/cmark/gfm.sls*.akku/lib/cmark/gfm.sls*)
      echo "cmark-gfm-root: ok a root with neither shape is refused, naming both" ;;
    *) echo "cmark-gfm-root: FAIL the refusal does not name both shapes: $out" >&2
       fail=1 ;;
  esac
fi

exit $fail
