# Known bugs

Defects found and not yet fixed, with the evidence for each. Fixed issues
are listed at the bottom so the record stays honest about what was actually
verified rather than assumed.

Severity is about consequence, not effort.

---

## Open

### B1 — Network address helper drops zero octets

**Severity:** high. Silently produces wrong results on common networks.
**Where:** `tkined/apps/ip_discover.tcl`, the network-address helper.
**Found:** while extracting spec 04.

The helper appends an octet only when it is non-zero. Measured:

| Address | Mask | Produced | Correct |
|---|---|---|---|
| `192.168.1.50` | `255.255.255.0` | `192.168.1` | `192.168.1.0` |
| `172.16.0.9` | `255.255.0.0` | `172.16` | `172.16.0.0` |
| `10.0.5.3` | `255.255.255.0` | **`10.5`** | `10.0.5.0` |

Dropping *trailing* zeros yields a prefix rather than an address, and the
host sweep happens to want prefixes, so that part is load-bearing. Dropping
an *interior* zero shifts the remaining octets left and misidentifies the
network outright. **Every `10.0.x.x` network is affected.** Comparisons
against such a value fail silently rather than raising.

**Fix:** compute network addresses as full 32-bit values; format a prefix
separately where a prefix is what the caller wants. Both callers need
checking, since one currently depends on the truncation.

### B2 — Netmask discovery degrades silently without privilege

**Severity:** medium. Produces a worse map with no indication.
**Where:** discovery stage 3, via `Tnm::icmp mask`.
**Found:** while extracting spec 04, following on from spec 02.

ICMP address mask requests need a raw socket. After the unprivileged ICMP
work, echo, ttl and traceroute all run as a normal user, but `mask` and
`timestamp` still require `nmicmpd` to be setuid root. When mask queries
fail, every netmask is unknown and network inference falls back to classful
guessing, producing a plausible but wrong map with no warning.

**Fix:** detect the degraded mode and say so, and prefer another source of
subnet data (SNMP, or the routing table) over classful assumption.

### B3 — Icons do not survive save and load

**Severity:** medium. Visible data loss on every reopened map.
**Where:** map save, in the editor core.
**Found:** while generating a map from live data.

The saver writes an icon as a bare basename, discarding the path. On load
the bare name cannot be resolved, so reloaded maps fall back to default
icons. Confirmed by saving and reloading a generated map.

**Fix:** store a stable icon identifier and resolve it at draw time, as
spec 01 describes.

### B4 — Bare icon names fail silently

**Severity:** medium. A wrong name looks like a working call.
**Where:** the icon method in the editor core.
**Found:** while generating a map.

Only 19 bitmaps are compiled in. Every other icon is a file on disk and
must be named in the toolkit's path form. Passing a bare name raises no
error and leaves the object on its previous icon, so the caller cannot tell
the difference between success and a typo.

**Fix:** resolve names against a known icon set and make an unknown name an
error.

### B5 — One icon does not render through the object API

**Severity:** low. Cosmetic, one asset.
**Where:** unclear; not the file and not the toolkit.
**Found:** while generating a map.

`machine.xbm` does not render when set through the object API, while
`mac.xbm` and `router.xbm` set the same way do. Ruled out by measurement:
the file is structurally valid at 40x29 with the expected 145 data bytes,
it has a mask like the others, and loading it directly into a bare canvas
works and reports the correct bounding box. So the fault is in the icon
handling path, not the asset and not the toolkit. Unresolved; the map
generator uses a different icon.

### B6 — Objects sometimes refuse to drag

**Severity:** medium. Reported by the user; not reproduced.
**Where:** the press dispatcher and the move tool.
**Found:** reported after the Aqua mouse binding fix.

Not reproduced under synthetic events across: repeated drags, click offsets
over the icon and label and off it, drags after a rubber band selection and
after a bare click, alternating objects, every object in a real map, and
dragging an object outside an existing multi-object selection.

Suspected but unconfirmed: the press dispatcher decides "this is a move"
with its own hit test, and the move tool then independently re-derives
whether to arm from the canvas selection tags. If the two disagree the
press is treated as a move that then does nothing.

**To capture one:** run with `TKINED_MOUSE_LOG=/tmp/mouse.log`. Each press
records what was under the cursor, whether a move armed, and the selection
size. A failing drag shows either `armed=0` on a press that should have
moved something, or `rubber band` with a real object in its `hits:` list.

