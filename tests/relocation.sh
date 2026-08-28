#!/bin/sh
# Copy the built tree to a different path and prove it still runs.
# This is what catches machine-specific and build-location assumptions;
# CI alone would not, since CI always builds at its own fixed path.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Strip any trailing slash: macOS TMPDIR ends in one, which would make
# mktemp produce a double slash and break prefix comparison below.
tmpbase="${TMPDIR:-/tmp}"
tmpbase="${tmpbase%/}"

TMP="$(mktemp -d "$tmpbase/tkined-reloc.XXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT

(cd "$ROOT" && tar cf - --exclude .git bin tools build) | (cd "$TMP" && tar xf -) || exit 1

cat > "$TMP/probe.tcl" <<'EOF'
package require Tnm
puts $tnm(library)
EOF

got=$("$TMP/bin/scotty" "$TMP/probe.tcl" </dev/null 2>&1) || {
    echo "    relocated scotty failed to run: $got" >&2; exit 1; }

# Normalize both sides: /var vs /private/var is a symlink on macOS.
[ -d "$got" ] || { echo "    not a directory: $got" >&2; exit 1; }
gotn=$(cd "$got" && pwd -P)
tmpn=$(cd "$TMP" && pwd -P)
rootn=$(cd "$ROOT" && pwd -P)

case "$gotn" in
    "$tmpn"/*) ;;
    *) echo "    library resolved outside the copy: $gotn (expected under $tmpn)" >&2; exit 1 ;;
esac
case "$gotn" in
    "$rootn"/*) echo "    library still points at the original tree: $gotn" >&2; exit 1 ;;
esac
exit 0
