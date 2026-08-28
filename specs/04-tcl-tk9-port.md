# 04 — Port to Tcl/Tk 9

**Depends on:** 03 (vendored, pinned source).
**Related:** 05 does the C language cleanup; keep the two separate.

## Important: upstream already started this

The fork inherited a branch, `origin/BCK-13583-tcl9-compatibility`,
**16 commits ahead of main**, doing exactly this work:

    f693cba More Tcl_Size lint.
    80e41be Fix typos, and Tcl_Size propogates upward.
    d292d74 Boost more int -> Tcl_Size
    ...
    a80fe80 Scratching the surface on changes

Scope: 25 files, +146/-93, **`tnm/` only — no Tkined files touched**.
It is 2 commits behind main.

The commit messages ("Scratching the surface", "More Tcl_Size lint")
indicate it is incomplete, and it has never been gated by a test suite.
**Chunk 4a is therefore to evaluate and rebase this branch, not to start
from scratch.** Assess how much is genuinely done before planning the rest.

## Why it is not trivial

Tcl 9 is a deliberate API break. What bites this codebase:

- **`Tcl_Size`** replaces `int` for lengths and indices. This is what the
  inherited branch is doing. The code uses `int` everywhere and already
  has documented 64-bit bugs: upstream's `mib format BinaryValue` failure
  formats a value at 46 bits instead of 14, which is precisely a
  size/width bug.
- **Removed deprecated APIs**, including `interp->result` style access.
- **`const` correctness** tightened across the API surface.
- **Stub table changes**; both extensions build with stubs today.
- Tk 9 changes widget and image internals. Tkined draws on a canvas with
  custom item types in C, and the inherited branch does not touch it at
  all, so Tkined is entirely unported.

## Strategy

Port **Tnm first** (has the 01 test suite), then Tkined (only the smoke
test). Keep the 8.6 build green in CI until 9 fully passes, then delete
8.6 support in one commit rather than carrying both indefinitely.

## Scope

1. Evaluate and rebase `BCK-13583-tcl9-compatibility` onto main.
2. Vendor Tcl/Tk 9.x alongside 8.6, selectable by a build flag.
3. Finish the Tnm port: remaining `Tcl_Size`, removed APIs, `const`.
4. Port Tkined C, including custom canvas items. Unstarted upstream.
5. Remove 8.6 support once 9 is green.

## Chunks

| # | Chunk | Parallel? |
|---|---|---|
| 4a | Evaluate + rebase the inherited tcl9 branch | serial, **first** |
| 4b | Vendor 9.x, add build switch | after 4a |
| 4c | Finish `Tcl_Size` sweep in Tnm | **parallel by file** |
| 4d | Removed/deprecated API fixes in Tnm | parallel with 4c, different files |
| 4e | Tkined C port | after 4c/4d; unstarted, highest unknown |
| 4f | Drop 8.6 | last |

4c/4d parallelize well by file. 4e does not — it is exploratory.

## Gate

- Builds against vendored 9.x.
- Full 01 suite passes, **including** the previously `knownBugMacOSX`
  `mib format BinaryValue` case, which correct size handling should fix.
  If it does not, that is a finding worth chasing rather than papering over.
- Tkined smoke test passes; editor renders.
- 8.6 removed in a single reviewable commit.

## Risk

Highest-uncertainty spec, and Tkined is the unknown half. If Tk 9 canvas
changes break Tkined badly, consider Tcl 9 with Tk 8.6 temporarily.
Reassess after 4c.
