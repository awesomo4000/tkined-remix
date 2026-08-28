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

if [ -z "$TCLTK_PREFIX" ]; then
    for _c in \
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
