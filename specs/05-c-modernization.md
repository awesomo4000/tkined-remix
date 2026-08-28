# 05 — Modernize the C to ISO C

**Depends on:** 01 (needs a gate). **Blocks:** 06 (Zig build).
**Independent of:** the Tcl version, so it can run in parallel with 03/04.

## Goal

Remove the pre-standard C constructs this codebase relies on, so it
compiles clean under a current compiler with no suppression flags.

## Why this is its own spec

Right now `tools/build.sh` mutes six diagnostics to get a build:

    -Wno-implicit-int -Wno-implicit-function-declaration
    -Wno-deprecated-non-prototype -Wno-int-conversion
    -Wno-incompatible-pointer-types -Wno-return-type

Those are not style warnings. `-Wno-int-conversion` and
`-Wno-incompatible-pointer-types` hide real type errors, and the code has
documented 64-bit bugs of exactly that family. Every one of these is
currently invisible.

This is separated from 04 (Tcl 9) deliberately: mixing an API port with a
language cleanup makes any regression impossible to attribute.

## Measured behavior (Zig 0.16.0, verified)

- **K&R function definitions:** `zig cc` emits a *warning*, not an error,
  at its default and at `-std=gnu17`. So Zig is more permissive here than
  Apple clang, which defaults to C23 and rejects them outright.
  They are still "not supported in C23" and must go eventually.
- **Implicit-int parameters:** a **hard error** under `zig cc` even at
  `-std=gnu17`. Example: `tnm/snmp/tnmMibFrozen.c:326`, where `restKind`
  is in the parameter list but never declared.

So the blocking item for Zig is implicit-int; K&R conversion is the
larger but less urgent job.

## Scope

1. **Convert K&R definitions to prototypes** across `tnm/` and `tkined/`.
   Mechanical and file-scoped.
2. **Fix implicit-int parameters.** Small set, blocks Zig.
3. **Fix, do not mute, the type errors** behind `-Wno-int-conversion` and
   `-Wno-incompatible-pointer-types`. Expect real bugs here, for example
   the `(char *) addr->sin_addr.s_addr` casts in `tnm/generic/tnmUtil.c`
   around lines 935 and 946, which cast a 32-bit integer to a pointer.
4. **Fix missing returns** behind `-Wno-return-type`.
5. **Delete each suppression flag** as its class is cleared. The flag
   list in `tools/build.sh` is the progress bar for this spec.

## Out of scope

- Reformatting, renaming, or restructuring. Type-correctness only.
- Tcl API changes. That is 04.

## Chunks

| # | Chunk | Parallel? |
|---|---|---|
| 5a | Implicit-int fixes, drop `-Wno-implicit-int` | serial, first, small |
| 5b | K&R -> prototypes in `tnm/generic/` | **parallel by file** |
| 5c | K&R -> prototypes in `tnm/snmp/` | **parallel by file** |
| 5d | K&R -> prototypes in `tnm/unix/` + `tkined/` | **parallel by file** |
| 5e | Pointer/int conversion errors | after 5b-5d; needs judgement |
| 5f | Missing returns; drop remaining flags | last |

**This is the best subagent fan-out in the roadmap.** 5b/5c/5d are
mechanical, file-scoped, and independently verifiable: one file or small
group per agent, each gated by "compiles with that warning class enabled
and the 01 suite still passes".

5e is the opposite: each site needs a human-quality decision about what
the code *meant*. Do not fan that out blindly.

## Gate

- Builds with **zero** `-Wno-` flags in `tools/build.sh`.
- Full 01 suite passes.
- Builds clean under both Apple clang and `zig cc`.
- Each pointer/int fix in 5e has a test or a written rationale.

## Risk

5e can change behavior. The casts currently "work" by accident on
little-endian 64-bit. Treat every one as a potential bug fix and a
potential regression, and land them in small reviewable commits.
