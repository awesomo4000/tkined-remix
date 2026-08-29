# 02 — The tool protocol

This is the boundary between the map and the things that act on it. It is
the single most reusable idea in tkined and the reason a reimplementation
can put the user interface and the logic in different languages, processes
or machines.

## The shape of it

A *tool* is an ordinary program. It is not linked into the editor, shares
no memory with it, and can be written in any language. It talks to the core
over a line-oriented connection, referring to objects by opaque id.

The core owns the map and its presentation. The tool owns the domain logic:
how to sweep a network, what to do with an SNMP reply, how to lay things
out. Neither knows the other's internals.

Two consequences worth keeping:

- **Tools can crash without taking the map with them.** Isolation is free.
- **Tools can run somewhere else.** Nothing in the protocol assumes the two
  ends share a machine, only that a byte stream connects them.

## Transport

Two transports exist, chosen by the tool at startup:

1. **Standard input and output.** The default. The core spawns the tool as
   a child process and speaks over its pipes.
2. **TCP.** If an environment variable naming a port is set, the tool opens
   a TCP connection to that port instead. The core sets that variable when
   it spawns the tool.

The TCP client **hardcodes the loopback address**. Only the port is
configurable. This looks like a limitation and is better read as a
constraint worth keeping: it means a remote tool has to be reached through
a forwarded connection rather than by exposing the port.

## Framing

- Line oriented. One command per line, terminated by a newline.
- Arguments containing spaces are wrapped in braces.
- Newlines inside an argument are escaped so a command is always one line.
- Replies come back on the same channel.

**Flow control.** The tool reports its pending queue depth to the core with
a `queue` message. This exists so a tool that is generating work faster
than the core can draw does not run away. A reimplementation over a modern
transport still needs backpressure; do not assume the transport provides it.

## Security

The protocol has **no authentication and no encryption**. Anything that can
connect can create, modify and delete objects, and can drive the user
interface. In the original this is contained by the loopback restriction
and by the core spawning its own children.

For a reimplementation this is the single most important thing to get
right. The protocol should be treated as a trusted local channel only:
bind to loopback, verify that you are bound to loopback, and carry it
between machines inside an authenticated tunnel rather than adding
credentials to the protocol itself.

## Command catalog

62 commands. Extracted from the reference documentation; the grouping is
editorial, the signatures are not. Square brackets mark optional arguments.

Commands that take a value are also queries: invoking one without the
optional value returns the current setting rather than changing it. This
halves the command count and is worth preserving.

### Object lifecycle

    ined create BARCHART
    ined create GRAPH
    ined create GROUP [ida idb ...]
    ined create IMAGE filename
    ined create INTERPRETER name
    ined create LINK id1 id2 [x1 y1 ...]
    ined create LOG
    ined create MENU name command1 [command2 ...]
    ined create NETWORK [x1 y1 x2 y2 ...]
    ined create NODE
    ined create REFERENCE
    ined create STRIPCHART
    ined create TEXT string
    ined delete id
    ined retrieve [id]
    ined dump id
    ined id id
    ined type id
    ined parent id

### Properties

    ined name id [string]
    ined address id [string]
    ined oid id [number]
    ined icon id [name]
    ined color id [colorname]
    ined font id [fontname]
    ined label id
    ined label id address
    ined label id attribute
    ined label id clear
    ined label id name
    ined text id [text]
    ined attribute id attribute [string]
    ined move id [x y]
    ined scale id [value]
    ined values id [number ...]
    ined size
    ined size id

### Structure

    ined members id [list]
    ined links id
    ined collapse id
    ined expand id
    ined collapsed id

### Selection

    ined select
    ined select id
    ined unselect id
    ined selected id

### Output and feedback

    ined append id text
    ined clear id
    ined flash id seconds
    ined jump id [number]
    ined hyperlink id cmd text
    ined browse title text

### User dialogs

    ined acknowledge line [line ...]
    ined confirm line [line ...] buttonlist
    ined request title requestlist buttonlist
    ined list title list buttonlist
    ined openfile title [file]
    ined savefile title [file]

### Tool and session

    ined send id cmd
    ined restart [command]
    ined trace callback
    ined page [size [orientation]]

Total commands: 62

## Notes on particular commands

**`create`** returns the id of the new object. Every other command takes
ids as input. This is the only way a tool learns an id for an object it
made.

**`retrieve`** with no argument returns the current selection; with an id
it returns that object's full state. It is how a tool discovers what the
user has chosen to act on, which is the normal way tools are invoked.

**`trace`** registers a callback so a tool is notified of changes it did not
make. This is what makes multiple concurrent tools viable rather than each
assuming it is the only writer.

**`send`** passes a command to another tool, so tools can compose.

**Dialog commands** (`acknowledge`, `confirm`, `request`, `list`,
`openfile`, `savefile`, `browse`) let a tool drive the user interface
without owning a window. The core renders them. This is why tools need no
graphics toolkit at all, and it is the main reason the split works as well
as it does.

A reimplementation targeting a browser should keep this property: the tool
describes *what to ask*, the interface decides *how to render it*. Do not
let tools emit markup.

**`page`** sets the canvas size and orientation. It is print-derived and
the weakest part of the model. A modern implementation should treat the
canvas as unbounded and make export a separate concern.

## What a reimplementation must decide

These are underspecified in the original and need a decision rather than a
transcription:

- **Errors.** The original mostly reports failures as empty results. A new
  protocol should distinguish "no such object" from "not permitted" from
  "malformed".
- **Ordering and atomicity.** There is no transaction boundary. The
  `-noupdate` flag used when loading a map is a redraw suppression hint,
  not a transaction. Batched mutation deserves a real construct.
- **Events.** `trace` is a callback registration whose delivery guarantees
  are not documented. Decide whether change notification is reliable,
  ordered, and whether a tool can miss events while busy.
- **Framing.** Brace quoting with escaped newlines is workable but ad hoc.
  A length-prefixed or JSON framing removes a class of quoting bugs.
