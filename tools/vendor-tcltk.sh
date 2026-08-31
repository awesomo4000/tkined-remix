#!/bin/sh
# Fetch, verify and build a pinned Tcl/Tk into vendor/prefix-<version>.
#
#   ./tools/vendor-tcltk.sh              # the default version
#   TCLTK_VERSION=9.0.4 ./tools/vendor-tcltk.sh
#
# Why pinned tarballs rather than a submodule or a committed source dump:
# the repository stays small, the exact bytes are verified by checksum, and
# Tcl's canonical version control is Fossil, so the git mirrors would be a
# second-hand source. The cost is needing the network once; after that the
# cache makes builds offline.
#
# Checksums come from the Homebrew formulae for tcl-tk and tcl-tk@8, which
# are independently maintained. They are deliberately NOT computed from our
# own download: a self-computed hash verifies nothing, and the first version
# of this script "verified" a truncated release candidate that way.
#
# Set TCLTK_TARBALL_DIR to a directory holding the source tarballs to build
# with no network at all.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor"
CACHE="${TCLTK_TARBALL_DIR:-$VENDOR/cache}"
SRC="$VENDOR/src"
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)}"

VERSION="${TCLTK_VERSION:-8.6.18}"
PREFIX="$VENDOR/prefix-$VERSION"

case "$VERSION" in
  8.6.18)
    TCL_SHA256=14f9af32b1767ff718477a8f974ad03c34341097e6b43f4ce54644ee974e268e
    TK_SHA256=95cd528a80f5e4bdb557af9b14a7197d6860793a3894e25e7c9fad2ed05d4c3c
    ;;
  9.0.4)
    TCL_SHA256=d0aed49230bc02a65c1e0229e65f34590a4b037ec40d546f32573b467f7551ea
    TK_SHA256=d7a146d2917eb8b5cc95276dbf0e3d03c7464d2b19c1675357857c989301dbb4
    ;;
  *)
    echo "vendor: no pinned checksums for Tcl/Tk $VERSION" >&2
    echo "  add them from an independent source before building it" >&2
    exit 1
    ;;
esac

BASE_URL="https://downloads.sourceforge.net/project/tcl/Tcl/$VERSION"
STAMP="$PREFIX/.built-$VERSION"

if [ -f "$STAMP" ]; then
    echo "vendor: Tcl/Tk $VERSION already built in $PREFIX"
    exit 0
fi

sha256_of() {
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    else echo "vendor: no sha256 tool available" >&2; exit 1; fi
}

fetch_and_verify() {
    pkg="$1"; want="$2"
    tarball="$CACHE/${pkg}${VERSION}-src.tar.gz"
    if [ ! -f "$tarball" ]; then
        if [ -n "$TCLTK_TARBALL_DIR" ]; then
            echo "vendor: $tarball not found in TCLTK_TARBALL_DIR" >&2
            exit 1
        fi
        mkdir -p "$CACHE"
        echo "vendor: fetching $pkg $VERSION"
        # --retry-all-errors matters: the mirror truncates transfers
        # intermittently, and a short read otherwise lands in the cache.
        curl -fL --retry 5 --retry-all-errors --max-time 900 \
             -o "$tarball.part" "$BASE_URL/${pkg}${VERSION}-src.tar.gz" >/dev/null 2>&1
        mv "$tarball.part" "$tarball"
    fi
    # Check the archive is whole before trusting the hash, so a truncated
    # download reports the real problem rather than a checksum mismatch.
    if ! tar tzf "$tarball" >/dev/null 2>&1; then
        echo "vendor: $pkg archive is corrupt or truncated; removing" >&2
        rm -f "$tarball"
        exit 1
    fi
    got="$(sha256_of "$tarball")"
    if [ "$got" != "$want" ]; then
        echo "vendor: checksum mismatch for $pkg $VERSION" >&2
        echo "  expected $want" >&2
        echo "  got      $got" >&2
        echo "  refusing to build; delete $tarball to re-fetch" >&2
        exit 1
    fi
}

extract() {
    pkg="$1"
    dir="$SRC/${pkg}${VERSION}"
    [ -d "$dir" ] && return 0
    mkdir -p "$SRC"
    echo "vendor: extracting $pkg $VERSION"
    tar xzf "$CACHE/${pkg}${VERSION}-src.tar.gz" -C "$SRC"
}

fetch_and_verify tcl "$TCL_SHA256"
fetch_and_verify tk  "$TK_SHA256"
extract tcl
extract tk

mkdir -p "$PREFIX"

# Shared, not static. Static linking belongs with the Zig build, where it
# buys a single distributable binary rather than just a different link mode.
echo "vendor: building Tcl $VERSION"
( cd "$SRC/tcl$VERSION/unix" \
  && ./configure --prefix="$PREFIX" --enable-threads --enable-shared \
  && make -j"$JOBS" && make install ) > "$VENDOR/build-tcl-$VERSION.log" 2>&1

echo "vendor: building Tk $VERSION"
( cd "$SRC/tk$VERSION/unix" \
  && ./configure --prefix="$PREFIX" --with-tcl="$PREFIX/lib" \
       --enable-threads --enable-shared --enable-aqua \
  && make -j"$JOBS" && make install ) > "$VENDOR/build-tk-$VERSION.log" 2>&1

touch "$STAMP"
echo "vendor: Tcl/Tk $VERSION installed into $PREFIX"
