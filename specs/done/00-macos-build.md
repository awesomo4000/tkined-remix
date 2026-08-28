# 00 — Build cleanly on macOS  [DONE]

**Status:** complete, commit `10a7153`.

## Goal

Get scotty building and running on macOS 15 / Apple Silicon, entirely
inside the repository, with no machine-specific paths committed.

## What was wrong

1. **Only Tcl 9.0.4 present.** Tcl 9 is a hard C API break for this code.
   Resolved by building against Homebrew `tcl-tk@8` (8.6.18). Removing
   this dependency is spec 03.
2. **autoconf >= 2.72 enables C23**, which deleted K&R function
   definitions. The source uses them throughout. Fixed with
   `ac_cv_prog_cc_c23=no`.
3. **Implicit-int K&R parameters.** For example `restKind` in
   `tnm/snmp/tnmMibFrozen.c:326` appears in the parameter list but is
   never declared, so it defaulted to `int` under C89. Modern clang
   errors. Fixed with `-Wno-` flags rather than editing many call sites.
4. **TEA takes `exec_prefix` from `tclConfig.sh`**, so `make install`
   wrote into the Homebrew keg. Fixed with explicit
   `--exec-prefix/--bindir/--libdir`.
5. **Compile-time baked library paths.** `TNMLIB`/`TKINEDLIB` are
   absolute. Worked around at runtime via `TNM_LIBRARY`/`TKINED_LIBRARY`,
   which makes a built tree relocatable.

## Delivered

- `tools/tcl-env.sh` — discovers a Tcl/Tk prefix; `TCLTK_PREFIX` overrides.
- `tools/build.sh` — derives the install prefix from the repo location,
  builds into gitignored `build/`.
- `bin/scotty`, `bin/tkined` — relocatable launchers.
- `.gitignore` covering all generated output.
- No upstream source files modified.

## Gate (met)

- `./tools/build.sh` from a clean tree succeeds.
- `bin/scotty` loads Tnm 3.1.3, all 13 command families present.
- MIB compiler resolves real OIDs (`sysDescr` -> `1.3.6.1.2.1.1.1`).
- All 10 Tkined packages load; editor constructs a canvas headlessly.
- Tree copied to an unrelated path still runs (relocation verified).

## Gotchas for later work

- `make distclean` deletes the autoheader-generated `config.h.in`.
- A prefix change requires `make clean`, because paths are compiled in.
- macOS Aqua `wish` **discards stdout**; use stderr or a file to debug.
