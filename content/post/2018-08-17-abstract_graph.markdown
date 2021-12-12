+++
date = 2018-08-17
draft = false
tags = ["julia", "graph", "package", "interface"]
title = "Building our own graph type in Julia"
summary = """
Who needs libraries when from scratch looks so good
"""
math = true

[header]
image = "posts/graph_interface/example.svg"
+++

--------

This is an adapted post on the talk we gave with [James](https://twitter.com/fairbanksjp)
at JuliaCon 2018 in London. You can see the
[original slides](https://matbesancon.xyz/graph_interfaces_juliacon18),
the video still requires a bit of post-processing.

Last week [JuliaCon](http://juliacon.org) in London was a great and very condensed experience.
The two talks on [LightGraphs.jl](https://github.com/JuliaGraphs/LightGraphs.jl)
received a lot of positive feedback and more than that, we saw
how people are using the library for a variety of use cases which is a great
signal for the work on the JuliaGraphs ecosystem
(see the [lightning talk](https://matbesancon.xyz/graph_interfaces_juliacon18/ecosystem.html#/)).

I wanted to re-build the same graph for people who prefer a post version to
my clumsy live explanations on a laptop not handling dual-screen well
(those who prefer the latter are invited to see the live-stream of the talk).

## Why abstractions?

The LightGraphs library is built to contain as few elements as possible to get
anyone going with graphs. This includes:

* The interface a graph type has to comply with to be used
* Essential algorithms implemented by any graph respecting that interface
* A simple, battery-included implementation based on adjacency lists

The thing is, if you design an abstraction which in fact has just one
implementation, you're doing abstraction wrong. This talks was also a
reality-check for LightGraphs, are we as composable, extensible as we promised?

The reason for abstraction is also that **minimalism has its price**.
The package was designed as the least amount of complexity required to get
graphs working. When people started to use it, obviously they needed more
features, some of which they could code themselves, some other required
extensions built within LightGraphs. By getting the core abstractions right,
you guarantee people will be able to use it and to build on top with minimal
friction, while keeping it simple to read and contribute to.

## Our matrix graph type

Let's recall that a graph is a collection of *nodes* and a collection of
*edges* between these nodes. To keep it simple, for a graph of $n$ edges,
we will consider they are numbered from 1 to n. An edge connects a node $i$
to a node $j$, therefore all the information of a graph can be kept as an
*adjacency matrix* $M_{ij}$ of size $n \times n$:

$$M_{ij} = \\begin{cases} 1, & \\mbox{if edge (i $\\rightarrow$ j) exists} \\\\ 0 & \\mbox{otherwise}\\end{cases}$$

We don't know what the use cases for our type will be, and therefore,
we will parametrize the graph type over the matrix type:

{{< highlight julia>}}
import LightGraphs; const lg = LightGraphs
mutable struct MatrixDiGraph{MT <: AbstractMatrix{Bool}} <: lg.AbstractGraph{Int}
  matrix::MT
end
{{< /highlight >}}

The edges are simply mapping an entry (i,j) to a boolean (whether there is an
edge from i to j). Even though creating a graph type that can be directed
or undirected depending on the situation is possible, we are creating a type
that will be directed by default.

## Implementing the core interface

We can now implement the core LightGraphs interface for this type, starting
with methods defined over the type itself, of the form `function(g::MyType)`

I'm not going to re-define each function here, their meaning can be found
by checking the help in a Julia REPL: `?LightGraphs.vertices` or on the
[documentation page](http://juliagraphs.github.io/LightGraphs.jl/stable/types.html#AbstractGraph-Type-1).

{{< highlight julia>}}
lg.is_directed(::MatrixDiGraph) = true
lg.edgetype(::MatrixDiGraph) = lg.SimpleGraphs.SimpleEdge{Int}
lg.ne(g::MatrixDiGraph) = sum(g.m)
lg.nv(g::MatrixDiGraph) = size(g.m)[1]

lg.vertices(g::MatrixDiGraph) = 1:nv(g)

function lg.edges(g::MatrixDiGraph)
    n = lg.nv(g)
    return (lg.SimpleGraphs.SimpleEdge(i,j) for i in 1:n for j in 1:n if g.m[i,j])
end
{{< /highlight >}}

Note the last function `edges`, for which the documentation specifies that we
need to return an **iterator** over edges. We don't need to collect the comprehension
in a Vector, returning a lazy generator.

Some operations have to be defined on both the graph and a node, of the form
`function(g::MyType, node)`.
{{< highlight julia>}}
lg.outneighbors(g::MatrixDiGraph, node) = [v for v in 1:lg.nv(g) if g.m[node, v]]
lg.inneighbors(g::MatrixDiGraph, node) = [v for v in 1:lg.nv(g) if g.m[v, node]]
lg.has_vertex(g::MatrixDiGraph, v::Integer) = v <= lg.nv(g) && v > 0
{{< /highlight >}}

Out `MatrixDiGraph` type is pretty straight-forward to work with and all
required methods are easy to relate to the way information is stored in the
adjacency matrix.

The last step is implementing methods on both the graph and an edge of the
form `function(g::MatrixDiGraph,e)`. The only one we need here is:
{{< highlight julia>}}
lg.has_edge(g::MatrixDiGraph,i,j) = g.m[i,j]
{{< /highlight >}}

## Optional mutability

Mutating methods were removed from the core interace some time ago,
as they are not required to describe a graph-like behavior.
The general behavior for operations mutating a graph is to return whether
the operation succeded. They consist in adding or removing elements from
either the edges or nodes.

{{< highlight julia>}}
import LightGraphs: rem_edge!, rem_vertex!, add_edge!, add_vertex!

function add_edge!(g::MatrixDiGraph, e)
    has_edge(g,e) && return false
    n = nv(g)
    (src(e) > n || dst(e) > n) && return false
    g.m[src(e),dst(e)] = true
end

function rem_edge!(g::MatrixDiGraph,e)
    has_edge(g,e) || return false
    n = nv(g)
    (src(e) > n || dst(e) > n) && return false
    g.m[src(e),dst(e)] = false
    return true
end

function add_vertex!(g::MatrixDiGraph)
    n = nv(g)
    m = zeros(Bool,n+1,n+1)
    m[1:n,1:n] .= g.m
    g.m = m
    return true
end
{{< /highlight >}}

## Testing our graph type on real data

We will use the graph type to compute the PageRank of

{{< highlight julia>}}
import SNAPDatasets
data = SNAPDatasets.loadsnap(:ego_twitter_d)
twitter_graph = MatrixDiGraph(lg.adjacency_matrix(data)[1:10,1:10].==1);
ranks = lg.pagerank(twitter_graph)
{{< /highlight >}}

Note the broadcast check `.==1`, `adjacency_matrix` is specified to yield a
matrix of `Int`, so we use this to cast the entries to boolean values.

I took only the first 10 nodes of the graph, but feel free to do the same with
500, 1000 or more nodes, depending on what your machine can stand  🙈

## Overloading non-mandatory functions
Some methods are already implemented for free by implementing the core interface.
That does not mean it should be kept as-is in every case. Depending on your
graph type, some functions might have smarter implementations, let's see one
example. What `MatrixDiGraph` is already an `adjacency_matrix`, so we know
there should be no computation required to return it (it's almost a no-op).

{{< highlight julia>}}
using BenchmarkTools: @btime

@btime adjacency_matrix(bigger_twitter)
println("why did that take so long?")
lg.adjacency_matrix(g::MatrixDiGraph) = Int.(g.m)
@btime A = lg.adjacency_matrix(bigger_twitter)
println("that's better.")
{{< /highlight >}}

This should yield roughly:
```
13.077 ms (5222 allocations: 682.03 KiB)
why did that take so long?
82.077 μs (6 allocations: 201.77 KiB)
that's better.
```

You can fall down to a no-op by storing the matrix entries as `Int` directly,
but the type ends up being a bit heavier in memory, your type, your trade-off.

## Conclusion

We've implemented a graph type suited to our need in a couple lines of Julia,
guided by the `LightGraphs` interface specifying **how** to think about our
graph instead of getting in the way of **what** to store. A lighter version
of this post can be read as [slides](https://matbesancon.xyz/graph_interfaces_juliacon18/).

As usual, ping me on [Twitter](https://twitter.com/matbesancon) for any
question or comment.

## Bonus

If you read this and want to try building your own graph type, here are two
implementations you can try out, put them out in a public repo and show them off
afterwards:
1. We created a type just for directed graphs, why bothering so much? You can create your own type which can be directed or not,
either by storing the information in the `struct` or by parametrizing the type
and getting the compiler to do the work for you.
2. We store the entries as an `AbstractMatrix{Bool}`, if your graph is dense
enough (how dense? No idea), it might be interesting to store entries as as
`BitArray`.

--------
Image source: GraphPlot.jl
