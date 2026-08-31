# 03 — Vendor Tcl/Tk in-tree  [DONE]

**Status:** complete. Tcl/Tk 8.6.18 is fetched from pinned sources,
verified, and built into `vendor/prefix`. The build no longer uses
Homebrew's `tcl-tk@8`.

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


## Outcome

Delivered as specified. Decisions taken:

**Mechanism: pinned tarballs verified by checksum**, not a submodule and
not a committed source dump. The repository stays small, the exact bytes
are verified, and Tcl's canonical version control is Fossil, so the git
mirrors would have been a second-hand source. `TCLTK_TARBALL_DIR` allows a
fully offline build.

**Shared, not static.** This chunk changed only *where* Tcl comes from;
the extensions link against it exactly as before, stubs included. Static
linking belongs with the Zig build, where it buys a single distributable
binary rather than just a different link mode.

## The checksum mistake, and what it should teach

The first attempt pinned SHA-256 values **computed from our own download**.
That verifies nothing, and it showed: the mirror served a *truncated
release candidate*, our hash matched it perfectly, and the build failed
only at extraction. Two separate errors compounded it -- the script's
output was piped through `tail`, so the pipeline reported the exit status
of `tail` rather than the failure, and the archive was never tested for
integrity before its hash was trusted.

Fixed three ways: checksums now come from the Homebrew formula, an
independently maintained source; the archive is tested with `tar` before
its hash is trusted, so a truncated download reports the real problem; and
the fetch uses `--retry-all-errors`, because the mirror truncates transfers
intermittently rather than consistently.

The general lesson: a checksum is only worth as much as the independence of
where it came from.

## Gate

- Build and full gate pass with Homebrew removed from `PATH` entirely.
- No built artifact references the Homebrew keg, confirmed with `otool`.
- `scotty` links and loads `vendor/prefix/lib/libtcl8.6.dylib`.
- Relocation test passes.
- CI installs only autoconf, caches the vendored tree, and builds it.

The gate asked for `brew uninstall tcl-tk@8` to be harmless. Removing a
package from the user's machine to prove a point is worse than the
alternative used here: hiding Homebrew from `PATH` and checking every
artifact's actual link table. That is stronger evidence and reversible.

**Remaining dependency.** autoconf is still required on a clean checkout,
because `configure` is generated rather than committed. Only the Tcl/Tk
dependency is gone. Committing `configure`, or moving to the Zig build of
spec 06, would remove the last one.
