#!/bin/sh
# Run the tkined-remix test suites against the built tree.
#
#   ./tools/test.sh            gate suites only (the merge gate)
#   ./tools/test.sh all        every suite, including advisory ones
#   ./tools/test.sh advisory   only the advisory + quarantined suites
#   ./tools/test.sh <name>...  named suites, e.g. ./tools/test.sh mib udp
#
# Exit status is non-zero if any GATE suite fails. Advisory suites are
# reported but never fail the run.
#
# Classification is based on measured behavior on macOS/arm64, not on
# guesswork. See specs/test-baseline.md.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/tools/tcl-env.sh"

BUILD="$ROOT/build"
SCOTTY="$ROOT/bin/scotty"
TESTDIR="$ROOT/tnm/tests"
TIMEOUT_SECS="${TIMEOUT_SECS:-120}"

# Suites that must pass. Purely local: no network, no privileges.
GATE_SUITES="job map syslog mib"

# Suites that pass here but depend on the host environment or network.
# Reported, never gating. Promote to GATE once observed stable in CI.
ADVISORY_SUITES="netdb udp snmp sunrpc dns ntp"

# Suites known to fail for a reason already tracked by a spec.
# icmp   -> spec 02 (needs SOCK_RAW / setuid root)
# l.smx  -> hardcodes the binary name "scotty3.1.0"; also needs an engine
QUARANTINED="icmp l.smx"

if [ ! -x "$SCOTTY" ] || [ ! -d "$BUILD/lib" ]; then
    echo "test: no build found. Run ./tools/build.sh first." >&2
    exit 1
fi

# GNU timeout is 'timeout' or 'gtimeout' depending on the platform.
if command -v timeout >/dev/null 2>&1; then TO=timeout
elif command -v gtimeout >/dev/null 2>&1; then TO=gtimeout
else TO=""; fi

run_suite() {
    name="$1"; kind="$2"
    file="$TESTDIR/$name.test"
    if [ ! -f "$file" ]; then
        printf '  %-10s SKIP (no such suite)\n' "$name"; return 0
    fi
    if [ -n "$TO" ]; then
        out=$(cd "$TESTDIR" && $TO "$TIMEOUT_SECS" "$SCOTTY" "$name.test" </dev/null 2>&1)
    else
        out=$(cd "$TESTDIR" && "$SCOTTY" "$name.test" </dev/null 2>&1)
    fi
    rc=$?
    line=$(printf '%s\n' "$out" | grep -E "^$name\.test:.*Total" | tail -1)

    if [ "$rc" -eq 124 ] || [ "$rc" -eq 143 ]; then
        printf '  %-10s TIMEOUT after %ss\n' "$name" "$TIMEOUT_SECS"
        printf '%s\n' "$out" > "$BUILD/test-$name.log"
        return 1
    fi
    if [ -z "$line" ]; then
        printf '  %-10s ERROR (no summary; see build/test-%s.log)\n' "$name" "$name"
        printf '%s\n' "$out" > "$BUILD/test-$name.log"
        return 1
    fi
    failed=$(printf '%s\n' "$line" | sed -n 's/.*Failed[[:space:]]*\([0-9]*\).*/\1/p')
    stats=$(printf '%s\n' "$line" | sed "s/^$name\.test:[[:space:]]*//")
    if [ "${failed:-0}" -ne 0 ]; then
        printf '%s\n' "$out" > "$BUILD/test-$name.log"
        printf '  %-10s FAIL  %s  (build/test-%s.log)\n' "$name" "$stats" "$name"
        return 1
    fi
    printf '  %-10s ok    %s\n' "$name" "$stats"
    return 0
}

mkdir -p "$BUILD"
mode="${1:-gate}"
rc_total=0

case "$mode" in
    gate)     gate="$GATE_SUITES"; advisory="" ;;
    all)      gate="$GATE_SUITES"; advisory="$ADVISORY_SUITES $QUARANTINED" ;;
    advisory) gate=""; advisory="$ADVISORY_SUITES $QUARANTINED" ;;
    *)    gate="$*"; advisory="" ;;
esac

if [ -n "$gate" ]; then
    echo "== gate suites =="
    for s in $gate; do run_suite "$s" gate || rc_total=1; done
fi

if [ -n "$advisory" ]; then
    echo "== advisory suites (never gate) =="
    for s in $advisory; do run_suite "$s" advisory || true; done
fi

if [ "$mode" = "advisory" ]; then
    if [ "$rc_total" -eq 0 ]; then echo "PASS (advisory)"; fi
    exit 0
fi

echo "== tkined smoke =="
if "$ROOT/tests/tkined-smoke.sh"; then
    echo "  tkined     ok    packages load, editor constructs"
else
    echo "  tkined     FAIL"; rc_total=1
fi

echo "== relocation =="
if "$ROOT/tests/relocation.sh"; then
    echo "  relocate   ok    built tree runs from a different path"
else
    echo "  relocate   FAIL"; rc_total=1
fi

if [ "$rc_total" -eq 0 ]; then echo "PASS"; else echo "FAIL"; fi
exit "$rc_total"
