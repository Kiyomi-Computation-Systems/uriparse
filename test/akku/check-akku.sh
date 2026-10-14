#!/bin/sh
# check-akku: install this package with Akku the way a consumer would, and
# check what lands on the consumer's library path.
#
# A consumer project is made in a temporary directory. Its Akku.lock points
# each package at a directory that holds only the files git tracks, which is
# what Akku's archive builds a package from: this checkout's tracked files,
# and, for each dependency Akku.manifest names, the tracked files of the copy
# vendored at vendor/<name>. Tracked files are copied from the working tree,
# so uncommitted edits to them are what gets tested; a file git does not track
# yet is left out, as the archive would leave it out. Before installing:
#
#   0. the package the archive would build must leave out the repository's
#      process records (.plans/, .superpowers/, AGENTS.md) and still hold the
#      libraries. Akku's archive builds a package the way `git archive` does,
#      leaving out every path .gitattributes marks export-ignore: byte-machine
#      0.8.0's package lacks exactly its export-ignored .plans, .decisions and
#      AGENTS.md. So git archive itself answers, at HEAD, with this tree's
#      .gitattributes. Everything the package unpacks lands in a consumer's
#      .akku/src/, not only its libraries.
#
# After `akku install`:
#
#   1. this package's libraries in .akku/list must be exactly the .sls files
#      git tracks under src/. A test, site or tool library would land on
#      every consumer's library path, and a missing one would fail at import.
#      The docs site generator's (site ...) libraries, tracked under site/,
#      are named first: .akkuignore must list site. Apart from its libraries
#      the package may install its legal notices and nothing else.
#   2. every dependency must have installed at least one library.
#   3. test/akku/consumer.sps, run with only the library path that
#      .akku/bin/activate sets, must read a URI through both layers.
#
# Needs akku, chez and git on PATH; AKKU and CHEZ override the first two.
set -eu

AKKU=${AKKU:-akku}
CHEZ=${CHEZ:-chez}
root=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/check-akku.XXXXXX")
trap 'rm -rf "$work"' EXIT

fail() { echo "check-akku: $*" >&2; exit 1; }

# copy_tracked SRC DEST: the files git tracks in SRC, as they are on disk.
# --no-recursion keeps a submodule's directory empty, as it is in an archive.
# GNU tar applies it only to the names after it, so it comes before -T. A
# pipeline's status is its last command's, so the list and the archive go
# through files in $work instead: under set -e, a failing git or tar fails
# the script.
copy_tracked() {
  mkdir -p "$2"
  (cd "$1" && git ls-files -z) > "$work/tracked"
  (cd "$1" && tar --null --no-recursion -T - -cf -) < "$work/tracked" > "$work/tracked.tar"
  (cd "$2" && tar -xf -) < "$work/tracked.tar"
}

# 0. What the archive would ship.
(cd "$root" && git archive --worktree-attributes --format=tar HEAD) > "$work/archive.tar"
tar -tf "$work/archive.tar" > "$work/archive.txt"
awk -F/ '{ print $1 }' "$work/archive.txt" | sort -u > "$work/archive-top.txt"
for record in .plans .superpowers AGENTS.md; do
  if grep -qxF "$record" "$work/archive-top.txt"; then
    fail "the package would ship $record; .gitattributes must mark it export-ignore"
  fi
done
grep -qxF src/uri/easy.sls "$work/archive.txt" ||
  fail "git archive holds no src/uri/easy.sls, so it cannot be what the package is built from"

