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
| `netdb` | 54 passed, **1 failed** | `netdb-2.7` walks the local hosts database; outcome depends on `/etc/hosts` |
| `udp` | 32 passed, 0 failed | loopback |
| `snmp` | 68 passed, 14 skipped, 0 failed | loopback agent |
| `sunrpc` | 29 passed, 16 skipped, 0 failed | local RPC services |
| `dns` | 15 passed, 11 skipped, 0 failed | needs a resolver |
| `ntp` | 10 passed, 1 skipped, 0 failed | needs a reachable NTP server |

Promote to gate once observed stable on CI runners.

### Quarantined — failing for a reason already tracked

| Suite | Result | Tracked by |
|---|---|---|
| `icmp` | **15 failed** | spec 02 — `nmicmpd` needs `SOCK_RAW`, hence root |
| `l.smx` | error | hardcodes the binary name `scotty3.1.0`; ours is `scotty3.1.3`. Also needs a running SMX engine |

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

## Root cause of the netdb hang

Worth recording because it is the clearest example of the 64-bit class of
bug this project inherits, and it is not yet fixed — only skipped.

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

Fixing it belongs to spec 05 (C modernization). A test that currently
skips should be un-skipped as part of that fix.

## Notes for anyone debugging these

- macOS Aqua `wish` **discards stdout**. Use stderr or a file.
- Do not diagnose a hang through a pipe to `head`/`tail`: stdio block
  buffering hides where it stopped. Redirect to a file and flush.
- When sampling a hung process, sample the actual child, not the
  `timeout`/`gtimeout` wrapper.
