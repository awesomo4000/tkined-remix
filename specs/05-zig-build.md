# 05 — Zig build system

**Depends on:** 03 (and ideally 04).

## Goal

Replace autotools with `build.zig`. One build, reproducible, cross-capable.

## Why Zig

`zig cc` is a drop-in C compiler with a bundled libc and real
cross-compilation, which suits a codebase whose portability problems are
mostly "which headers and which libc". It also removes the autoconf
generation step that has already bitten us twice (C23 default, deleted
`config.h.in`).

## What autotools currently provides

Must be replicated or consciously dropped:

- `tclConfig.sh` / `tkConfig.sh` ingestion (moot after 03 vendoring).
- Header/function probes: `rpc/rpc.h`, `struct rpcent`, `getrpcent`,
  `res_mkquery` in `-lresolv`, `zlib.h`, `smi.h`, `sys/select.h`.
- `rpcgen` invocation for `tnm/generic/*.x`, with prebuilt fallbacks
  already committed in `tnm/compat/`.
- Baked `TNMLIB`/`TKINEDLIB` defines.
- Shared library naming/versioning and stub linkage.

## Scope

1. `build.zig` for Tnm, then Tkined.
2. Replace probes with explicit per-platform config, since after 03 the
   variability is platform-level, not machine-level.
3. Handle `rpcgen`: prefer the committed `tnm/compat/` output over
   requiring the tool at build time.
4. Keep `TNM_LIBRARY` relocation behavior.
5. **Run both build systems in CI until Zig passes the same gate**, then
   remove autotools in one commit.
6. Cross-compilation target: Linux x86_64 and arm64 from macOS.

## Chunks

| # | Chunk | Parallel? |
|---|---|---|
| 5a | `build.zig` for Tnm C library | serial, first |
| 5b | `scotty`, `nmicmpd`, `nmtrapd` targets | after 5a |
| 5c | `build.zig` for Tkined | parallel with 5b |
| 5d | Vendored Tcl/Tk under Zig | hardest; parallel with 5b/5c |
| 5e | Cross-compile targets + CI matrix | after 5d |
| 5f | Retire autotools | last |

## Gate

- `zig build` produces binaries passing the full 01 suite.
- Relocation test passes.
- Autotools and Zig outputs behave identically before autotools is removed.
- A Linux binary cross-compiled from macOS runs on Linux CI.

## Risk

5d is the crux: Tcl/Tk have elaborate build systems and may resist being
driven from Zig. Fallback is to keep building Tcl/Tk with their own
configure and use Zig only for scotty. That is still a win; say so up
front rather than treating it as failure.
