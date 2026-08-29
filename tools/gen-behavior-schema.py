#!/usr/bin/env python3
"""Regenerate the machine-readable behaviour specs from the source tree.

The capability matrix and the command catalog in specs/behavior/ are
extracted mechanically rather than transcribed, so they cannot drift away
from the code. Re-run this after touching the object dispatch table or the
protocol documentation:

    python3 tools/gen-behavior-schema.py
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "specs", "behavior", "schema")

TYPES = ["NODE", "GROUP", "NETWORK", "LINK", "TEXT", "IMAGE", "REFERENCE",
         "STRIPCHART", "BARCHART", "GRAPH", "LOG", "INTERPRETER", "MENU",
         "EVENT", "DATA"]

# Fields that exist only because the implementation is Tcl/Tk.
EXCLUDED = ["canvas", "items", "editor"]


def capabilities():
    """Which operations apply to which object types, from the dispatch table."""
    src = open(os.path.join(ROOT, "tkined/generic/tkiObjects.c")).read()
    entries = re.findall(
        r'\{\s*((?:TKINED_[A-Z]+\s*\|?\s*)+),\s*"([a-z]+)",\s*m_\w+\s*\}', src)
    if not entries:
        sys.exit("no dispatch table entries found; did tkiObjects.c change shape?")
    caps = {}
    for tset, name in entries:
        ts = set(re.findall(r'TKINED_([A-Z]+)', tset))
        if "ALL" in ts:
            ts = set(TYPES)
        caps.setdefault(name, set()).update(t for t in ts if t in TYPES)
    return {k: sorted(v) for k, v in sorted(caps.items())}


def commands():
    """The protocol command surface, from the reference documentation."""
    raw = subprocess.run(
        ["grep", "-E", r'^\.B "?ined ', os.path.join(ROOT, "tnm/doc/ined.n")],
        capture_output=True, text=True).stdout
    sigs = set()
    for line in raw.splitlines():
        s = line.replace(".B ", "", 1).strip().strip('"')
        s = re.sub(r'\\f[IRB]', '', s).replace("\\", "").strip()
        if s:
            sigs.add(s)
    if not sigs:
        sys.exit("no command signatures found; did ined.n change shape?")
    out = []
    for s in sorted(sigs):
        parts = s.split()
        out.append({"verb": parts[1], "signature": s,
                    "arguments": parts[2:], "queryable": "[" in s})
    return out


def matrix_markdown(caps):
    """The human-readable capability table used in 01-object-model.md."""
    short = {t: t[:3].title() for t in TYPES}
    universal = [n for n in caps if all(t in caps[n] for t in TYPES)]
    lines = ["Operations every type supports: "
             + ", ".join("`%s`" % n for n in sorted(universal)) + ".", ""]
    lines.append("| operation | " + " | ".join(short[t] for t in TYPES) + " |")
    lines.append("|---|" + "---|" * len(TYPES))
    for name in sorted(caps):
        if name in universal:
            continue
        cells = ["x" if t in caps[name] else "" for t in TYPES]
        lines.append("| `%s` | " % name + " | ".join(cells) + " |")
    return "\n".join(lines)


def main():
    caps = capabilities()
    cmds = commands()

    schema = json.load(open(os.path.join(OUT, "object-model.schema.json")))
    schema["x-excluded-implementation-fields"] = EXCLUDED
    json.dump(schema, open(os.path.join(OUT, "object-model.schema.json"), "w"),
              indent=2)
    open(os.path.join(OUT, "object-model.schema.json"), "a").write("\n")

    proto = json.load(open(os.path.join(OUT, "tool-protocol.json")))
    proto["commandCount"] = len(cmds)
    proto["commands"] = cmds
    proto["capabilitiesByOperation"] = caps
    proto["objectTypes"] = TYPES
    json.dump(proto, open(os.path.join(OUT, "tool-protocol.json"), "w"), indent=2)
    open(os.path.join(OUT, "tool-protocol.json"), "a").write("\n")

    open(os.path.join(OUT, "capability-matrix.md"), "w").write(
        matrix_markdown(caps) + "\n")

    print("%d commands, %d operations across %d types"
          % (len(cmds), len(caps), len(TYPES)))


if __name__ == "__main__":
    main()
