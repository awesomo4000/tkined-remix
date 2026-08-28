#!/bin/sh
# Headless wrapper for the Tkined smoke test.
# Skips (exit 0) if Tk cannot reach a display, which is normal on
# headless CI runners; a genuine load or construction failure exits 1.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tools/tcl-env.sh"
BUILD="$ROOT/build"

TNM_LIBRARY="$(echo "$BUILD"/lib/Tnm*)";       export TNM_LIBRARY
TKINED_LIBRARY="$(echo "$BUILD"/lib/Tkined*)"; export TKINED_LIBRARY
TCLLIBPATH="$BUILD/lib";                       export TCLLIBPATH
TKI_SMOKE_OUT="$BUILD/tkined-smoke.txt";       export TKI_SMOKE_OUT
rm -f "$TKI_SMOKE_OUT"

"$WISH_BIN" "$ROOT/tests/tkined-smoke.tcl" </dev/null >/dev/null 2>"$BUILD/tkined-smoke.err"
rc=$?

if [ ! -f "$TKI_SMOKE_OUT" ]; then
    if grep -qiE 'display|screen|connect' "$BUILD/tkined-smoke.err" 2>/dev/null; then
        echo "    (skipped: no display available)" >&2
        exit 0
    fi
    echo "    (no result file; see build/tkined-smoke.err)" >&2
    exit 1
fi
grep -q '^FAIL' "$TKI_SMOKE_OUT" && { cat "$TKI_SMOKE_OUT" >&2; exit 1; }
exit $rc