### B7 — SMX engine lifecycle

**Severity:** low. Obscure subsystem, quarantined.
**Where:** `tnm/tests/l.smx.test` and the Script MIB engine.

19 of 47 tests pass. The suite starts a listener and launches an engine,
which does connect, verified accepting from the loopback address. The
engine script then ends, the interpreter exits at end of file, and the
suite reports the peer as gone on the next command. Keeping the engine
alive with an event loop was tried and is **not** the fix: it hangs the
whole suite. Entry point for anyone picking it up is the engine start
routine in the test.

### B8 — An object did not come back from retrieve

**Severity:** unknown. Observed once, not investigated.
**Where:** map load, or the retrieve command.

Dragging every object in a generated map exercised six objects, but the map
contains seven. One node was not returned by `retrieve`. May be related to
B3, since both concern load fidelity. Worth confirming before trusting a
loaded map to be complete.

### B9 — Click selects the last candidate, not the topmost

**Severity:** low. Wrong object toggles when objects overlap.
**Where:** the select tool's click handler.
**Found:** while extracting spec 03.

When several objects lie under the pointer, the handler iterates the
overlapping items and keeps the **last** one carrying an object id, then
toggles that. The last item in the iteration is not the topmost one, so
which object responds depends on internal drawing order rather than on
what is visually on top.

The hit-testing helper next to it already does this correctly, walking the
z-order from the closest item outward. The click handler should use it
instead of its own loop.

### B10 — ASN1_COUNTER64 falls through to the IP address case

**Severity:** medium. Wrong conversion for 64-bit counters.
**Where:** `tnm/snmp/tnmMibUtil.c`, `TnmMibGetValue`.
**Found:** while porting to Tcl 9.

The `ASN1_COUNTER64` case converts to the unsigned-64 type and then has
no `break`, so control falls into `ASN1_IPADDRESS` and immediately
overwrites the result with an IP address conversion. Every other case in
the switch breaks, so this reads as an omission rather than intent.

Left alone deliberately: it is unrelated to the Tcl 9 port and fixing it
in the same change would make a behavioural change hard to attribute.

---

## Not our bug

### Tk cannot emit canvas bitmaps to PostScript on macOS

The canvas PostScript dump renders links, labels and network bars but omits
every icon. Pinning foreground and background to concrete colours, the
technique the editor's own PostScript path uses for backgrounds, does not
help. This limits the offscreen render path, which is otherwise the way to
produce map images without mapping a window. Worked around by capturing the
real window.

---

## Fixed

| # | Issue | Fixed in |
|---|---|---|
| F1 | `netdb ip range` looped forever on LP64: a 32-bit counter compared against a bound computed from a 64-bit complement | `netdb ip range` rewritten in 32-bit arithmetic |
| F2 | `knownBug64BitArchitecture` tested only for amd64 and x86_64, so the guard silently stopped working on arm64 and known-bad tests ran | replaced with a pointer-size check |
| F3 | ICMP needed root because `nmicmpd` opened a raw socket unconditionally | falls back to an unprivileged datagram socket; echo, ttl and traceroute all work as a normal user |
| F4 | `inappropriate device for ioctl` reported for ICMP failures: a stale errno read after the helper had already exited | reports the real cause |
| F5 | Right-click did nothing and objects could not be dragged: X11 button numbers hardcoded, but Aqua numbers them differently | platform-aware bindings; left-drag now moves |
| F6 | A null editor pointer segfaulted the whole application on an ordinary scripting mistake | guarded |
| F7 | Scanning tools froze for 75 seconds per host: blocking connects with no timeout, at six call sites | bounded async connect helper |
| F8 | `TCP Services` walked 4935 services with blocking connects, about 102 hours for one filtered host | concurrent batches with a bounded timeout, 41.7s worst case |
| F9 | A test used `192.169.173.173` as an unreachable address; it answers today | uses the reserved `192.0.2.1` |
| F10 | A test required every host alias to resolve forward, which the macOS resolver breaks by returning a PTR name as an alias | skips aliases that do not resolve |
| F11 | `l.smx` hardcoded a binary name that no longer exists | uses the running interpreter |
| F12 | Show Toolbar did not draw the toolbar until some later event: the geometry manager defers its work to an idle callback, so the frame and everything in it stayed unmapped after the toggle returned | `update idletasks` after the toggle. Measured on both 8.6.18 and 9.0.4, so not a Tcl 9 regression |
