# 04 — Discovery algorithms

How tkined turns a network prefix into a map: which hosts exist, what
segments they sit on, which of them route between segments, and what links
those facts imply.

Input is one or more network prefixes. Output is a set of node, network and
link objects created through the protocol of document 02, ready for the
layout of document 05.

## The pipeline

Discovery runs as an ordered pipeline. Each stage enriches a shared table
keyed by object id, and later stages depend on earlier ones.

| Stage | Produces | Depends on |
|---|---|---|
| 1. Host sweep | the set of live hosts | the input prefix |
| 2. Route tracing | a path to every host | stage 1 |
| 3. Netmask query | a netmask per host | stage 1 |
| 3.5. SNMP probe | identity and vendor per host | stage 1 |
| 4. Reply-address query | the address each host answers *from* | stage 1 |
| 5. Network inference | the set of segments | stages 1, 3 |
| 6. Gateway detection | which hosts route | stages 2, 4, and naming |
| 7. Link inference | node-to-segment attachment | stages 5, 6 |

The staging matters: everything expensive is batched across all hosts at
once rather than done per host, which is what makes the whole thing
tractable.

## Stage 1 — host sweep

    procedure sweep(prefix):
        if prefix has three octets:
            probe every address .1 through .254 in one parallel batch
            every responder becomes a node
        else if prefix has two octets:
            for each of 256 third octets: sweep(prefix.octet)
        else if prefix has one octet:
            for each of 256 second octets: sweep(prefix.octet)

The unit of work is a 24-bit prefix, swept as a **single parallel batch** of
254 probes. Shorter prefixes recurse into /24-sized chunks rather than
widening the batch.

Two consequences worth noting. The sweep never probes the all-zeros or
all-ones host address, which is correct for a classful /24 but wrong for
any other prefix length. And recursing from a one- or two-octet prefix
means 16 million or 65 thousand probes respectively, which is not usable in
practice: the recursion exists but only the /24 case is realistic.

## Stage 2 — route tracing

All routes are traced **concurrently**, advancing every target one hop per
round rather than completing one target at a time.

    procedure trace_all(targets):
        routes  <- empty path per target
        pending <- targets
        for ttl from 1 while pending is non-empty and ttl <= limit:
            responses <- probe(pending, ttl)     # one batch, all targets
            for each target and its response:
                append the responding hop to that target's route
                if the hop is not the target itself:
                    keep the target pending
            pending <- the still-incomplete targets
        return routes

A target drops out when the responding hop equals the target, meaning the
path is complete. The cost is bounded by the longest path, not the number
of targets, which is what makes tracing hundreds of hosts practical.

**Intermediate hops become nodes.** Anything appearing in a path that was
not found by the sweep is added to the map. This is how routers outside the
swept prefix get discovered, and it is why tracing must precede network
inference.

## Stage 3 — netmask query

Each host is asked for the netmask of the interface it was reached on,
batched 255 at a time. This is the only source of subnet information;
without it stage 5 can only fall back to classful assumptions.

**This stage needs a privileged socket.** Address mask requests cannot be
sent on an unprivileged datagram ICMP socket, so running without the raw
socket capability leaves every netmask unknown and degrades network
inference to classful guessing. A reimplementation should either obtain the
capability or get subnet information another way, for example from SNMP,
rather than silently producing a worse map.

## Stage 3.5 — SNMP probe

Every host is queried for its system description and object identifier, all
requests issued together and collected by callback. The results identify
the vendor and model, which drives icon selection and gives the operator
something more useful than an address. Failure is expected and not an
error: most hosts do not answer.

## Stage 4 — reply-address query

Each host is probed in a way that reveals the source address it *answers
from*, which is not necessarily the address that was probed. A host that
replies from a different address has more than one interface. This is a
cheap and reliable multi-homing signal that costs one extra batched round.

## Stage 5 — network inference

    procedure infer_networks():
        table <- {}
        for each node:
            skip loopback addresses
            classful <- the class A, B or C network of the node's address
            record classful in table with its natural mask
            if the node's netmask is known:
                if the netmask is wider than the classful network:
                    warn: the netmask is inconsistent, skip this node
                subnet <- network address of (node address, node netmask)
                record subnet in table with that netmask
        validate(table)
        create a network object per surviving entry

Two networks are therefore proposed per node: the classful one it belongs
to by address, and the subnet implied by its own netmask.

### Validation by majority vote

