+++
title = "Vertex removal in LightGraphs"
subtitle = "Testing abstractions, their limits and leaks"

# Add a summary to display on homepage (optional).
summary = ""

date = 2019-05-30T11:14:43+02:00
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
# projects = ["internal-project"]

# Featured image
# To use, add an image named `featured.jpg/png` to your page's folder.
[image]
  # Caption (optional)
  caption = ""

  # Focal point (optional)
  # Options: Smart, Center, TopLeft, Top, TopRight, Left, Right, BottomLeft, Bottom, BottomRight
  focal_point = ""
+++

In various graph-related algorithms, a graph is modified through successive
operations, merging, creating and deleting vertices. That's the case for the
[Blossom algorithm](https://en.wikipedia.org/wiki/Blossom_algorithm) finding a
best matching in a graph and using contractions of nodes.
In such cases, it can be useful to remove only the vertex being contracted,
and maintain the number of all other vertices.

*LightGraphs.jl* offers a set of abstractions, types and algorithms to get started
with graphs. The claim of the abstraction is simple: whatever the underlying
structure representing your graph, if it implements the `AbstractGraph` interface,
it can be used out of the box with all algorithms built on *LightGraphs.jl*.
The main concrete type presented by *LightGraphs.jl* is `SimpleGraph` and its
directed counterpart `SimpleDiGraph`, only storing edges as adjacency lists,
meaning vertices are just the integers from 1 to the length of the list.
This means that in a graph with 6 vertices, deleting vertex 4 will re-label vertex 6
as 4. Hopefully, the interface should allow us to build a graph type on top of another graph,
re-implementing only vertex removal.

## A simple vertex-safe implementation

First things first, we will build it as a struct, using LightGraphs:

{{< highlight julia>}}
import LightGraphs
const LG = LightGraphs

struct VSafeGraph{T, G<:LG.AbstractGraph{T}, V<:AbstractVector{Int}} <: LG.AbstractGraph{T}
    g::G
    deleted_vertices::V
    VSafeGraph(g::G, v::V) where {T, G<:LG.AbstractGraph{T}, V<:AbstractVector{Int}} = new{T, G, V}(g, v)
end

VSafeGraph(g::G) where {G<:LG.AbstractGraph} = VSafeGraph(g, Vector{Int}())
VSafeGraph(nv::Integer) = VSafeGraph(LG.SimpleGraph(nv))
{{< /highlight >}}

We added simple default constructors for convenience. The structure holds two
elements:

- An inner abstract graph `g`
- A list of vertices already deleted: `deleted_vertices`.

The interface can now be implemented for our type, starting with the trivial
parts:

{{< highlight julia>}}
LG.edges(g::VSafeGraph) = LG.edges(g.g)
LG.edgetype(g::VSafeGraph) = LG.edgetype(g.g)

LG.is_directed(g::VSafeGraph) = LG.is_directed(g.g)
LG.is_directed(::Type{<:VSafeGraph{T,G}}) where {T,G} = LG.is_directed(G)

LG.ne(g::VSafeGraph) = LG.ne(g.g)
LG.nv(g::VSafeGraph) = LG.nv(g.g) - length(g.deleted_vertices)
LG.vertices(g::VSafeGraph) = (v for v in LG.vertices(g.g) if !(v in g.deleted_vertices))

LG.outneighbors(g::VSafeGraph, v) = LG.outneighbors(g.g, v)
LG.inneighbors(g::VSafeGraph, v) = LG.inneighbors(g.g, v)
LG.has_vertex(g::VSafeGraph, v) = LG.has_vertex(g.g, v) && !(v in g.deleted_vertices)

LG.has_edge(g::VSafeGraph, e) = LG.has_edge(g.g, e)

LG.add_vertex!(g::VSafeGraph) = LG.add_vertex!(g.g)

LG.rem_edge!(g::VSafeGraph, v1, v2) = LG.rem_edge!(g.g, v1, v2)

Base.copy(g::VSafeGraph) = VSafeGraph(copy(g.g), copy(g.deleteed_vertices))
{{< /highlight >}}

For most of these, we only re-call the method on the inner graph type.
Only for `LG.nv`, which computes the number of vertices in the inner graph,
minus the number of vertices in our removed list. Now the tricky parts,
adding an edge and removing a vertex, which require a bit more verifications:

{{< highlight julia>}}
function LG.add_edge!(g::VSafeGraph, v1, v2)
    if !LG.has_vertex(g, v1) || !LG.has_vertex(g, v2)
        return false
    end
    LG.add_edge!(g.g, v1, v2)
end

function LG.rem_vertex!(g::VSafeGraph, v1)
    if !LG.has_vertex(g, v1) || v1 in g.deleted_vertices
        return false
    end
    for v2 in LG.outneighbors(g, v1)
        LG.rem_edge!(g, v1, v2)
    end
    for v2 in LG.inneighbors(g, v1)
        LG.rem_edge!(g, v2, v1)
    end
    push!(g.deleted_vertices, v1)
    return true
end
{{< /highlight >}}

Instead of removing the vertex `v1` from the inner graph, the function removes
all edges pointing to and from `v1`, and then adds it to the removed list.

## Specific and generic tests

So far so good, we can add some basic tests to check our type behaves as
expected:

{{< highlight julia>}}
@testset "Graph construction and basic interface" begin
    nv = 20
    g1 = VSafeGraph(nv)
    @test LG.nv(g1) == nv
    @test LG.nv(g1.g) == nv

    g2_inner = LG.CompleteGraph(nv)
    g2 = VSafeGraph(g2_inner)
    @test LG.nv(g2) == LG.nv(g2_inner)
    @test LG.ne(g2) == LG.ne(g2_inner)

    @test all(sort(collect(LG.vertices(g2))) .== sort(collect(LG.vertices(g2_inner))))

    g3 = VSafeGraph(LG.CompleteDiGraph(30))
    @test LG.is_directed(g3)
    @test !LG.is_directed(g2)
end

@testset "Vertex deletion" begin
    Random.seed!(33)
    nv = 45
    inner = LG.CompleteGraph(nv)
    g = VSafeGraph(inner)
    @test LG.ne(inner) == LG.ne(g)
    @test LG.nv(inner) == LG.nv(g)
    nrm = 0
    for _ in 1:15
        removed_ok = LG.rem_vertex!(g, rand(1:nv))
        if !removed_ok
            continue
        end
        nrm += 1
        @test LG.nv(inner) == nv
        @test LG.nv(g) == nv - nrm
        @test length(g.deleted_vertices) == nrm

        @test LG.ne(inner) == LG.ne(g)
    end
end
{{< /highlight >}}

So far so good. Now, with the promise of generic graphs and the AbstractGraph
interface, we should be able to use **any** algorithm in *LightGraphs.jl*,
let us try to compute a page rank and a Kruskal minimum spanning tree:

{{< highlight julia>}}
nv = 45
inner = LG.CompleteGraph(nv)
g = VSafeGraph(inner)
removed_ok = LG.rem_vertex!(g, rand(1:nv))
@test removed_ok
# LG broken here
@test_throws BoundsError LG.pagerank(g)
@test_throws BoundsError LG.kruskal_mst(g)
{{< /highlight >}}

Yikes, what's happening here? Many parts of *LightGraphs.jl* use vertices computed
from `vertices(g) `as indices for structures indexed by them. So if you remove
vertex 4 in a 6-vertex graph, vertices will be `{1,2,3,5,6}`, and the rank
algorithm will try to access the 6th rank, even though only 5 exist.

## Fixes and proposal

It would be too bad to throw the interface altogether, but we need to do
something for the broken behaviour. The underlying assumption here is that
vertices behave like indices for anything vertex-related.
So the way we implement this interface for `VSafeGraph` is correct, but the
implicit contract is not, the way it is used in algorithms such as pagerank
and Kruskal leak the underlying implementation for `SimpleGraph`:
a contiguous list of integers from 1 to the number of vertices.
It reminds me of this [great talk](https://youtu.be/MdTTt5v-HWQ?t=692)
on paying attention to the contract of an interface in Go, the type is telling
you what to expect in and out, but not how it is supposed or will be used.

The first fix is to make `vertices` return `1:nv(g)` for VSafeGraph, but if you
think about it, it means it needs to do such with any graph type, which means
the `vertices` function is redundant with other functions of the interface and
should not be mandatory. The other option is to fix breaking code to really
use the interface signalled and documented and not the leaked implementation.

We still have some good news though:

- Changing the code here is strictly non-breaking, since we would just remove
the assumption that vertices are indices.
- If we want to keep this assumption for some pieces of code, it means these
pieces are not generic but specialized, something we can handle well using either
dispatch on types or traits, which *LightGraphs.jl* already does. There is a `IsDirected`
trait associated with the fact that a graph is directed or not, there could also
be a `HasContiguousVertices` trait signalling whether this assumption is validated
for a type.

## Edit: refined proposal

Following some discussions with fellow *LightGraphs.jl* developers and users, a
softer transition could be:

1. Add the functions `vertex_indices(g)` and `vertex_values(g)` to the interface, `vertex_values` could default to `vertex_indices`, which could itself default on `1:nv(g)`.
2. Deprecate `vertices(g)`, with a fallback to `vertex_indices`.
3. Replace all calls to `vertex` with either `vertex_indices` or `vertex_values` depending on which makes sense for the use case.

This change is non-breaking and only deprecating `vertices`, making the
interface more explicit. By keeping the two functions, we avoid having to use
`enumerate(vertices_values(g))` every time we need indices.

## Edit 2: Corrections to the functions

I have corrected various functions following Pankaj's much needed
[Pull Request](https://github.com/matbesancon/VertexSafeGraphs.jl/pull/2)
on the corresponding repository, thank!

## Edit 3

Seth Bromberger spotted an error in my assumptions,
We use swap-and-pop is used for vertex removal, so the last
vertex will take the place of the removed one in the re-labelling.
