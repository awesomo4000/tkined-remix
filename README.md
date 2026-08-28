# tkined-remix

A modernization of **scotty** (Tnm + Tkined), the Tcl/Tk network-management
suite by Juergen Schoenwaelder, TU Braunschweig and the University of Twente.

Forked from [flightaware/scotty](https://github.com/flightaware/scotty).
Upstream's own README is preserved as [README.upstream.md](README.upstream.md).

## Status

Builds and runs on macOS (Apple Silicon) against Tcl/Tk 8.6.

## Quick start

    brew install tcl-tk@8      # macOS; any prefix with tclConfig.sh works
    ./tools/build.sh
    ./bin/scotty               # Tcl shell with Tnm preloaded
    ./bin/tkined               # network editor GUI

Build output goes to `build/` and is gitignored. Nothing is installed
outside the repository.

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
