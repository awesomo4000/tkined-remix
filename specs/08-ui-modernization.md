# 07 — Tk UI modernization

**Depends on:** 01. Interacts with 04 (Tk 9).

## Goal

Make Tkined look like current software without rewriting it.

## Current state

- `bin/tkined` sets `option add Tkined*Text.font fixed`, the X11 bitmap
  font, and disables tear-off menus. The look is 1995 X11.
- Rendering is a Tk canvas with custom item types in C.
- Icons are XBM bitmaps (`tkined/bitmaps/`, plus `*.xbm` maps in apps).
- Tk 8.6 has `ttk` themed widgets; upstream predates them and does not use
  them. On macOS, `ttk` maps to native Aqua widgets.

## Strategy

Theming and asset replacement, **not** a rewrite. The canvas and the app
protocol stay as they are, so all 28 apps keep working. Anything that
would change the `ined` protocol belongs in a different spec.

## Scope

1. **Font and color pass.** Remove the hardcoded `fixed` font; adopt
   platform-appropriate defaults. Highest visual return for the effort.
2. **Migrate chrome to `ttk`** — dialogs, toolbars, menus, scrollbars.
   The canvas itself is unaffected.
3. **Replace XBM icons** with scalable or high-DPI assets. XBM is 1-bit;
   this is what makes it look oldest.
4. **HiDPI correctness.** Verify canvas scaling on Retina.
5. **Dark mode.** macOS reports appearance; Tk 8.6/9 can follow it.
6. **Optional: layout modernization** of the editor window. Explicitly
   opt-in, deferred until 1-5 land.

## Chunks

| # | Chunk | Parallel? |
|---|---|---|
| 7a | Font/color defaults, drop `fixed` | serial, first, high value |
| 7b | `ttk` migration of dialogs | parallel with 7c/7d |
| 7c | Icon asset replacement | parallel with 7b/7d |
| 7d | HiDPI/Retina canvas verification | parallel with 7b/7c |
| 7e | Dark mode | after 7a |
| 7f | Layout rework | last, optional |

7b/7c/7d are genuinely independent and parallelize well.

## Gate

- Tkined smoke test still passes; all 10 packages load, canvas builds.
- All 28 bundled apps still launch. This is the real regression risk:
  apps create their own dialogs and assume widget behavior.
- Visual check on a Retina display, capturing **only the app window**.
- No change to the `ined` protocol.

## Risk

Apps construct Tk widgets directly, so `ttk` migration can break them in
ways the smoke test misses. Add a per-app launch test in 01 before
starting 7b.

## Note

Sequence 7a before 04 (Tk 9) or after, not during. Doing both at once
makes it impossible to tell whether a visual regression came from the
port or the theming.


## Findings from building a real map (2026-08-28)

Discovered while generating a map from live local network data with
`tools/local-map.sh`. All verified, not inferred.

1. **A NULL editor pointer segfaulted the application.** An object created
   with `NODE create` but not yet attached to an editor has
   `object->editor == NULL`. `m_icon` passed it straight to
   `Tki_EditorAttribute`, which dereferenced it. A plain Tcl-level mistake
   crashed the whole app. Fixed with a guard in `tkiEditor.c`.

2. **Only 19 bitmaps are compiled in** (`icon`, `noicon`, `node`, `group`,
   `reference`, `graph`, `corner`, `network`, `link`, the toolbar set).
   Every other icon is an `.xbm` on disk and needs Tk's `@path` form.
   Passing a bare name such as `machine` **silently does nothing**: no
   error is raised and the object keeps its default icon. Silent failure
   is the problem here, not the path requirement.

3. **`machine.xbm` does not render through the object API** even via
   `@path`, while `mac.xbm` and `router.xbm` do. The file is structurally
   valid: 40x29 with the expected 145 data bytes, it has a mask like the
   others, and plain Tk loads it correctly with the right bbox. So this is
   in tkined's icon handling, not Tk and not the file. Unresolved;
   `tools/local-map.tcl` uses `pc` instead.

4. **Icons do not survive a save/load round trip.** `$editor save` writes
   the icon as a bare basename, dropping the `@` and the directory, so
   reloading a map falls back to default icons.

5. **Tk on Aqua cannot emit bitmap items to PostScript.** The canvas
   PostScript dump renders links, labels and network segments but omits
   every icon. Pinning `-foreground`/`-background` to concrete colors, the
   trick `Editor__postscript` uses for backgrounds, does not help. This
   limits the offscreen render path, which is otherwise the way to
   generate map images without mapping a window.

Items 2, 3 and 4 are icon-handling bugs and belong together in whichever
chunk touches icon assets (7c in the table above).
