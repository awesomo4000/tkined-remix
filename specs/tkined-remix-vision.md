# tkined-remix — Vision

## What this is

**scotty** (Tnm + Tkined) is a Tcl/Tk network-management platform from
TU Braunschweig and the University of Twente, written mostly 1993-1998.
It provides SNMP v1/v2c/v2u with a real MIB compiler, ICMP, DNS, UDP,
NTP, Sun RPC and syslog as first-class Tcl commands, plus **Tkined**, a
network map editor that is extended by writing ordinary Tcl programs.

The engineering is good and the model has aged well. What rotted is the
toolchain around it: C23 removed the K&R syntax it is written in, Tcl 9
broke the C API, and the build assumes a 1990s Unix.

**tkined-remix** modernizes the platform without discarding it.

## Why bother

The interesting property of Tkined is its extension model. An "app" is a
standalone process that speaks a line protocol to the editor. Adding a
tool means writing a script, not recompiling a GUI. That decoupling is
what makes the distributed goal (below) reachable rather than a rewrite.

## End state

1. **Self-contained.** Tcl/Tk vendored in-tree. No Homebrew, no system Tcl.
2. **Modern toolchain.** Builds with Zig as a single cross-capable build,
   replacing autotools.
3. **Current Tcl/Tk.** Ported to the 9.x C API.
4. **Distributed.** The UI runs on a workstation; collectors run on
   registered remote agents reached over SSH.
5. **Presentable.** A Tk UI that does not look like 1995.

## Principles

- **Upstream stays recognizable.** Prefer build-level fixes over source
  edits; when sources must change, change them surgically. Keep the
  `upstream` remote and stay rebasable for as long as it is useful.
- **Every chunk has a gate.** A chunk is done when an automated check
  proves it, not when it looks right.
- **No machine-specific paths, ever.** Enforced by CI on a clean runner.
- **Incremental and revertible.** Each chunk is a branch and a PR.
- **Verify, do not assume.** Several "known limitations" inherited from
  upstream docs turned out to be wrong or misattributed on first contact.

## Verified architectural seams

These were confirmed by reading the source, and the plan depends on them:

- **`tnm/generic/tnmIned.c:204`** — an app connects to the editor over
  **TCP** when `TNM_INED_TCPPORT` is set, otherwise over stdin/stdout.
  The editor side sets it in `tkined/generic/tkiMethods.c:1170`.
  The protocol is line-buffered and the host is hardcoded to `localhost`.
  *This is the seam the distributed architecture uses.*
- **`unix/tnmUnixInit.c:181`** — `TNM_LIBRARY` / `TKINED_LIBRARY` override
  compile-time baked paths, which is what makes a built tree relocatable.
- **`unix/nmicmpd.c:1216`** — ICMP uses `SOCK_RAW`, hence the root
  requirement. Not an OS constraint; macOS allows unprivileged
  `SOCK_DGRAM`/`IPPROTO_ICMP`.
- **Apps are separate processes** (`tkined/apps/*.tcl`, 28 of them) that
  `package require Tnm` and call `ined`. They are not linked into the GUI.

## Sequence

    00 macOS build            [DONE]
     |
    01 test harness + CI      <- gate mechanism for everything after it
     |
     +-- 02 ICMP without root
     |
    03 vendor Tcl/Tk          <- removes the external dependency
     |
    04 Tcl/Tk 9 port          <- cheap once the version is pinned in-tree
     |
    05 Zig build system
     |
     +-- 06 distributed agents over SSH
     |
    07 UI modernization

**Why vendoring precedes the Tcl 9 port:** vendoring pins an exact
Tcl/Tk source in-tree. "Move to 9" then becomes choosing what to vendor
and fixing compile errors against a known, unchanging target, rather than
chasing a Homebrew version that can move underneath us. It also makes the
Zig build far simpler, since there is no external prefix to discover.

02 and 06/07 are independent of the toolchain line and can proceed in
parallel with it.

## Risks

| Risk | Mitigation |
|---|---|
| Tcl 9 port is larger than expected | 03 pins the target first; keep an 8.6 build green in CI until 9 passes |
| Zig cannot express some autotools probe | Keep autotools working in parallel; Zig must pass the same gate before autotools is retired |
| The `ined` protocol has no authentication | Never expose it on a socket; SSH transport only, bound to loopback |
| Upstream 64-bit bugs surface as we go | 01 gives us a suite; convert each into a failing test first |
| Tk UI work balloons | Treat 07 as opt-in theming over existing widgets, not a rewrite |

## Testing approach

The codebase already uses **`tcltest` 2** with 13 suites under
`tnm/tests/`. Tkined has none. Spec 01 builds on that rather than
introducing a new framework. Network-dependent tests are the main
difficulty and are handled there.
