+++
title = "Leveraging special graph shapes in LightGraphs"
subtitle = "Let the compiler do the work"

# Add a summary to display on homepage (optional).
summary = ""

date = 2019-07-25T18:14:43+02:00
draft = false

# Authors. Comma separated list, e.g. `["Bob Smith", "David Jones"]`.
authors = []

# Is this a featured post? (true/false)
featured = false

# Tags and categories
# For example, use `tags = []` for no tags, or the form `tags = ["A Tag", "Another Tag"]` for one or more tags.
tags = ["julia", "graphs", "interface"]
categories = []

# Projects (optional).
#   Associate this post with one or more of your projects.
#   Simply enter your project's folder or file name without extension.
#   E.g. `projects = ["deep-learning"]` references
#   `content/project/deep-learning/index.md`.
#   Otherwise, set `projects = []`.
projects = []

# Featured image
# To use, add an image named `featured.jpg/png` to your page's folder.
[image]
  # Caption (optional)
  caption = ""

  # Focal point (optional)
  # Options: Smart, Center, TopLeft, Top, TopRight, Left, Right, BottomLeft, Bottom, BottomRight
  focal_point = ""
+++

In a [previous post]({{< ref path="2019-05-30-vertex-safe-removal" >}}), we
pushed the boundaries of the LightGraphs.jl abstraction to see how conforming the
algorithms are to the declared interface, noticing some implied assumptions
that were not stated. This has led to the development of
[VertexSafeGraphs.jl](https://github.com/matbesancon/VertexSafeGraphs.jl) and
soon to some work on LightGraphs.jl itself.

Another way to push the abstraction came out of the
[JuliaNantes workshop](https://matbesancon.xyz/slides/JuliaNantes/Graphs):
leveraging some special structure of graphs to optimize some specific operations.
A good parallel can be established be with the `LinearAlgebra` package from
Julia Base, which defines special matrices such as `Diagonal` and `Symmetric`
and `Adjoint`, implementing the `AbstractMatrix` interface but without storing
all the entries.

## A basic example

Suppose you have a path graph or chain, this means any vertex is connected to
its predecessor and successor only, except the first and last vertices.
Such graph can be represented by a `LightGraphs.SimpleGraph`:
{{< highlight julia>}}
import LightGraphs
const LG = LightGraphs

g = LG.path_graph(10)

for v in 1:9
    @assert LG.has_edge(g, v, v+1) # should not explode
end
{{< /highlight >}}

This is all fine, but we are encoding in an adjacency list some structure that
we are aware of from the beginning. If you are used to thinking in such way,
"knowing it from the beginning" can be a hint that it can be encoded in terms
of types and made zero-cost abstractions. The real only runtime information of
a path graph (which is not available before receiving the actual graph) is its
size $n$. The only thing to do is implement the handful of methods from the
LightGraphs interface.

{{< highlight julia>}}
struct PathGraph{T <: Integer} <: LG.AbstractGraph{T}
    nv::Int
end

LG.edgetype(::PathGraph) = LG.Edge{Int}
LG.is_directed(::Type{<:PathGraph}) = false
LG.nv(g::PathGraph) = g.nv
LG.ne(g::PathGraph) = LG.nv(g) - 1
LG.vertices(g::PathGraph) = 1:LG.nv(g)

LG.edges(g::PathGraph) = [LG.Edge(i, i+1) for i in 1:LG.nv(g)-1]

LG.has_vertex(g::PathGraph, v) = 1 <= v <= LG.nv(g)

function LG.outneighbors(g::PathGraph, v)
    LG.has_vertex(g, v) || return Int[]
    LG.nv(g) > 1 || return Int[]
    if v == 1
        return [2]
    end
    if v == LG.nv(g)
        return [LG.nv(g)-1]
    end
    return [v-1, v+1]
end

LightGraphs.inneighbors(g::PathGraph, v) = outneighbors(g, v)

function LightGraphs.has_edge(g::PathGraph, v1, v2)
    if !has_vertex(g, v1) || !has_vertex(g, v2)
        return false
    end
    return abs(v1-v2) == 1
end
{{< /highlight >}}

## A more striking example

`PathGraph` may leave you skeptical as to the necessity of such machinery, and
you are right. A more interesting example might be complete graphs. Again for
these, the only required piece of information is the number of vertices,
which is a lot lighter than storing all the possible edges. We can make a
parallel with [FillArrays.jl](https://github.com/JuliaArrays/FillArrays.jl),
implicitly representing the entries of a matrix.

### Use cases

The question of when to use a special-encoded graph is quite open.
This type can be used with all functions assuming a graph-like behaviour, but
is immutable, it is therefore not the most useful when you construct these
special graphs as a starting point for an algorithm mutating them.

## Performance

As of now, simple benchmarks will show that the construction of special graphs
is cheaper than the creation of the adjacency lists for `LightGraphs.SimpleGraph`.
Actually using them for "global" algorithms is another story:

{{< highlight julia>}}
function f(G, nv)
    g = G(nv)
    pr = pagerank(g)
    km = kruskal_mst(g)
    return (g, pr, km)
end
{{< /highlight >}}

Trying to benchmark this function on `PathGraph` shows it is way worse than
the corresponding SimpleGraph structure, the `CompleteGraph` implementation is
about the same order of allocations and runtime as its list-y counterpart.

The suspect for the lack of speedup is the `edges` operation, optimized with a custom edge
iterator in LightGraphs and returning a heap-allocated `Array` in SpecialGraphs
for now. Taking performance seriously will requiring tackling this before
anything else. Other opportunities for optimization may include returning
[StaticArrays](https://github.com/JuliaArrays/StaticArrays.jl/) and
re-implementing optional methods such as `LightGraphs.adjacency_matrix`
using specialized matrix types.

## Conclusion and further reading

The work on these graph structures is happening in
[SpecialGraphs.jl](https://github.com/JuliaGraphs/SpecialGraphs.jl), feel free
to file issues and submit pull requests. Also check out the matrix-based
graph prototype in [this post]({{< relref "2018-08-17-abstract_graph" >}}).
