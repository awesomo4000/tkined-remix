# tkined-remix

A modernization of **scotty** (Tnm + Tkined), the Tcl/Tk network-management
suite by Juergen Schoenwaelder, TU Braunschweig and the University of Twente.

Forked from [flightaware/scotty](https://github.com/flightaware/scotty).
Upstream's own README is preserved as [README.upstream.md](README.upstream.md).

## Status

Builds and runs on macOS (Apple Silicon) against Tcl/Tk 8.6.

## Quick start

    brew install tcl-tk@8 autoconf    # autoconf generates configure, which is not committed
    ./tools/build.sh

Build output goes to `build/` and is gitignored. Nothing is installed
outside the repository.

## Running it

### The network editor

    ./bin/tkined

Opens the Tkined map editor. To draw a network: use the toolbar to place
nodes and networks on the canvas, select them, then drive them from the
**Tools** menu, which loads the bundled applications.

Useful things to try, all from the Tools menu with objects selected:

- **IP-Monitor** — reachability and round-trip times.
- **IP-Discover** — walk a subnet and place what it finds on the map.
- **SNMP-Browser** — browse the MIB tree of an SNMP-capable device.
- **SNMP-Monitor** — graph SNMP values over time as stripcharts.

Note: anything using ICMP (ping, traceroute) currently fails unless
`build/bin/nmicmpd` is setuid root. See **Known limitations**. SNMP, DNS
and Sun RPC tools work as an unprivileged user.

Open a saved map directly:

    ./bin/tkined mymap.tki

### The shell

`./bin/scotty` is `tclsh` with Tnm preloaded — the quickest way to explore:

    $ ./bin/scotty
    % package require Tnm
    3.1.3
    % namespace import Tnm::*

    # resolve names and OIDs from the compiled-in MIBs
    % mib oid sysDescr
    1.3.6.1.2.1.1.1
    % mib name 1.3.6.1.2.1.1.5.0
    SNMPv2-MIB::sysName.0
    % mib syntax sysUpTime
    TimeTicks

    # DNS
    % dns address localhost
    127.0.0.1

    # query a real device (needs a reachable SNMP agent)
    % set s [snmp session -address 192.0.2.1 -community public]
    % $s get sysDescr.0

Run a script instead of interactively:

    ./bin/scotty myscript.tcl

The 28 bundled applications in `tkined/apps/` are ordinary Tcl programs
and are worth reading as examples.

## Seeing it with real data

    ./tools/local-map.sh            # build a map, write .tki + PNG
    SHOT=1 ./tools/local-map.sh     # also open the editor and capture it

Builds a Tkined map of the local network from passive sources only: the
routing table, interface config, the ARP cache and DNS. No ICMP and no
root, so it works today. Output lands in `build/`:

- `local-network.tki` -- open it with `./bin/tkined build/local-network.tki`
- `local-network.png` -- offscreen PostScript render (no icons; see below)
- `tkined-window.png` -- the real editor window, with `SHOT=1`

Note that the offscreen render omits icons: Tk on Aqua cannot emit canvas
bitmap items to PostScript. See `specs/08-ui-modernization.md`.

## Portability

## Seeing it with real data

    ./tools/local-map.sh            # build a map, write .tki + PNG
    SHOT=1 ./tools/local-map.sh     # also open the editor and capture it

Builds a Tkined map of the local network from passive sources only: the
routing table, interface config, the ARP cache and DNS. No ICMP and no
root, so it works today. Output lands in `build/`:

- `local-network.tki` -- open it with `./bin/tkined build/local-network.tki`
- `local-network.png` -- offscreen PostScript render (no icons; see below)
- `tkined-window.png` -- the real editor window, with `SHOT=1`

Note that the offscreen render omits icons: Tk on Aqua cannot emit canvas
bitmap items to PostScript. See `specs/08-ui-modernization.md`.

## Portability

No machine-specific paths are committed:

- `tools/tcl-env.sh` discovers Tcl/Tk (override with `TCLTK_PREFIX`).
- `tools/build.sh` derives the install prefix from the repo location.
- `bin/*` export `TNM_LIBRARY` / `TKINED_LIBRARY`, which override the paths
  baked in at compile time, so a built tree can be moved and still run.

## Toolchain notes

Two incompatibilities between 1990s C and a current toolchain are handled
in `tools/build.sh` rather than by editing sources:

1. autoconf >= 2.72 enables C23, which removed K&R function definitions.
   Suppressed with `ac_cv_prog_cc_c23=no`.
2. Some K&R parameters rely on implicit-int (for example `restKind` in
   `tnm/snmp/tnmMibFrozen.c`, declared in the parameter list but never
   given a type). Restored with `-Wno-` flags.

Also note: `make distclean` deletes the autoheader-generated `config.h.in`;
`tools/build.sh` regenerates it.

## Known limitations

- ICMP requires `nmicmpd` to be setuid root, because it opens a `SOCK_RAW`
  socket. This is not an OS limitation: macOS supports unprivileged ICMP via
  `SOCK_DGRAM`/`IPPROTO_ICMP`, and the system `ping` is not setuid. Fixing
  this is planned work.
- Upstream documents macOS bugs in `dns -server`, `icmp` to unreachable
  hosts, and `mib format BinaryValue` on 64-bit.
- macOS Aqua `wish` discards stdout; use stderr or a file when debugging.

## Roadmap

See [specs/tkined-remix-vision.md](specs/tkined-remix-vision.md).
