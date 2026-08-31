# Working on tkined-remix

## Branch workflow

`main` is always buildable and always passes the gate. No work happens
directly on it.

    git checkout main && git pull
    git checkout -b <area>/<short-description>
    # ... work, commit as you go ...
    ./tools/build.sh && ./tools/test.sh     # must pass before merging
    git checkout main && git merge --no-ff <branch>
    git push origin main
    git branch -d <branch>

Branch naming by spec area:

| Prefix | Use |
|---|---|
| `test/` | 01 test harness and CI |
| `icmp/` | 02 ICMP without root |
| `vendor/` | 03 vendored Tcl/Tk |
| `tcl9/` | 04 Tcl/Tk 9 port |
| `cmod/` | 05 C modernization |
| `zig/` | 06 Zig build |
| `agent/` | 07 distributed agents |
| `ui/` | 08 UI modernization |
| `docs/` | documentation only |

Use `--no-ff` so each chunk stays visible as a unit in history.

## Definition of done

A chunk is done when its spec's **Gate** section passes, not when the code
looks right. Every spec states its gate explicitly.

Run the gate before merging:

    ./tools/build.sh      # build into build/
    ./tools/test.sh       # gate suites + tkined smoke + relocation

Other modes:

    ./tools/test.sh all       # add advisory + quarantined suites
    ./tools/test.sh mib udp   # named suites

Only the gate suites can fail the run. Advisory suites are reported but
never block, and quarantined ones are tracked by a spec. Classification
and the current numbers live in `specs/test-baseline.md`.

## Spec lifecycle

Specs live in `specs/`. When one is fully delivered and its gate passes,
move it to `specs/done/` in the same commit that completes it, with a
`**Status:**` line naming the commit.

## Ground rules

- **No machine-specific paths.** No usernames, no absolute paths outside
  the repo. `tools/tcl-env.sh` discovers Tcl/Tk; nothing else hardcodes it.
- **Prefer build-level fixes to source edits** while the `upstream` remote
  is still useful for rebasing.
- **Verify, do not assume.** Several inherited "known limitations" turned
  out to be wrong or misattributed on first contact. Measure, then write
  it down.
- Build output belongs in `build/`, which is gitignored.

## Bugs

Defects that are found but not fixed go in `specs/known-bugs.md`, with the
evidence for each and enough detail to act on. Anything reproduced by
measurement says so; anything suspected but unconfirmed says that too.
Move an entry to the Fixed table in the same commit that fixes it.

## Upstream

    git fetch upstream          # https://github.com/flightaware/scotty

Inherited branches worth knowing about:

- `origin/BCK-13583-tcl9-compatibility` — 16 commits of partial Tcl 9
  `Tcl_Size` work, Tnm only. See spec 04.
- `origin/multicast` — `MCAST_JOIN_GROUP` support and a syslog format-string
  fix. Worth cherry-picking; the syslog change looks like a real bug fix.
- `origin/base` — historical, 141 commits behind. Ignore.
