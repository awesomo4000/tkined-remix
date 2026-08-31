# 05 — Layout algorithms

How tkined arranges a discovered network on the canvas. Two independent
subsystems, useful in different situations:

1. **Segment layout** — arrange the hosts attached to one network segment
   around its bar. Small, local, deterministic.
2. **Incremental graph layout** — arrange an arbitrary graph of nodes and
   groups with no segment to anchor to. Larger, and the interesting one.

Both operate on the object model of document 01 and reach the map through
the protocol of document 02, so neither assumes a particular renderer.

## Shared concepts

**Neighbours.** Adjacency is derived from links, not stored. To find the
neighbours of an object, walk its links and take whichever endpoint is not
the object itself. Links are undirected for layout purposes even though
they record a source and a destination.

**Degree classification.** The single most load-bearing idea in the whole
layout system. An object with exactly one link is a *leaf*; an object with
more than one is a *gateway*. This distinction drives placement order,
grouping, and the choice of placement strategy later on. It is cheap to
compute and it captures the thing that actually matters visually: leaves
can go anywhere, gateways are constrained by several relationships at once.

**Occupancy grid.** The canvas is modelled as a coarse matrix of cells.
Placing an object marks the cells its icon covers. Testing a candidate
position means checking the canvas bounds and then those cells. Bounds
failures are reported per edge, so the caller knows which direction it
overflowed rather than just that it failed.

**Extent tracking.** The bounding box of everything placed so far is
maintained as placement proceeds, so later decisions can be made relative
to the shape of the graph rather than the shape of the window.

**Icon half-extents.** Each object caches half its width and height, since
every bounds and collision test is expressed as centre plus or minus half.

## Subsystem 1 — segment layout

Given a network segment, place the hosts attached to it around its bar.

    procedure layout_segment(segment):
        centre  <- midpoint of the segment's bar
        hosts   <- neighbours(segment)
        leaves  <- hosts with exactly one link
        gateways<- hosts with more than one link
        layout_grid(leaves followed by gateways, centre)

Leaves are deliberately placed **first**, so they occupy the positions
nearest the segment and gateways end up further out where their other links
have room to leave. Ordering the input list is the whole mechanism; the
placement routine itself is oblivious.

    procedure layout_grid(objects, centre, grid_x, grid_y, columns):
        for each object, in order:
            every 2*columns objects, start a new pair of rows:
                move one row further above and one further below centre
                reset the horizontal pair to the centre column
            place the object at the current position
            alternate: above row -> below row
            when both rows at this column are used,
                step one column right, and one column left
                continue with the right column

The result fans outward from the centre in four directions at once: above
and below, left and right. It is not a raster scan. The visual effect is a
segment with its hosts distributed symmetrically around it rather than
trailing off to one side.

Defaults: horizontal spacing 65, vertical spacing 50, 8 columns per
row-pair.

## Subsystem 2 — grouping

Collapse each segment and its leaves into a single group object.

    procedure group_segments(selection):
        result <- []
        for each object in selection:
            if it is a node that still has links: skip it
            if it is not a segment: keep it in result, untouched
            else:
                members <- segment
                for each neighbour:
                    if it is a leaf: add it and its link to members
                    else:            keep it in result   # a gateway
                group <- create GROUP from members
                copy the segment's name, colour and font to the group
                give the group the bus icon, label it by name
                add group to result
        return result

The rule that makes this work: **leaves are absorbed, gateways are not**. A
gateway belongs to several segments, so putting it inside any one group
would misrepresent the topology. Leaving gateways at the top level means
the groups end up connected to each other through them, which is exactly
the abstraction you want — a map of segments joined by routers.

The returned list is deliberately a mix of new groups and leftover
gateways, and is what gets handed to the graph layout next.

## Subsystem 3 — incremental graph layout

Arranges nodes and groups that have no segment bar to hang from. Attributed
in the source to Sascha Bengsch; the comments are in German.

### Placement state

Every object carries a placement state:

| State | Meaning |
|---|---|
| 0 | not placed |
| 1 | provisionally claimed this round, position not yet decided |
| 2 | placed as a neighbour |
| 3 | placed as a seed |

State 1 matters: it stops an object being claimed twice while a round is
still deciding where its siblings go.

### Main loop

    procedure layout_graph(elements):
        while elements remain unplaced:
            seed <- unplaced element with the most links
            place_seed(seed)
            elements <- those still unplaced

Greedy, highest degree first. The consequence is that the busiest object in
each connected component becomes the centre it is drawn around, and
components are laid out one after another rather than all at once.

Isolated objects — zero links — are excluded from this loop entirely and
placed at the end by a separate pass, since there is nothing to arrange
them relative to.

