# 04 — Port to Tcl/Tk 9

**Depends on:** 03 (vendored, pinned source).

## Goal

Build and run against the Tcl/Tk 9.x C API, dropping 8.6.

## Why it is not trivial

Tcl 9 is a deliberate API break. The changes that bite this codebase:

- **`Tcl_Size`** replaces `int` for lengths and indices. This code uses
  `int` everywhere and already has documented 64-bit bugs (upstream flags
  `mib format BinaryValue`, whose symptom is a value formatted at 46 bits
  instead of 14 — a size/width bug of exactly this family).
- **Removed deprecated APIs**, including `interp->result` style access.
- **`const` correctness** tightened across the API surface.
- **Stub table changes**; both extensions build with stubs today.
- Tk 9 changes some widget and image internals; Tkined draws directly on
  a canvas and defines custom items.

## Strategy

Port **Tnm first**, then Tkined. Tnm is the larger C surface but has the
existing test suite; Tkined is smaller but only has the smoke test from 01.

Keep the 8.6 build green in CI until 9 fully passes, then delete 8.6
support in one commit rather than carrying both indefinitely.

## Scope

1. Vendor Tcl/Tk 9.x alongside 8.6, selectable by a build flag.
2. Port Tnm C sources: `Tcl_Size` migration, removed APIs, `const`.
3. Port Tkined C sources, including custom canvas items.
4. Audit the K&R and implicit-int sites that `-Wno-` flags currently
   suppress. Under a real port, fix them properly instead of muting them,
   since several are latent 64-bit bugs rather than style issues.
5. Remove the compatibility `-Wno-` flags from the build once clean.

## Chunks

| # | Chunk | Parallel? |
|---|---|---|
| 4a | Vendor 9.x, add build switch | serial, first |
| 4b | Mechanical `Tcl_Size` sweep in Tnm | parallelizable **by file** |
| 4c | Removed/deprecated API fixes in Tnm | parallel with 4b, different files |
| 4d | Tkined C port | after 4b/4c land |
| 4e | Fix suppressed K&R/implicit-int sites | parallel, file-scoped |
| 4f | Drop 8.6, remove `-Wno-` flags | last |

4b/4c/4e are the parallelizable heart of this spec: file-scoped,
mechanical, individually testable. Good subagent fan-out, one file or
small group per agent, each gated by a compile plus the 01 suite.

## Gate

- Builds against vendored 9.x with **no** `-Wno-` compatibility flags.
- Full 01 suite passes, including the previously `knownBugMacOSX`
  `mib format BinaryValue` case, which should be **fixed** by correct
  size handling. If it is not, that is a finding worth chasing.
- Tkined smoke test passes; editor renders.
- 8.6 support removed in a single reviewable commit.

## Risk

Highest-uncertainty spec. If Tk 9 canvas changes break Tkined badly,
consider staying on Tcl 9 with Tk 8.6 temporarily. Reassess after 4b.
