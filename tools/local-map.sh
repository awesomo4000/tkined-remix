#!/bin/sh
# Build a Tkined map of the local network and render it offscreen.
# Passive sources only: routing table, interfaces, ARP cache, DNS.
# No ICMP, no root, and no window is ever mapped.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tools/tcl-env.sh"
BUILD="$ROOT/build"

TNM_LIBRARY="$(echo "$BUILD"/lib/Tnm*)";       export TNM_LIBRARY
TKINED_LIBRARY="$(echo "$BUILD"/lib/Tkined*)"; export TKINED_LIBRARY
TCLLIBPATH="$BUILD/lib";                       export TCLLIBPATH

MAP_OUT="${1:-$BUILD/local-network.tki}";      export MAP_OUT
MAP_PS="$BUILD/local-network.ps";              export MAP_PS
MAP_LOG="$BUILD/local-map.log";                export MAP_LOG

# SHOT=1 additionally opens the editor and captures its window
[ -n "$SHOT" ] && { SHOT_OUT="$BUILD/tkined-window.png"; export SHOT_OUT; }

"$WISH_BIN" "$ROOT/tools/local-map.tcl" </dev/null >/dev/null 2>"$BUILD/local-map.err"
rc=$?
[ -s "$BUILD/local-map.err" ] && { echo "stderr:"; cat "$BUILD/local-map.err"; }
[ -f "$MAP_LOG" ] && cat "$MAP_LOG"

if [ -f "$MAP_PS" ] && command -v gs >/dev/null 2>&1; then
    png="${MAP_PS%.ps}.png"
    gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=png16m -r150 \
       -dEPSCrop -sOutputFile="$png" "$MAP_PS" >/dev/null 2>&1
    # the map is drawn landscape, so rotate the raster upright and trim
    if [ -f "$png" ] && command -v magick >/dev/null 2>&1; then
        magick "$png" -rotate 90 -bordercolor white -border 20 -trim \
               -bordercolor white -border 30 "$png" 2>/dev/null
    fi
    [ -f "$png" ] && echo "rendered $png"
fi
exit $rc
