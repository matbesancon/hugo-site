+++
date = 2019-04-07
draft = false
tags = ["julia", "optimization", "jump", "graph", "integer-optimization"]
title = "Picking different names with integer optimization"
summary = """
Making social events easier as a graph problem.
"""
math = true

[banner]
image = ""
+++

--------

I must admit I am not always the most talented at social events.
One point I am especially bad at is **remembering names**, and it gets
even harder when lots of people have similar or similar-sounding names.
What if we could select a list of people with names as different from each
other as possible?  

First some definitions, *different* here is meant with respect to the
[Hamming distance](https://en.wikipedia.org/wiki/Hamming_distance) of any two names.
This is far from ideal since Ekaterina would be quite far from Katerina, but
it will do the trick for now.

## Graph-based mental model

This sounds like a problem representable as a complete graph.
The names are the vertices, and the weight associated with each edge $(i,j)$
is the distance between the names of the nodes. We want to take a subset
of $k$ nodes, such that the sum of edge weights for the induced sub-graph
is maximum. This is therefore a particular case of maximum (edge) weight clique
problem over a complete graph, which has been investigated in [1, 2] among others.

## A mathematical optimization approach

This model can be expressed in a pretty compact way:

$$ \max\_{x,y} \sum\_{(i,j)\in E} c\_{ij} \cdot y\_{ij} $$
subject to: $$ 2y\_{ij} \leq x\_i + x\_j \,\, \forall (i,j) \in E$$
$$ \sum\_{i} x\_i \leq k $$
$$x\_i, y\_{ij} \in \mathbb{B} $$

The graph is complete and undirected, so the set of edges is:  
$ E = $ {$ (i,j) | i \in $ {$ 1..|V| $}$, j \in ${$ 1..i-1 $}}  

It's an integer problem with a quadratic number of variables and constraints.
Some other formulations have been proposed, and there may be a specific structure
to exploit given that we have a complete graph.
For the moment though, this generic formulation will do.  

## A Julia implementation

What we want is a function taking a collection of names and returning which
are selected. The first thing to do is build this distance matrix.
We will be using the
[StringDistances.jl](https://github.com/matthieugomez/StringDistances.jl)
package not to have to re-implement the Hamming distance.

{{< highlight julia>}}
import StringDistances

hamming(s1, s2) = StringDistances.evaluate(StringDistances.Hamming(), s1, s2)

function build_dist(vstr, dist = hamming)
    return [dist(vstr[i], vstr[j]) for i in eachindex(vstr), j in eachindex(vstr)]
end
{{< /highlight >}}

We keep the option to change the distance function with something else later.
The optimization model can now be built, using the distance function and $k$,
the maximum number of nodes to take.

{{< highlight julia>}}
using JuMP
import SCIP

function max_clique(dist, k)
    m = Model(with_optimizer(SCIP.Optimizer))
    n = size(dist)[1]
    @variable(m, x[1:n], Bin)
    @variable(m, y[i=1:n,j=1:i-1], Bin)
    @constraint(m, sum(x) <= k)
    @constraint(m, [i=1:n,j=1:i-1], 2y[i,j] <= x[i] + x[j])
    @objective(m, Max, sum(y[i,j] * dist[i,j] for i=1:n,j=1:i-1))
    return (m, x, y)
end
{{< /highlight >}}

I'm using SCIP as an integer solver to avoid proprietary software,
feel free to switch it for your favourite one.
Note that we don't optimize the model yet but simply build it.
It is a useful pattern when working with JuMP, allowing users
to inspect the build model or add constraints to it before starting the resolution.
The last steps are straightforward:

{{< highlight julia >}}
dist = build_dist(vstr)
(m, x, y) = max_clique(dist, k)
optimize!(m) # solve the problem

# get the subset of interest
diverse_names = [vstr[i] for i in eachindex(vstr) if JuMP.value(x[i]) ≈ 1.]
{{< /highlight >}}

And voilà.

## Trying out the model

I will use 50 real names taken from
[the list of random names](http://listofrandomnames.com) website, which you
can find [here](/text/names.txt).
The problem becomes large enough to be interesting, but reasonable enough for
a decent laptop. If you want to invite 4 of these people and get the most
different names, Christian, Elizbeth, Beulah and Wilhelmina are the ones you
are looking for.  


## Bonus and random ideas

It is computationally too demanding for now, but it would be interesting
to see how the total sum of distances evolves as you add more people.  

Also, we are using the sum of distances as an objective to maximize.
One interesting alternative would be to maximize the smallest distance between
any two nodes in the subset. This changes the model, since we need to encode
the smallest distance using constraints. We will use an indicator constraint
to represent this:

$$\max\_{x,y} d $$
subject to:
$$ y\_{ij} \Rightarrow d \leq c\_{ij} \,\, \forall (i,j) \in E$$
$$ 2y\_{ij} \leq x\_i + x\_j \forall (i,j) \in E $$
$$ \sum\_{(i,j) \in E} y\_{ij} = k\cdot (k-1) $$

Depending on the solver support, the indicator constraint can be modelled directly,
with big M or SOS1 constraints. This remains harder than the initial model.  

Special thanks to Yuan for bringing out the discussion which led to this
post, and to BYP for the feedback.

--------

# Sources

[1] Alidaee, Bahram, et al. "Solving the maximum edge weight clique problem via unconstrained quadratic  programming." European Journal of Operational Research 181.2 (2007): 592-597.

[2] Park, Kyungchul, Kyungsik Lee, and Sungsoo Park. "An extended formulation approach to the edge-weighted maximal clique problem." European Journal of Operational Research 95.3 (1996): 671-682.
