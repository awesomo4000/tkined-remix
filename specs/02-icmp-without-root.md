# 02 — ICMP without root

**Depends on:** 01 (needs a gate). **Independent of:** 03-05.

## Goal

`Tnm::icmp echo` works as an unprivileged user on macOS, with no setuid
binary. Degrade honestly where the OS genuinely requires privilege.

## Current state (verified, not assumed)

- `Tnm::icmp echo 127.0.0.1` as uid 501 fails with
  `nmicmpd: inappropriate device for ioctl`.
- That message is **misleading**. `ENOTTY` is a stale errno picked up by
  `Tcl_PosixError` in `tnm/unix/tnmUnixIcmp.c:215` *after* the daemon has
  already exited. It is not a permission error.
- Real cause, `tnm/unix/nmicmpd.c:1216`:
  `socket(AF_INET, SOCK_RAW, icmp_proto)` -> `EPERM` for non-root.
- Measured on this machine as uid 501:
  - `SOCK_RAW  IPPROTO_ICMP` -> `EPERM`
  - `SOCK_DGRAM IPPROTO_ICMP` -> **succeeds**
- `/sbin/ping` is mode `-r-xr-xr-x`, **not setuid**, and works unprivileged.
- A full echo round-trip to loopback as uid 501 was confirmed working;
  macOS prepends a 20-byte IP header on `SOCK_DGRAM` ICMP receives.
- `nmicmpd.c:1231` separately opens `SOCK_RAW`/`IPPROTO_RAW` for the
  traceroute TTL path. **That genuinely needs root.**

## Scope

1. **Fix the misleading error first.** Report why `nmicmpd` exited rather
   than a stale errno. This is independently worth doing and makes the
   rest debuggable.
2. **Datagram ICMP fallback.** Try `SOCK_RAW`; on `EPERM` fall back to
   `SOCK_DGRAM`/`IPPROTO_ICMP` and record which mode is active.
3. **Handle the two behavioral differences:**
   - **`icmp_id` is rewritten by the kernel** on datagram sockets.
     `nmicmpd` correlates replies to targets by id, so this correlation
     **will break** and must be reworked (likely keying on sequence number
     plus target address).
   - Receive framing differs; confirm whether the IP header is present in
     both modes and normalize.
4. **Feature-gate traceroute.** If only datagram mode is available, either
   set TTL via `IP_TTL` on the datagram socket (verify it works) or fail
   with a clear message naming setuid as the remedy.

## Out of scope

- Linux `ping_group_range` handling. Note it; do it when Linux CI exists.
- IPv6. Upstream is IPv4-only; that is a separate spec.

## Chunks

| # | Chunk | Parallel? | Risk |
|---|---|---|---|
| 2a | Accurate daemon-failure error reporting | yes | low |
| 2b | Socket fallback + mode reporting | after 2a | low |
| 2c | Rework reply correlation for rewritten `icmp_id` | after 2b | **high** |
| 2d | Traceroute TTL in datagram mode, or clean refusal | after 2b | medium |

2c is the real work. Everything else is small.

## Gate

- New test: `Tnm::icmp echo 127.0.0.1` succeeds as a normal user.
- New test: multi-target echo returns results matched to the **correct**
  targets. This is what proves 2c; a single-target test would not.
- Traceroute either works unprivileged or fails with an actionable message.
- No regression when running with elevated privileges.

## Risk

If kernel id-rewriting cannot be worked around cleanly, fall back to one
socket per outstanding target, or keep setuid as an opt-in fast path.
Decide with measurements, not guesses.