# The package's name and version, then one dependency name per line.
cat > "$work/manifest.ss" <<'EOF'
(with-input-from-file "Akku.manifest"
  (lambda ()
    (let loop ()
      (let ((d (read)))
        (cond ((eof-object? d) (error 'check-akku "no akku-package form"))
              ((and (pair? d) (eq? (car d) 'akku-package))
               (display (car (cadr d))) (display " ")
               (display (cadr (cadr d))) (newline)
               (for-each (lambda (dep) (display (car dep)) (newline))
                         (cond ((assq 'depends (cddr d)) => cdr)
                               (else '()))))
              (else (loop)))))))
EOF
manifest=$(cd "$root" && "$CHEZ" -q --script "$work/manifest.ss")
package=$(echo "$manifest" | sed -n '1s/ .*//p')
version=$(echo "$manifest" | sed -n '1s/.* //p')
depends=$(echo "$manifest" | sed '1d')

copy_tracked "$root" "$work/pkg/$package"
lock="((name \"$package\") (location (directory \"$work/pkg/$package\")))"
for dep in $depends; do
  [ -f "$root/vendor/$dep/.git" ] || [ -d "$root/vendor/$dep/.git" ] ||
    fail "dependency $dep is not vendored at vendor/$dep (git submodule update --init?)"
  sub="$work/pkg/$package/vendor/$dep"
  [ -d "$sub" ] && [ -z "$(ls -A "$sub")" ] ||
    fail "vendor/$dep in the copy of $package is not an empty directory, as git tracks a submodule"
  copy_tracked "$root/vendor/$dep" "$work/pkg/$dep"
  lock="$lock ((name \"$dep\") (location (directory \"$work/pkg/$dep\")))"
done

mkdir "$work/consumer"
cd "$work/consumer"
cat > Akku.manifest <<EOF
#!r6rs
(import (akku format manifest))
(akku-package ("check-akku-consumer" "0.0.0")
  (synopsis "check-akku's consumer") (authors "check-akku") (license "MIT")
  (depends ("$package" "^$version")))
EOF
cat > Akku.lock <<EOF
#!r6rs
(import (akku format lockfile))
(projects $lock)
EOF

echo "check-akku: installing $package $version and its dependencies: $depends"
"$AKKU" install > install.log 2>&1 || { cat install.log >&2; fail "akku install failed"; }

# 1. This package's libraries are exactly src/.
awk -F '\t' -v p="$package" '$2 == p && $3 == "r6rs-library" { sub("^\\.akku/lib/", "", $1); print $1 }' \
  .akku/list | sort > installed.txt
site=$(grep '^site/' installed.txt | tr '\n' ' ' || true)
[ -z "$site" ] ||
  fail "$package installs the docs site generator's libraries ($site): .akkuignore must list site"
(cd "$root" && git ls-files -- 'src/*.sls' | sed 's#^src/##' | sort) > expected.txt
diff -u expected.txt installed.txt > libraries.diff ||
  { cat libraries.diff >&2; fail "$package installs a different set of libraries than src/ (- missing, + extra)"; }
# ...and nothing else but its notices: a program would land in .akku/bin.
other=$(awk -F '\t' -v p="$package" '$2 == p && $3 != "r6rs-library" && $3 != "legal-notice-file" { print $1 " (" $3 ")" }' .akku/list)
[ -z "$other" ] || fail "$package installs more than libraries and notices: $other"

# 2. Each dependency installed something.
for dep in $depends; do
  awk -F '\t' -v p="$dep" '$2 == p && $3 == "r6rs-library"' .akku/list | grep -q . ||
    fail "dependency $dep installed no library"
done

# 3. A consumer reads a URI with only Akku's library path.
cp "$root/test/akku/consumer.sps" consumer.sps
out=$(env -u CHEZSCHEMELIBDIRS R6RS_PATH= R7RS_PATH= LD_LIBRARY_PATH= DYLD_LIBRARY_PATH= \
        sh -c '. .akku/bin/activate && exec "$0" --program consumer.sps' "$CHEZ") ||
  fail "consumer.sps failed with Akku's library path"
[ "$out" = "example.com /b" ] ||
  fail "consumer.sps printed '$out', not 'example.com /b'"

echo "check-akku: $(wc -l < installed.txt | tr -d ' ') libraries from src/, and a consumer read a URI through both layers"
