# Behavioural extraction

These documents describe **what tkined does**, independently of Tcl, Tk and
X11, so the behaviour can be reimplemented in another system entirely.

They are *descriptive*. They record the model, the algorithms and the
interaction rules as they actually are in this source tree, with the
implementation baggage stripped out. Proposals for a new architecture
belong in a separate target spec, not here, so that the extraction stays
usable even if the target changes.

## Why this is tractable

tkined already separates the user interface from the logic. Tools are not
linked into the editor; they are **separate processes** that speak a
line-oriented protocol over a pipe or a TCP connection. That protocol has
62 commands and is the entire boundary between "the map and its
presentation" and "the things that discover, monitor and manipulate it".

A reimplementation therefore has a natural seam: keep the protocol, and the
two halves can be written in different languages, on different machines.

## Documents

| # | Document | Covers |
|---|---|---|
| 01 | [Object model](01-object-model.md) | The 15 object types, their fields, capabilities, identity and the map file format |
| 02 | [Protocol](02-ined-protocol.md) | The UI/logic boundary: transport, framing, all 62 commands |
| 03 | Interaction model | Selection, dragging, grouping, annotation, context menus *(to be written)* |
| 04 | Discovery algorithms | Sweep, netmask inference, topology, SNMP enrichment *(to be written)* |
| 05 | [Layout algorithms](05-layout-algorithms.md) | Segment layout, grouping, incremental graph placement |

Machine-readable companions live in [`schema/`](schema/).

## Conventions

- **Ground truth is the source, not the manual.** Where a document states a
  table or a signature, it was extracted mechanically from the code and can
  be regenerated. Where behaviour was measured, the measurement is given.
- **Baggage is called out explicitly.** Anything that only exists because
  the implementation is Tcl/Tk is listed as excluded, with a note on what a
  reimplementation should do instead.
- Pseudocode is language-neutral and avoids Tcl idioms.
- Open questions and places where the original behaviour is unclear or
  looks wrong are marked, rather than smoothed over.
