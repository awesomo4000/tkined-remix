# 03 — Vendor Tcl/Tk in-tree

**Depends on:** 01. **Blocks:** 04, and greatly simplifies 05.

## Goal

Build against a Tcl/Tk whose exact source lives in the repository.
Remove the Homebrew `tcl-tk@8` dependency.

## Why now

Currently the only system-wide dependency, and it is a moving target:
Homebrew can bump 8.6.x underneath us. Pinning the source first means the
Tcl 9 port (04) is done against something that does not change, and the
Zig build (05) has no external prefix to discover.

## Scope

1. **Choose the vendoring mechanism.** Prefer a git submodule or a
   pinned-tarball fetch with checksum over committing a full source dump.
   Decide explicitly and record why.
2. **Vendor Tcl and Tk 8.6.x** matching what we build against today, so
   this chunk changes *only* where Tcl comes from, not which version.
3. **Teach `tools/tcl-env.sh`** to prefer the vendored tree, with
   `TCLTK_PREFIX` still overriding for system builds.
4. **Build the vendored Tcl/Tk** as part of `tools/build.sh`, cached so
   it is not rebuilt every time.
5. **Static vs shared** — decide. Static simplifies distribution and suits
   the Zig work; shared keeps builds fast. Record the tradeoff.

## Out of scope

- Changing Tcl version. That is 04, deliberately separated so a failure
  is attributable to one cause.

## Chunks

| # | Chunk | Parallel? |
|---|---|---|
| 3a | Decide + document vendoring mechanism | serial, first |
| 3b | Vendor Tcl 8.6.x, build it | after 3a |
| 3c | Vendor Tk 8.6.x, build it | after 3b (Tk needs Tcl) |
| 3d | `tcl-env.sh` prefers vendored | after 3c |
| 3e | CI builds vendored, drops the brew step | after 3d |

Mostly serial. Parallelism here is low; do not force it.

## Gate

- `./tools/build.sh` succeeds on a runner with **no** `tcl-tk` installed.
- Full 01 suite passes against the vendored build.
- Relocation test still passes.
- `brew uninstall tcl-tk@8` locally does not break the build.

## Risk

Build time will grow substantially. Budget for CI caching from the start,
and keep the system-Tcl path working as an escape hatch.
