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
