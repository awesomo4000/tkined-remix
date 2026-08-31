#!/bin/sh
# Resolve a Tcl/Tk installation without hardcoding machine-specific paths.
#
# Override by exporting TCLTK_PREFIX to a prefix containing
# lib/tclConfig.sh and lib/tkConfig.sh. Otherwise we probe Homebrew,
# then a few conventional locations.
#
# Exports: TCLTK_PREFIX TCL_CONFIG_DIR TCLSH_BIN WISH_BIN

_probe() {
    [ -n "$1" ] && [ -f "$1/lib/tclConfig.sh" ] && [ -f "$1/lib/tkConfig.sh" ]
}

# The vendored tree is preferred over anything on the system, so a build
# does not depend on what happens to be installed. Callers set ROOT before
# sourcing this; fall back to deriving it if they did not.
if [ -z "$ROOT" ]; then
    _here="$(cd "$(dirname "${BASH_SOURCE:-$0}")" 2>/dev/null && pwd)"
    ROOT="$(cd "$_here/.." 2>/dev/null && pwd)"
fi

# TCLTK_VERSION selects which vendored build to use. It defaults to 8.6.18
# so the supported configuration stays the default; set it to 9.0.4 to
# build against Tcl/Tk 9.
_want="${TCLTK_VERSION:-8.6.18}"

# If a version was asked for explicitly, it is an error not to have it.
# Falling through to whatever else is lying around would silently build
# against a different Tcl than the one requested, which is worse than
# stopping.
if [ -n "$TCLTK_VERSION" ] && [ -z "$TCLTK_PREFIX" ]; then
    if [ ! -f "$ROOT/vendor/prefix-$TCLTK_VERSION/lib/tclConfig.sh" ]; then
        echo "tcl-env: Tcl/Tk $TCLTK_VERSION is not built." >&2
        echo "  build it:  TCLTK_VERSION=$TCLTK_VERSION ./tools/vendor-tcltk.sh" >&2
        return 1 2>/dev/null || exit 1
    fi
fi

if [ -z "$TCLTK_PREFIX" ]; then
    for _c in \
        "$ROOT/vendor/prefix-$_want" \
        "$ROOT/vendor/prefix" \
        "$(command -v brew >/dev/null 2>&1 && brew --prefix tcl-tk@8 2>/dev/null)" \
        /opt/homebrew/opt/tcl-tk@8 \
        /usr/local/opt/tcl-tk@8 \
        /usr/local \
        /usr
    do
        if _probe "$_c"; then TCLTK_PREFIX="$_c"; break; fi
    done
fi

if ! _probe "$TCLTK_PREFIX"; then
    echo "tcl-env: no Tcl/Tk with tclConfig.sh + tkConfig.sh found." >&2
    echo "  Install one (macOS:  brew install tcl-tk@8)" >&2
    echo "  or export TCLTK_PREFIX=/path/to/prefix" >&2
    return 1 2>/dev/null || exit 1
fi

TCL_CONFIG_DIR="$TCLTK_PREFIX/lib"
for _v in 8.6 9.0 ""; do
    [ -x "$TCLTK_PREFIX/bin/tclsh$_v" ] && TCLSH_BIN="$TCLTK_PREFIX/bin/tclsh$_v" && break
done
for _v in 8.6 9.0 ""; do
    [ -x "$TCLTK_PREFIX/bin/wish$_v" ] && WISH_BIN="$TCLTK_PREFIX/bin/wish$_v" && break
done

export TCLTK_PREFIX TCL_CONFIG_DIR TCLSH_BIN WISH_BIN
