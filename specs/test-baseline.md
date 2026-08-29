# Test baseline

Measured on macOS 26.5 / arm64, Tcl 8.6.18, against commit-time `main`.
Regenerate with `./tools/test.sh all`.

## Classification

Suites are classified by **measured** behavior, not by what their names
suggest. `netdb` in particular looked like a safe offline suite and was not.

### Gate — must pass, purely local

| Suite | Result |
|---|---|
| `job` | 32 passed, 0 failed |
| `map` | 21 passed, 0 failed |
| `syslog` | 8 passed, 0 failed |
| `mib` | 296 passed, 24 skipped, 0 failed |

### Advisory — environment- or network-dependent

| Suite | Result | Note |
|---|---|---|
| `netdb` | 57 passed, 0 failed | reads local databases; promotion to gate pending CI observation |
| `udp` | 32 passed, 0 failed | loopback |
| `snmp` | 68 passed, 14 skipped, 0 failed | loopback agent |
| `sunrpc` | 29 passed, 16 skipped, 0 failed | local RPC services |
| `dns` | 15 passed, 11 skipped, 0 failed | needs a resolver |
| `ntp` | 10 passed, 1 skipped, 0 failed | needs a reachable NTP server |
| `icmp` | 41 passed, 2 skipped, 0 failed | 2 skips are `mask` and `timestamp`, which need a raw socket |

Promote to gate once observed stable on CI runners.

### Quarantined — failing for a reason already tracked

| Suite | Result | Tracked by |
|---|---|---|
| `l.smx` | 19 passed, **27 failed** | SMX engine lifecycle; see below |

## Fixed while establishing this baseline

**`knownBug64BitArchitecture` was broken on Apple Silicon.** It was defined
in `mib.test`, `netdb.test` and `snmp.test` as:

    !(machine == "amd64" || machine == "x86_64")

`tcl_platform(machine)` is `arm64` here, so the guard evaluated true and
the known-buggy tests **ran** instead of being skipped. Replaced with a
pointer-size check, which is architecture-agnostic:

    [expr {$::tcl_platform(pointerSize) != 8}]

Effect: `mib` 2 failures -> 0, `snmp` 4 failures -> 0, and `netdb` went
from hanging to passing.

## Fixed: the netdb hang (LP64 bug in `netdb ip range`)

The clearest example of the 64-bit class of bug this project inherits.
**Now fixed** in `tnm/generic/tnmNetdb.c`; `netdb-6.6` and `netdb-6.7` are
no longer skipped and pass.

`netdb ip range` in `tnm/generic/tnmNetdb.c`:

    unsigned long net, mask;           /* 64-bit on LP64 */
    struct in_addr ipaddr;             /* s_addr is uint32_t */
    for (ipaddr.s_addr = net + 1;
         ipaddr.s_addr < net + ~mask; ipaddr.s_addr++)

For a /30, `mask` is `0xFFFFFFFC`. On a 64-bit `unsigned long`, `~mask`
is `0xFFFFFFFF00000003`, so the loop bound is about 1.8e19. The 32-bit
`s_addr` wraps at 2^32 and never reaches it, so the loop appends
addresses forever. Observed: 98.5% CPU, RSS climbing past 2.2 GB.

On a 32-bit `unsigned long`, `~mask` is `3` and the loop is correct.
This is precisely why upstream documented that scotty "only operates
correctly on 32 bit platforms".

The fix computes the range in 32-bit arithmetic. Verified across mask
sizes: /16 -> 65534, /24 -> 254, /29 -> 6, /30 -> 2, /32 -> empty.

## Fixed: netdb-2.7 assumed every alias resolves forward

The test walked host aliases and required each to resolve back to the same
address. On macOS the resolver returns `1.0.0.127.in-addr.arpa`, the PTR
name, as an alias of 127.0.0.1, and that has no A record.

Checked against `gethostbyaddr(3)` directly: the C library returns exactly
that alias, so **Tnm is correct** and the test's assumption was wrong. The
test now skips aliases that do not resolve forward, which preserves what
it was actually verifying.

## Still open: l.smx

Was failing outright because it hardcoded the binary name `scotty3.1.0`.
It now uses `[info nameofexecutable]` and runs: 19 passed, 27 failed.

The remaining failures are an engine lifecycle problem. The suite starts a
listener, launches an engine as a subprocess, and the engine does connect
(verified: it accepts from `::1`). The engine script then ends, `scotty`
exits at EOF, and the suite reports `smx peer gone away` on the next
command. Adding `vwait forever` to keep the engine alive was tried and is
**not** the fix: it hangs the whole suite.

Script MIB is not on the roadmap, so this stays quarantined rather than
absorbing more time. Anyone picking it up should start at `startengine`
in `tnm/tests/l.smx.test`.

## Notes for anyone debugging these

- macOS Aqua `wish` **discards stdout**. Use stderr or a file.
- Do not diagnose a hang through a pipe to `head`/`tail`: stdio block
  buffering hides where it stopped. Redirect to a file and flush.
- When sampling a hung process, sample the actual child, not the
  `timeout`/`gtimeout` wrapper.
- Do not rely on `timeout(1)`: macOS does not ship it, and it is only
  present locally via Homebrew coreutils. `tools/test.sh` uses its own
  portable watchdog, because depending on coreutils silently disabled
  every per-suite limit on CI.
