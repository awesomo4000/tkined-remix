# 01 — Object model

Everything on a tkined map is an *object*. Objects have a type, a stable
identity, a set of typed fields, and an open-ended attribute dictionary.
The map is a flat collection of objects plus two relationships: grouping
(parent/member) and linking (source/destination).

## Type system

There are 15 usable object types. Types are a **bit mask**, not an
enumeration: operations declare the set of types they accept as a bitwise
union, and queries can match several types at once. A reimplementation does
not have to keep the bit representation, but it does need the underlying
idea of "this operation applies to this set of types".

| Type | Purpose |
|---|---|
| `NODE` | A host or device. The thing you normally think of as a machine. |
| `NETWORK` | A network segment, drawn as a bar that nodes attach to. |
| `LINK` | A connection between two objects. |
| `GROUP` | A named collection of objects that can collapse to one icon. |
| `TEXT` | A free text annotation on the canvas. |
| `IMAGE` | A background image, used for maps and floor plans. |
| `REFERENCE` | A pointer to another map file, so maps can nest. |
| `STRIPCHART` | A time series display attached to a monitored value. |
| `BARCHART` | A bar display attached to a monitored value. |
| `GRAPH` | A general XY plot. |
| `LOG` | A scrolling text window that tools write output into. |
| `INTERPRETER` | A running tool process. See document 02. |
| `MENU` | A menu contributed by a tool. |
| `EVENT` | An event registration. |
| `DATA` | A container for values with no visual form of its own. |

`NONE` and `ALL` also exist as the empty and full masks.

## Fields

These are the fields a reimplementation needs to carry. They are the
portable subset of the object record.

| Field | Applies to | Meaning |
|---|---|---|
| `type` | all | One of the types above. Immutable after creation. |
| `id` | all | Unique identity within a map. See *Identity* below. |
| `name` | all | Human readable name. |
| `address` | see matrix | Network address. Semantically distinct from `name`. |
| `oid` | see matrix | An externally assigned identifier, for tools that need their own key. |
| `x`, `y` | positioned types | Position, floating point. |
| `icon` | see matrix | Which icon represents the object. |
| `color` | see matrix | Display colour. Also used to convey state. |
| `font` | see matrix | Label font. |
| `label` | see matrix | *Which* field to display as the label, not the text itself. See below. |
| `text` | `TEXT` | The annotation content. |
| `parent` | all | The enclosing `GROUP`, if any. |
| `members` | `GROUP` | The contained objects. |
| `src`, `dst` | `LINK` | The two endpoints. |
| `links` | `NODE`, `NETWORK` | The links attached to this object. |
| `points` | `NETWORK`, `LINK` | Vertex list for the drawn shape. |
| `size` | most | Occupied extent. |
| `action` | see matrix | A command bound to the object. |
| `scale` | charts | Vertical scaling factor. |
| `values` | charts, `DATA` | The numeric series being displayed. |
| `attributes` | all | Arbitrary string key to string value dictionary. |

Boolean state: `selected`, `collapsed` (groups), `loaded` (came from a
file rather than being created live), `incomplete`, `timeout`.

### `label` is a selector, not a string

This trips people up. Setting an object's label does not set display text.
It selects **which field** is displayed: the name, the address, or a named
attribute. Clearing it displays nothing. The consequence is that when the
underlying field changes, the label follows automatically, and a
reimplementation should preserve that indirection rather than copying the
text at the time the label is set.

### Attributes carry the domain data

The fixed fields are deliberately few. Everything a tool learns about an
object -- vendor, uptime, interface list, whatever -- goes into the
attribute dictionary under a name of the tool's choosing. Attributes are
also what the label selector can point at, so a tool can make its own
findings visible without the core knowing anything about them. This is the
main extension mechanism for data, as the protocol is for behaviour.

## Capabilities by type

Extracted mechanically from the method dispatch table. This is the
authoritative statement of which operations apply to which type.

Operations every type supports: `attribute`, `canvas`, `create`, `delete`, `editor`, `id`, `items`, `name`, `parent`, `retrieve`, `type`.

