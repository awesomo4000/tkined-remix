#!/bin/sh
# Build Tnm + Tkined into $REPO/build. No machine-specific paths:
# the Tcl/Tk prefix is discovered, and the install prefix is derived
# from this script's location.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Build the vendored Tcl/Tk if it is not already there. The script is
# idempotent and returns immediately once the prefix exists, so this costs
# nothing on a warm tree. Set TCLTK_PREFIX to build against a system copy
# instead and this is skipped.
if [ -z "$TCLTK_PREFIX" ] && [ ! -d "$ROOT/vendor/prefix" ]; then
    "$ROOT/tools/vendor-tcltk.sh"
fi

. "$ROOT/tools/tcl-env.sh"

BUILD="$ROOT/build"
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)}"

# This is 1990s C. Two toolchain incompatibilities must be neutralised:
#  1. autoconf >= 2.72 enables C23, which deleted K&R function definitions.
#  2. Some K&R parameters rely on implicit-int, an error in modern clang.
COMPAT="-Wno-implicit-int -Wno-implicit-function-declaration \
-Wno-deprecated-non-prototype -Wno-int-conversion \
-Wno-incompatible-pointer-types -Wno-return-type"

conf_common="--prefix=$BUILD --exec-prefix=$BUILD --bindir=$BUILD/bin --libdir=$BUILD/lib"

build_one() {
    dir="$1"; shift
    echo "==> $dir"
    cd "$ROOT/$dir"
    # autoheader must run before configure; `make distclean` removes config.h.in
    [ -f configure ] || autoconf
    [ -f config.h.in ] || autoheader
    ./configure $conf_common "$@" \
        CC="${CC:-clang}" ac_cv_prog_cc_c23=no CFLAGS="-g -O2 $COMPAT" >"$BUILD/$dir-configure.log" 2>&1
    make clean >/dev/null 2>&1 || true
    make -j"$JOBS" >"$BUILD/$dir-build.log" 2>&1
    cd "$ROOT"
}

mkdir -p "$BUILD"
build_one tnm    --with-tcl="$TCL_CONFIG_DIR"
( cd "$ROOT/tnm" && make scotty >>"$BUILD/tnm-build.log" 2>&1 )
( cd "$ROOT/tnm" && make install >"$BUILD/tnm-install.log" 2>&1 )

build_one tkined --with-tcl="$TCL_CONFIG_DIR" --with-tk="$TCL_CONFIG_DIR"
( cd "$ROOT/tkined" && make install >"$BUILD/tkined-install.log" 2>&1 )

echo "==> installed into $BUILD"
ls "$BUILD/bin" "$BUILD/lib"