### Seeding a component

    procedure place_seed(seed):
        anchors <- neighbours of seed already placed
        if anchors is non-empty:
            position <- centroid of anchors
            place seed near that centroid
        else:
            position <- centre of the canvas
            if occupied: search outward for free space
            move seed there, mark its cells
        mark seed as state 3
        update the graph extent
        place_neighbours(seed)

The two branches are the difference between continuing an existing drawing
and starting a fresh one. A component with no placed neighbours starts at
the canvas centre; anything reachable from what is already drawn is pulled
towards it.

### Choosing a strategy per neighbour

This is the heart of the algorithm and the part most worth carrying over.

    procedure split_neighbours(element):
        angular <- []
        central <- []
        for each unplaced neighbour n of element:
            anchors <- count of n's own neighbours already placed
            if anchors > 1: central.add(n)      # constrained
            else:           angular.add(n)      # only this element anchors it
            mark n as state 1
        return angular, central

**The number of already-placed anchors selects the strategy.** A neighbour
held by only the current element is free, so it is spread by angle around
that element. A neighbour held by two or more placed objects is already
constrained, so it is put at their average position instead — trying to
place it on a ring would fight the constraints and produce crossings.

This is a good rule because it is local, needs no global optimisation, and
degrades sensibly: a tree gets clean radial fans, a mesh gets its
cross-linked nodes pulled into the middle.

### Angular placement

Neighbours are laid on concentric rings around the element.

**Around a seed**, in rings of up to six:

- The first ring spreads evenly over a full turn. Two special cases: a
  single neighbour goes straight up; four neighbours are offset by an
  eighth of a turn so they sit diagonally rather than on the axes, which
  reads better.
- Each subsequent ring is rotated by 30 degrees relative to the previous
  one, so objects in different rings do not line up radially and occlude
  one another.

**Around a non-seed**, in groups of three, relative to the direction the
element was itself approached from:

| Count | Angles relative to incoming direction |
|---|---|
| 1 | straight ahead |
| 2 | plus and minus 30 degrees |
| 3 | minus 36 degrees, straight ahead, plus 36 degrees |

Placing relative to the incoming direction is what stops the drawing
doubling back on itself: growth continues away from where it came from, so
a tree unfolds outward instead of tangling near its root.

In both cases the ring radius starts at the base radius and grows by 0.8
of it per ring. The base radius defaults to 70 and is raised automatically
if any icon is larger, so the rings can never be tighter than the things
they hold.

### Central placement

    procedure place_central(element):
        position <- centroid of the element's already-placed neighbours
        if occupied: search outward for free space
        move element there, mark its cells

Straightforward, and correct precisely because the elements routed here are
the ones with several anchors.

### Collision handling

Every candidate position is tested against the canvas bounds and the
occupancy grid. On a clash, the search moves outward from the preferred
position until it finds free space. Failure to find any is propagated as an
error that aborts the layout rather than producing overlapping output.

### Parameters

| Parameter | Default | Controls |
|---|---|---|
| horizontal spacing | 65 | segment layout column spacing |
| vertical spacing | 50 | segment layout row spacing |
| columns | 8 | objects per row-pair before stepping out |
| radius | 70 | base ring radius, auto-raised to fit the largest icon |

## Reimplementation notes

**Keep:**

- Degree classification. Leaves and gateways behave differently and should
  continue to.
- Absorbing leaves into segment groups while leaving gateways outside. This
  is what produces a readable segment-and-router map.
- Anchor-count strategy selection. Local, cheap, and it degrades well.
- Placing relative to the incoming direction, so growth moves outward.
- Ring rotation between rings, which prevents radial occlusion.
- Placement being incremental and stable: previously placed objects are not
  disturbed, so a user's manual arrangement survives a re-layout of the
  rest. A force-directed algorithm would lose this, and it is the main
  reason not to reach for one.

**Reconsider:**

- The occupancy grid is tied to a fixed canvas with page dimensions. A
  modern implementation should treat the canvas as unbounded and use a
  spatial index rather than a matrix sized to the window.
- Bounds failures returning distinct codes per edge is a useful signal that
  is currently discarded by callers; it could drive canvas growth instead
  of an error.
- The angle tables are hardcoded constants for one, two, three, four and
  six neighbours. A general spread function would be shorter and cover the
  cases the tables miss.
- Aborting the whole layout when no free space is found is harsh. Growing
  the canvas is the obvious alternative.
- Nothing routes links. They are drawn straight and may cross both objects
  and each other; the algorithm avoids overlapping *icons* only. Edge
  routing is the largest missing capability.

**Open question.** The layout is deterministic given the same input order,
but the input order comes from selection order and link enumeration, so it
is not obviously stable across runs. Worth pinning down in a
reimplementation: a stable sort on a durable key would make layouts
reproducible.