| operation | Nod | Grp | Net | Lnk | Txt | Img | Ref | Str | Bar | Grf | Log | Int | Mnu | Evt | Dat |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `action` | x | x | x | x | x | x | x |  |  |  |  |  |  |  |  |
| `address` | x | x | x |  |  |  | x | x | x | x | x |  |  |  |  |
| `append` |  |  |  |  |  |  |  |  |  |  | x |  |  |  |  |
| `bell` |  |  |  |  |  |  |  |  |  |  |  |  |  | x |  |
| `clear` |  |  |  |  |  |  |  | x | x | x | x |  |  |  |  |
| `collapse` |  | x |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `collapsed` |  | x |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `color` | x | x | x | x | x | x | x | x | x | x |  |  |  |  |  |
| `dst` |  |  |  | x |  |  |  |  |  |  |  |  |  |  |  |
| `dump` | x | x | x | x | x | x | x | x | x | x | x | x |  |  | x |
| `expand` |  | x |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `flash` | x | x | x | x | x | x | x | x | x |  |  |  |  |  |  |
| `font` | x | x | x |  | x |  | x | x | x |  |  |  |  |  |  |
| `hyperlink` |  |  |  |  |  |  |  |  |  |  | x |  |  |  |  |
| `icon` | x | x | x |  |  |  | x |  |  | x | x |  |  |  |  |
| `interpreter` |  |  |  |  |  |  |  |  |  |  | x |  | x |  |  |
| `jump` |  |  |  |  |  |  |  | x |  |  |  |  |  |  |  |
| `label` | x | x | x |  |  |  | x | x | x | x |  |  |  |  |  |
| `labelxy` |  |  | x |  |  |  |  |  |  |  |  |  |  |  |  |
| `links` | x |  | x |  |  |  |  |  |  |  |  |  |  |  |  |
| `lower` | x | x | x | x | x | x | x | x | x |  |  |  |  |  |  |
| `member` |  | x |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `move` | x | x | x | x | x | x | x | x | x |  |  |  |  |  |  |
| `oid` | x | x | x | x | x | x | x |  |  |  |  |  |  |  |  |
| `points` |  |  | x | x |  |  |  |  |  |  |  |  |  |  |  |
| `postscript` | x | x | x | x | x |  | x | x | x | x |  |  |  |  |  |
| `raise` | x | x | x | x | x |  | x | x | x |  |  |  |  |  |  |
| `scale` |  |  |  |  |  |  |  | x | x | x |  |  |  |  |  |
| `select` | x | x | x | x | x | x | x | x | x | x |  |  |  |  |  |
| `selected` | x | x | x | x | x | x | x | x | x | x |  |  |  |  |  |
| `send` |  |  |  |  |  |  |  |  |  |  |  | x |  |  |  |
| `size` | x | x | x | x | x | x | x | x | x |  |  |  |  |  |  |
| `src` |  |  |  | x |  |  |  |  |  |  |  |  |  |  |  |
| `text` |  |  |  |  | x |  |  |  |  |  |  |  |  |  |  |
| `ungroup` |  | x |  |  |  |  |  |  |  |  |  |  |  |  |  |
| `unselect` | x | x | x | x | x | x | x | x | x | x |  |  |  |  |  |
| `values` |  |  |  |  |  |  |  | x | x | x |  |  |  |  | x |

Note that `canvas`, `editor` and `items` appear in the universal list but
are **not** part of the portable model; see *Excluded baggage* below.

## Identity and lifecycle

- Ids are unique within a map and are assigned by the core on creation.
- Ids are the currency of the protocol: tools refer to objects by id and
  never hold a pointer or a handle.
- An id is opaque to tools. Nothing may be inferred from its form.
- Objects created by a tool and objects loaded from a file are
  indistinguishable afterwards except for the `loaded` flag.
- Deleting an object deletes the objects that depend on it: deleting an
  endpoint deletes its links, deleting a group deletes or reparents its
  members.

**Creation is two-phase in the original and should not be.** In this
implementation an object is created first and attached to an editor and a
drawing surface afterwards, and calling most operations in between
dereferences a null pointer and crashes the process. A reimplementation
should make an object valid on creation, with its owning map fixed at that
point.

## Grouping

A `GROUP` holds members and can be *collapsed* to a single icon or
*expanded* to reveal them. Groups may nest. Collapsing is a display state,
not a structural change: the members still exist and tools can still act on
them. Links that cross a collapsed group boundary are redrawn to terminate
on the group icon.

## The map file

A saved map is a sequence of protocol commands, in the same vocabulary
tools use, prefixed by a page declaration. Loading a map is replaying that
sequence. There is no separate parser: the file format *is* the protocol,
which is a property worth preserving because it makes maps scriptable and
diffable.

The shape, from a real generated map:

    ined page A4 landscape

    set node2 [ ined -noupdate create NODE ]
    ined -noupdate move $node2 410.00 390.00
    ined -noupdate icon $node2 machine.xbm
    ined -noupdate name $node2 10.26.161.71
    ined -noupdate address $node2 10.26.161.71
    ined -noupdate attribute $node2 {mac address} 52:30:7:3c:51:73
    ined -noupdate label $node2 name

    set network0 [ ined -noupdate create NETWORK 0 0 130 0 ]
    ...
    set link2 [ ined -noupdate create LINK $node2 $network0 ]

Points to carry over:

- **`-noupdate` suppresses redraw** while loading, so the map is not
  repainted once per command. A reimplementation needs an equivalent
  batching flag or an explicit transaction.
- **Objects are referenced by variable**, so links can be written after
  their endpoints without a forward reference mechanism.
- **Order matters**: endpoints must precede the links that join them.
- The file is executable script in the original. That is a security
  consideration a reimplementation should drop: loading a map should not
  be able to run arbitrary code. Parse the command sequence instead of
  evaluating it.

### Known defect

Icon references do not survive a save/load cycle. The saver writes the
icon as a bare basename, discarding the path, and the loader cannot resolve
it, so reloaded maps fall back to default icons. A reimplementation should
store a stable icon identifier and resolve it at draw time.

## Excluded baggage

These exist in the implementation and should **not** be carried over:

| Excluded | Why | Do instead |
|---|---|---|
| `canvas`, `items` | Tk widget path and canvas item ids stored on the object | Keep presentation state out of the model; let the view own its own handles |
| `editor` | Back pointer to the owning editor, unset at creation | Make the owning map an immutable property set at construction |
| `font` as an X11 font name | Names like `fixed` are meaningless off X11 | A portable text style |
| `icon` as an X11 bitmap path | 1-bit XBM files, and only 19 are compiled in; every other name silently does nothing | A named icon in a themeable set, resolved at draw time, with unknown names an error |
| Tcl channel, command buffer, interpreter | Tool process plumbing stored on the object | Belongs to the transport, not the model |
| `queue` | Per-interpreter pending count | Belongs to the transport |
