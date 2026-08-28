# 06 — Zig build system (Zig 0.16.0)

**Depends on:** 03 (vendored Tcl/Tk), 05 (C modernization).
**Target:** Zig **0.16.0** (confirmed installed locally via zvm).

## Goal

Replace autotools with `build.zig`, and have the C compile cleanly under
`zig cc`. One reproducible, cross-capable build.

## Why Zig

`zig cc` is a clang-based C compiler that ships its own libc headers and
cross-compiles without a sysroot. This codebase's portability problems are
almost entirely "which headers, which libc", which is exactly what that
solves. It also deletes the autoconf generation step, which has already
caused two failures in this project: autoconf 2.72 silently enabling C23,
and `make distclean` removing the generated `config.h.in`.

## Verified compiler behavior (Zig 0.16.0)

Measured, not assumed:

- K&R function definitions: **warning** under `zig cc`, both at default
  and `-std=gnu17`. More permissive than Apple clang's C23 default.
- Implicit-int parameters: **hard error**, even at `-std=gnu17`.

So `zig cc` can compile most of this tree today, but **not** until the
implicit-int sites are fixed. That is chunk 5a, hence the dependency on 05.

## What autotools currently provides

Must be replicated or consciously dropped:

- `tclConfig.sh` / `tkConfig.sh` ingestion — largely moot after 03.
- Probes: `rpc/rpc.h`, `struct rpcent`, `getrpcent`, `res_mkquery` in
  `-lresolv`, `zlib.h`, `smi.h`, `sys/select.h`.
- `rpcgen` for `tnm/generic/*.x`. Prebuilt output is already committed
  under `tnm/compat/`, so the tool need not be a build dependency.
- Baked `TNMLIB` / `TKINEDLIB` defines.
- Shared library naming/versioning and Tcl stub linkage.

## Scope

1. `build.zig` for the Tnm C library, then its programs.
2. `build.zig` for Tkined.
3. Replace autoconf probes with explicit per-platform config. After 03 the
   variability is platform-level, not machine-level, so most probes become
   constants.
4. Use committed `tnm/compat/` rpcgen output rather than requiring rpcgen.
5. Preserve `TNM_LIBRARY` / `TKINED_LIBRARY` relocation behavior.
6. Cross-compile to Linux x86_64 and arm64 from macOS.
7. **Run autotools and Zig side by side in CI** until Zig passes the same
   gate, then retire autotools in one commit.

## Chunks

| # | Chunk | Parallel? |
|---|---|---|
| 6a | `zig cc` compiles all C via existing Makefiles (`CC="zig cc"`) | serial, **first** |
| 6b | `build.zig` for the Tnm library | after 6a |
| 6c | `scotty`, `nmicmpd`, `nmtrapd` targets | after 6b |
| 6d | `build.zig` for Tkined | parallel with 6c |
| 6e | Vendored Tcl/Tk under Zig | hardest; parallel with 6c/6d |
| 6f | Cross-compile targets + Linux CI | after 6e |
| 6g | Retire autotools | last |

**6a is the cheap early signal.** `tools/build.sh` already honors `CC`, so
`CC="zig cc" ./tools/build.sh` is a one-line experiment that tells us how
far off we are before any `build.zig` is written. Do it first.

## Gate

- `zig build` produces binaries passing the full 01 suite.
- Relocation test passes.
- Autotools and Zig outputs behave identically before autotools is removed.
- A Linux binary cross-compiled from macOS runs on Linux CI.
- Pinned to Zig 0.16.0; the version is recorded in the repo and CI.

## Risk

6e is the crux: Tcl and Tk have elaborate build systems of their own and
may resist being driven from `build.zig`. The fallback is to keep building
vendored Tcl/Tk with their own configure and use Zig only for scotty.
That is still a real win. Say so up front rather than treating it as
failure.

Zig's build API is also not yet stable across releases, so pin 0.16.0 and
treat a version bump as its own chunk with its own gate.
