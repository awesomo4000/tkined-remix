# 01 — Test harness and CI gates  [DONE]

**Status:** complete. Delivered `tools/test.sh`, `tests/tkined-smoke.{sh,tcl}`,
`tests/relocation.sh`, `.github/workflows/ci.yml`, `specs/test-baseline.md`.

**Depends on:** 00. **Blocks:** everything after it.

## Goal

A single command that proves the tree is healthy, running on a clean
GitHub Actions macOS runner, so every later chunk has an objective gate.

## Why this comes before the ICMP work

Every remaining spec changes C code, the build system, or both. Without a
gate, "it still works" is an opinion. This is small and unblocks the rest.

## Current state (verified)

- `tnm/tests/` has 13 suites using **`tcltest` 2**, plus `all.tcl`.
- `tkined/` has **no tests at all**.
- Upstream documents failures on macOS/64-bit in `dns -server`, `icmp` to
  unreachable hosts, and `mib format BinaryValue`, marked `knownBugMacOSX`.
- Tests need `TCLLIBPATH`/`TNM_LIBRARY` set the way `bin/scotty` does.

## Scope

1. **`tools/test.sh`** — runs the Tnm suite against the built tree with
   correct environment, exiting non-zero on failure.
2. **Test classification.** Split suites into:
   - `offline` — no network (netdb, mib, job, syslog, map, asn1). Must
     always pass. This is the real gate.
   - `loopback` — needs only 127.0.0.1 (udp, some icmp).
   - `network` — needs DNS/external hosts. Advisory, never gates.
   The existing `knownBugMacOSX` constraints stay until a spec fixes them.
3. **Tkined smoke test** — headless, no window mapped: load all 10
   packages, construct an editor, assert a canvas exists, exit 0. This
   already works manually; make it a test.
4. **Relocation test** — copy the built tree to a temp dir, run from
   there. Catches machine-specific paths, which CI alone would not.
5. **GitHub Actions** — `macos-latest`: install `tcl-tk@8`, build, run
   `offline` + `loopback` + smoke + relocation.

## Out of scope

- Fixing any currently failing test. Record and quarantine only.
- Linux/BSD CI. Add when the Zig build lands (05).

## Chunks

| # | Chunk | Parallel? |
|---|---|---|
| 1a | `tools/test.sh` + suite classification | serial, first |
| 1b | Tkined headless smoke test | parallel with 1c |
| 1c | Relocation test | parallel with 1b |
| 1d | Actions workflow wiring | after 1a-1c |

## Gate

- `./tools/test.sh` green locally and on a clean runner.
- Baseline of known failures recorded in `specs/test-baseline.md`.
- CI required for merge to `master`.

## Open question

Whether to gate on `loopback` tests. Runner ICMP/UDP behavior is not
guaranteed. Start advisory, promote once observed stable.


## Outcome

Delivered as specified. Two findings changed the plan while doing it:

1. **`netdb` was misclassified.** It looked like a safe offline suite and
   in fact hung indefinitely. Measuring before classifying was the whole
   value of this spec.
2. **`knownBug64BitArchitecture` was silently broken on arm64**, so
   known-buggy tests were running instead of skipping. Fixing that guard
   removed 6 failures and the hang. See `specs/test-baseline.md`.

The open question about gating loopback suites was resolved by keeping
them advisory for now, pending observation on CI runners.