Misconfigured hosts invent subnets that do not exist, so proposals are
tested before being accepted.

    procedure validate(table):
        order networks from most specific netmask to least
        assign each node to the first network it belongs to   # most specific wins
        for each network:
            agree    <- nodes whose own netmask yields this network
            disagree <- nodes whose netmask yields something wider
            unknown  <- nodes with no netmask
            if disagree > agree:
                ask the operator whether to discard this network

The heuristic is that a subnet is real if the hosts on it agree that it is.
Ordering most-specific-first matters: a node must be claimed by the
tightest network containing it, otherwise every node would land in its
classful network and no subnet would ever accumulate evidence.

Asking rather than deciding is a reasonable choice for an ambiguous signal,
though it makes unattended discovery impossible. A reimplementation should
keep the vote and make the response configurable.

## Stage 6 — gateway detection

Three independent signals, combined:

1. **Path position.** Any host appearing as a non-final hop in some traced
   route is forwarding traffic, and is therefore a gateway.
2. **Reply-address mismatch.** A host that answers from a different address
   than the one probed has multiple interfaces. Both addresses are recorded
   as belonging to the same gateway.
3. **Name agreement.** Interfaces of the same router frequently resolve to
   the same name, so addresses sharing a reverse-DNS name are treated as
   one device.

Signals two and three are what merge several addresses into a single
multi-homed object instead of leaving a router drawn as several unrelated
hosts. Using three weak independent signals rather than one strong one is
sound: each fails on some equipment, and they rarely fail together.

## Stage 7 — link inference

    procedure infer_links():
        order networks from most specific netmask to least
        for each node:
            attach it to the first network it belongs to
        for each gateway:
            attach it to every network any of its addresses belongs to

Ordinary hosts get exactly one attachment, so they become leaves. Gateways
get one per interface, so they become the objects with degree greater than
one. This is precisely the leaf-versus-gateway distinction that the layout
in document 05 depends on, which is why discovery and layout compose so
well: discovery produces the degree structure that layout reads.

## Address helpers

| Helper | Purpose |
|---|---|
| class of address | Classful A, B, C, D or loopback from the first octet |
| network of (address, mask) | Bitwise and, per octet |
| membership test | Whether an address falls inside a network under a mask |
| mask comparison | Orders netmasks by specificity |

### Defect: the network address helper drops zero octets

Verified by running it:

| Address | Mask | Produced | Correct |
|---|---|---|---|
| `10.26.166.175` | `255.255.224.0` | `10.26.160` | `10.26.160.0` |
| `192.168.1.50` | `255.255.255.0` | `192.168.1` | `192.168.1.0` |
| `172.16.0.9` | `255.255.0.0` | `172.16` | `172.16.0.0` |
| `10.0.5.3` | `255.255.255.0` | **`10.5`** | `10.0.5.0` |

The helper appends an octet only when it is non-zero. Dropping *trailing*
zeros yields a prefix rather than a dotted quad, which the sweep happens to
want, so the bug is partly load-bearing. Dropping an *interior* zero is
simply wrong: the remaining octets shift left and the network is
misidentified. Every `10.0.x.x` network is affected, and comparisons
against such a value silently fail rather than erroring.

A reimplementation should compute network addresses as full 32-bit values
and format prefixes separately where a prefix is what is wanted.

## Reimplementation notes

**Keep:**

- Batching every expensive operation across all hosts. It is the difference
  between minutes and hours.
- Concurrent traceroute bounded by path length rather than target count.
- Promoting intermediate hops to nodes, which discovers routers outside the
  swept range.
- Multiple independent gateway signals rather than one.
- Majority validation of inferred subnets.
- Most-specific-network-wins for attachment, which produces the degree
  structure the layout depends on.

**Reconsider:**

- **Classful addressing is obsolete.** Class A, B, C and D assumptions run
  through inference. Real networks are CIDR and a reimplementation should
  work in prefix lengths throughout, treating the classful network as at
  most a weak prior.
- The sweep skips the first and last address of the range, which is correct
  only for a /24.
- Recursing over class A or B prefixes is not viable. Prefix length should
  be an explicit parameter with a refusal above some size, not a silent
  16-million-probe loop.
- ICMP-only liveness misses anything that filters echo, which today is
  most things. TCP or ARP probing should supplement it; ARP in particular
  is reliable on the local segment and needs no privilege.
- Netmask discovery depending on a privileged socket is fragile; prefer
  SNMP or routing information where available.
- Blocking the pipeline on an operator prompt makes unattended runs
  impossible.

**Note on scale.** A sweep is active scanning. It is loud, it takes as long
as the slowest timeout, and on a monitored network it looks like
reconnaissance. Rate limiting and an explicit bound on the address count
are worth building in rather than leaving to the operator.
