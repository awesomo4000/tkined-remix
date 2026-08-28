# 06 — Distributed collectors over SSH

**Depends on:** 01. Benefits from 02. Independent of the toolchain line.

## Goal

Run the Tkined UI on a workstation while collectors (ICMP, SNMP, DNS,
RPC probes) execute on registered remote agents reached over SSH.

## Why this is tractable (verified, not speculative)

Tkined already separates the UI from the work:

- Apps are **standalone processes** (`tkined/apps/*.tcl`, 28 of them).
  They `package require Tnm`, call `ined`, and are not linked into the GUI.
- `tnm/generic/tnmIned.c:204` — the app connects to the editor over
  **TCP** when `TNM_INED_TCPPORT` is set, otherwise stdin/stdout.
- `tkined/generic/tkiMethods.c:1170` — the editor sets that variable when
  spawning an app.
- The protocol is **line-buffered**, so it tunnels cleanly.

So a remote collector is largely: run the app on the remote host with
`TNM_INED_TCPPORT` pointed at an SSH-forwarded port.

**Two constraints found in the same code:**

1. The client host is **hardcoded to `localhost`** (`tnmIned.c:216`).
   That is fine, and arguably good: it forces the SSH-tunnel design.
   The remote end connects to its own loopback, forwarded back to us.
2. The protocol has **no authentication and no encryption**. It must
   never be exposed on a real interface. SSH is not a convenience here,
   it is the entire security boundary. Bind the listener to loopback and
   verify that it is bound to loopback, rather than assuming.

## Scope

1. **Agent registry** — declared agents (host, SSH target, capabilities,
   credentials by reference). A file format plus UI to manage it.
2. **Transport** — establish `ssh -R` reverse forwards so a remote app
   reaches the local editor on the remote's loopback. Handle connection
   loss, reconnect, and agent death without hanging the UI.
3. **Remote bootstrap** — the agent host needs `scotty` and the Tnm
   library. Options: pre-install, or ship a static binary (much easier
   after 05 cross-compilation). Decide explicitly.
4. **Dispatch** — let a map object or app choose *which* agent runs a
   probe. This is the real UX design question: how does a user say
   "monitor this subnet from the Frankfurt agent"?
5. **Security posture** — document the trust model plainly. Anyone who can
   reach the `ined` port controls the editor.

## Out of scope

- Rewriting the `ined` protocol. Tunnel it; redesigning it is separate.
- Agent-to-agent communication. Star topology only.

## Chunks

| # | Chunk | Parallel? |
|---|---|---|
| 6a | Prove the seam: run an unmodified app over an SSH tunnel by hand | serial, **first** |
| 6b | Agent registry format + loader | parallel with 6c |
| 6c | SSH transport manager (forwards, lifecycle, reconnect) | parallel with 6b |
| 6d | Remote bootstrap / binary shipping | parallel, depends on 05 for static builds |
| 6e | Dispatch UI | after 6b/6c |
| 6f | Loopback-binding and trust-model verification | parallel, small |

**6a is the gate for the whole spec.** If an unmodified app cannot be
driven over a tunnel, the design assumption is wrong and everything after
it needs rethinking. Do 6a before committing to 6b-6f.

## Gate

- An unmodified upstream app (for example `ip_monitor.tcl`) runs on a
  remote host and updates the local map.
- Killing the SSH connection degrades gracefully; no UI hang.
- Verified: the `ined` listener is bound to loopback only.
- Two agents run concurrently against one editor.

## Risk

The protocol may carry local assumptions beyond the transport, such as
file paths (`TKINED_PATH`) or the app expecting a shared filesystem.
6a will expose these early, which is exactly why it comes first.
