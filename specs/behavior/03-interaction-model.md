# 03 — Interaction model

How a person manipulates a map: choosing tools, selecting, moving,
annotating, and reaching the commands that tools contribute.

This is where most of the *feel* of tkined lives, and where the most
Tcl/Tk-specific detail has to be stripped away to leave the behaviour.

## Modal tools

The canvas is modal. One tool is active at a time, chosen from a toolbox,
and it owns the meaning of a press and drag. Seven tools exist: select,
resize, text, node, network, link and reference. A group tool exists in the
source but is disabled.

Switching tools resets to a clean slate:

    procedure activate(tool):
        reset the pointer to the default shape
        discard all transient canvas artefacts
            (rubber band, in-progress shapes, resize handles)
        clear every press, drag, release and motion binding
        mark the tool's toolbox button as active
        rebind only the canvas-wide gestures (scroll)
        let the tool install its own bindings

The important property is that a tool never has to undo another tool's
bindings, because activation always starts from nothing. Modes that
partially overlap are a common source of bugs and this design avoids it.

**Reimplementation note.** Modality is worth keeping for creation tools,
where the pointer genuinely means something different, but the select and
move distinction is better handled by context, as described under *Moving*
below.

## Hit testing

    procedure find(x, y, acceptable_types):
        candidate <- topmost item at (x, y)
        loop:
            if candidate lies within a small tolerance box around (x, y):
                if it is a label and labels are acceptable: return it
                if its type is acceptable: return it
            candidate <- next item outward in z-order
            if we have wrapped to the first candidate: return nothing

Two details worth carrying over. The search has a **tolerance** of a few
pixels rather than requiring an exact hit, which matters for thin objects
like links. And it **walks the z-order** rather than taking only the
topmost item, so a wanted object is still reachable when an unwanted one
overlaps it.

Labels are hit-testable as first-class targets, so clicking a name selects
its object.

## Selection

Selection is **toggling, not replacement**. This is the largest behavioural
difference from what a modern user expects and needs a deliberate decision.

    on click:
        target <- object under the pointer
        if target is selected: deselect it
        else:                  select it

    on rubber band release:
        for every object fully enclosed by the band:
            if selected: deselect it
            else:        select it

Consequences of the current behaviour:

- Clicking an object never clears the rest of the selection.
- Dragging a band across an already-selected group **deselects** it.
- There is no single gesture meaning "select exactly this".

The band uses **full enclosure**, not intersection, so an object clipped by
the edge of the band is not affected. The pointer shape changes to indicate
which corner the band is growing from, which is a nice touch worth keeping.

**Reimplementation note.** Toggle-everywhere is defensible for a diagramming
tool but surprising today. The conventional split is: plain click replaces
the selection, modifier-click toggles, plain band replaces, modifier-band
adds. If that change is made, say so explicitly, because scripts and muscle
memory depend on the old behaviour.

**Defect.** When several objects lie under the pointer, the click handler
keeps the **last** candidate it encounters rather than the topmost, so which
object toggles depends on internal drawing order rather than what is
visually on top.

## Moving

Moving is a two-stage operation: a press decides whether a move is possible
and *arms* it, and only then does dragging translate anything.

    on press:
        if the pointer is over an object:
            arm a move, selecting that object if nothing relevant is selected
        else:
            begin a rubber band

    on drag:
        if a move is armed: translate the whole selection by the delta
        else:               grow the rubber band

    on release:
        commit the move, or apply the band's selection change

The whole selection moves, not just the object under the pointer, which is
what makes moving a group meaningful.

**Reimplementation note.** Deciding between move and band from *what is
under the pointer* is better than making them separate modes, and is how
this implementation now behaves. The risk to avoid is having two pieces of
code independently decide whether a move is possible: if the press handler
and the move handler disagree, a press is treated as a move that then does
nothing. That is an open defect, recorded as B6.

## Context menu

The richest mechanism in the interaction model, and the one most worth
carrying over intact.

A right-click on an object builds a menu from **two independent sources**:

1. **Core entries.** Attribute creation, deletion and editing, plus label
   selection. Gated by type: link objects, which carry less state, get a
   reduced set.

2. **Tool-contributed entries.** Every running tool may register a named
   menu. For each such menu, the object is asked for an attribute named
   after it; if the object does not have one, the map's default for that
   name is used. That attribute holds a **list of command names**. The menu
   shows the intersection of the commands the tool offers and the commands
   the attribute names. If the intersection is empty the menu is omitted
   entirely.

Choosing an entry sends that command name to the owning tool, along with
the object it was invoked on.

    procedure build_menu(object):
        add core entries appropriate to the object's type
        for each registered tool menu:
            allowed <- object.attribute(menu.name)
                       or map.default_for(menu.name)
            if allowed is empty: skip this menu
            commands <- menu.items intersect allowed
            if commands is empty: skip this menu
            add a submenu invoking each command on this object

Why this is good design:

- **The core knows nothing about any tool.** It never enumerates commands
  or types; it intersects two lists.
- **Objects advertise their own capabilities** through ordinary attributes,
  so discovery can mark a router as supporting router commands simply by
  setting an attribute, using the same mechanism it uses for every other
  fact it learns.
- **Defaults are map-wide with per-object override**, so the common case
  needs no per-object data at all.
- Menus disappear when they would be empty, so the menu reflects what is
  actually applicable rather than showing disabled entries.

This is the interaction counterpart to the protocol: the protocol decouples
*behaviour*, and this decouples *what the user can invoke*.

## Object creation

The node, network, link and reference tools each create an object. Nodes
appear where clicked. Networks and links are drawn: press to start, drag to
extend, with additional vertices accumulated so both are polylines rather
than single segments.

Links are the only tool that must resolve **two** objects, one at each end,
using the same hit testing described above.

## Annotation

Text objects are free annotation on the canvas, edited in place: the tool
places a caret, keystrokes accumulate, and the object is committed when
focus leaves. This is the "annotate the whole canvas" capability, and it is
independent of the network model, which is why it survives a
reimplementation unchanged.

## Resize

Networks and charts can be resized by dragging, with a dedicated tool and
per-type handlers. Nodes cannot: their size follows their icon.

## Canvas panning

Dragging with a modifier scrolls the canvas rather than moving anything.
The pointer changes shape to indicate panning. This is bound canvas-wide
rather than per tool, so it works in every mode.

## Pointer buttons

The original binds X11 button numbers directly, which is wrong on other
window systems: the same physical button has a different number under
Aqua, where the context menu button is 2 rather than 3. This has been
fixed here by binding the platform's context-menu event rather than a
number, and by mapping the middle and right roles per platform.

A reimplementation should describe interactions by **role** -- primary,
secondary, middle -- and never by number.

## Reimplementation summary

**Keep:**

- Clean-slate tool activation.
- Hit testing with tolerance that walks the z-order.
- Labels as hit targets.
- Move versus band decided by what is under the pointer.
- Moving the whole selection.
- The context menu intersection mechanism, unchanged. It is the best idea
  here.
- In-place text annotation, independent of the network model.

**Change:**

- Toggle-everywhere selection, if modern conventions are wanted.
- The topmost-object defect in click handling.
- Button roles rather than numbers.
- Full-enclosure-only rubber band; intersection is usually expected.
