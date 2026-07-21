---
title: A Field Guide to Object-Spatial Programming
date: 2026-07-10
tags: jac, languages, osp
summary: Objects hold state. Graphs hold structure. Walkers move computation to where the data lives — a primer on the programming model at the heart of Jac.
---

Most programs move data to computation: you fetch rows, hydrate objects, and
pass them through functions. Object-spatial programming (OSP) inverts that —
you lay your data out as a *topology* and send computation traveling through
it.

## Three primitives

OSP adds three constructs to the familiar object-oriented toolbox:

- **Nodes** — objects that live at a location in a graph
- **Edges** — first-class, typed relationships between nodes
- **Walkers** — mobile computation that traverses nodes and edges

```jac
node Person {
    has name: str;
}

edge Follows {
    has since: str;
}

walker CountReach {
    has seen: int = 0;

    can count with Person entry {
        self.seen += 1;
        visit [-->];        # keep walking outbound edges
    }
}
```

Spawn the walker anywhere in the graph and it does the rest:

```jac
with entry {
    alice = root ++> Person(name="Alice");
    result = alice spawn CountReach();
    print(result.seen);
}
```

## Why bother?

The claim is not that graphs are new — it's that making the graph *the program
structure* changes what's easy:

1. **Locality is explicit.** A walker's `can ... with X entry` ability runs
   *at* a node. The code reads like the traversal it performs.
2. **Persistence is ambient.** Anything connected to `root` persists. There is
   no ORM because there is no "mapping" — the object graph is the storage.
3. **Scale is a deployment detail.** The same walker code runs single-process,
   multi-user, or sharded across a cluster; the runtime owns the topology.

> In OSP, "where does this code run?" and "where does this data live?" are the
> same question — and the language answers it for you.

## The mental shift

Coming from OOP, the trap is modeling everything as node fields. The idiom is
the opposite: **push structure out of objects and into the graph**. A
`Person` with a `friends: list[Person]` field is OOP with extra steps; a
`Person` with `Follows` edges is a graph your walkers — and your queries, and
your access control — can actually see.

It takes about a week for the inversion to feel natural. After that, going
back to hand-rolled joins feels like manual memory management.
