+++
date = 2019-09-12
draft = false
tags = ["julia", "jump", "optimization", "graphs"]
title = "Bridges as an extended dispatch system"
summary = """
Compiling mathematical optimization problems in a multiple-dispatch context.
"""
math = true
diagram = true

[header]
image = ""
+++

--------

The progress of mathematical optimization as a domain has been tightly
coupled with the development and improvement of computational methods and
their implementations as computer programs. As observed in the recent
MIPLIB compilation [^1], the quantification of method performance in
optimization cannot really be split from the experimental settings.

Different methods and implementations manipulate different data
structures to represent the same optimization problem.
Reformulating optimization problems has often been the role and responsibility
of the practitioner, transforming the application problem at hand to fit a
standard form that a given solver accepts as input for a solution method.
Interested readers may find work on formal representation of optimization
problems as data structures by Liberti et al[^5][^6].
Mapping a user-facing representation of an object into a semantically
equivalent internal representation is the role of compilers.
For mathematical optimization specifically, **Algebraic Modelling Languages**
(AML) are domain-specific languages (and often an associated compiler and runtime)
turning a user-specified code into data structures passed to solvers.  

We will focus in this post on [MathOptInterface.jl](https://github.com/JuliaOpt/MathOptInterface.jl)
(**MOI**) which acts as a second layer of the compilation phase of an AML.
The main direct user-facing language for this is [JuMP](https://github.com/JuliaOpt/JuMP.jl),
which has already been covered in multiple formats [^2][^3].
The problem has been read from the user code but not reformulated yet.
In compiler terms, MOI appears after the parsing phase: the user code has been
recognized and transformed into corresponding internal structures.

{{% toc %}}

Multiple dispatch is the specialization of code depending on the arity and type
of arguments. When multiple definitions (methods) exist for a function, the types
of the different arguments are used to determine which definition is compatible.
If several definitions are compatible, the most specific with respect to the
position in the type hierarchy is selected. If several definitions are compatible
without a total ordering by specificity, the method call is ambiguous, which raises an error.
More information on the dispatch system in Julia can be found
[in the seminal article](https://doi.org/10.1137/141000671) and the recent talk on
[multiple dispatch](https://www.youtube.com/watch?v=kc9HwsxE1OY).
See the following examples for the basic syntax:

{{< highlight julia>}}
f(x) = 3 # same as f(x::Any) = 3
f(x::Int) = 2x

# dispatch on arity
f(x, y) = 2

# defining and dispatching on a custom type
struct X
  value::Float64
end

f(x::X) = 3 * x.value
{{< /highlight >}}

# Re-formulating problems using multiple dispatch

In this section, we will consider the reformulation of problems
using multiple dispatch. In a generic form, an optimization problem can be
written as:

$$\min_{x} f(x) \\\\ \text{s.t.}\\\\ \,\,\,F_i(x) \in S_i \,\,\, \forall i$$

## The example of linear constraints

We will build a reformulation system leveraging multiple dispatch.
Assuming the user code is already parsed, the problem input can be represented
as function-set pairs $(F_i, S_i)$. If we restrict this to individual linear
constraints, all functions are of the form:
$$ F_i(x) = a_i^T x $$

The three types of sets are:

- `LessThan(b)`: $ y \in S_i \Leftrightarrow y \leq b $
- `GreaterThan(b)`: $ y \in S_i \Leftrightarrow y \geq b $
- `EqualTo(b)`: $ y \in S_i \Leftrightarrow y = b $

{{< highlight julia>}}
abstract type ConstraintSet end

struct LessThan{T} <: ConstraintSet
    b::T
end

struct GreaterThan{T} <: ConstraintSet
    b::T
end

struct EqualTo{T} <: ConstraintSet
    b::T
end

abstract type ScalarFunction end

struct ScalarAffineFunction{T} <: ScalarFunction
    a::Vector{T}
    x::Vector{VariableIndex}
end
{{< /highlight >}}

Now that the fundamental structures are there, let us think of a solver based
on the simplex method, accepting only less-or-equal linear constraints.
We will assume a `Model` type has been defined, which supports a function
`add_constraint!(m::Model, f::F, s::S)`, which adds a constraint of type `F in S`.

{{< highlight julia>}}

function add_constraint!(m::Model, f::ScalarAffineFunction, s::LessThan)
    pass_to_solver(m.solver_pointer, f, s)
end

function add_constraint!(m::Model, f::ScalarAffineFunction{T}, s::GreaterThan{T}) where {T}
    # a^T x >= b <=> -a^T x <= b
    leq_set = LessThan{T}(-s.b)
    leq_function = ScalarAffineFunction(-f.a, f.x)
    add_constraint!(m, leq_function, leq_set)
end

function add_constraint!(m::Model, f::ScalarAffineFunction, s::EqualTo)
    # a^T x == b <=> a^T x <= b && a^T x >= b
    leq_set = LessThan(s.b)
    geq_set = LessThan(s.b)
    leq_function = copy(f)
    geq_function = copy(f)
    add_constraint!(m, leq_function, leq_set)
    add_constraint!(m, geq_function, geq_set)
end
{{< /highlight >}}

The dispatching rules of that program are determined statically
and define the sequence of method calls:

```
graph TD;
    E[EqualTo] --> G[GreaterThan];
    E[EqualTo] --> L[LessThan];
    G[GreaterThan] --> L[LessThan];
    L[LessThan] --> S[Solver];
```

<img src="/img/posts/bridges/diagram1.svg" style="width:40%;">

At each call site, exactly one method is determined to be the appropriate
one to use by the dispatch mechanism.

## Unique dispatch and multiple solvers

Let us now consider that another solver is integrated into our dispatch-based
optimization framework, but supporting only `GreaterThan` constraints.
The new method call diagram is:

```
graph TD;
    E[EqualTo] --> G[GreaterThan];
    E[EqualTo] --> L[LessThan];
    L[LessThan] --> G[GreaterThan];
    G[GreaterThan] --> S[Solver];
```

<img src="/img/posts/bridges/diagram2.svg" style="width:40%;">

Considering that we wish to define one reformulation graph for all solvers,
two possibilities occur:

1. Which path should be used is encoded in types.
2. The method called from a given node depends on runtime parameters.

The first option could sound more efficient, but as the number of nodes, arcs
and solvers grow, compilation is rendered impossible, as one would have to
recompute complete programs based on the addition of solvers or reformulations.
The second option requires tools other than dispatch, since this mechanism
uses precisely the types to determine the method. It is to tackle this problem
of reformulating problems in graph above that the bridge system was developed
in MOI.

# The bridge system

The bridge system emerged as a solution to tackle the rapidly-growing
number of supported functions, sets and constraints as function-set pairs.
A bridge is the instantiation in the reformulation system of an arc in
the diagram presented above. It is defined by:

- The type of constraint it is replacing, represented by its function-set pair $(F_0, S_0)$.
- The type of constraints which must be supported for the reformulation, as a collection of function-set pairs $[(F_i, S_i)]$.
- The reformulation method itself which takes the initial constraint, creates the necessary variables and constraints and adds them to the model. In a Haskell-like notation, the declarative part of the bridge can be modelled with the following signature:
$$ ([x_0], F_0, S_0) \rightarrow ([x_1], [(F_i,S_i)]) $$

where $[x_0]$ is a collection of variables used by the initial constraint,
$[x_1]$ is the collection of newly created variables, and the $(F_i,S_i)$ are the newly created constraints.

## Bridge implementation

The bridge definition and most implementations live in the `MathOptInterface.Bridges` module.
It consists of an abstract type `AbstractBridge` and some functions that bridges must implement.

We will see the greatly reduced example of a bridge type `MyBridge` adding support for two types
of constraints. The following code declares *what* the bridge does:

{{< highlight julia>}}
abstract type AbstractBridge end

struct MyBridge1 <: AbstractBridge end

struct MyBridge2 <: AbstractBridge end

"""
By default, bridges do not support a constraint `F-in-S`
"""
function MOI.supports_constraint(::Type{<:AbstractBridge}, ::Type{F}, ::Type{S}) where {F, S}
    return false
end

"""
MyBridge1 supports `F1 in S1`
""" 
function MOI.supports_constraint(::Type{MyBridge1}, ::Type{F1}, ::Type{S1})
    return true
end

"""
MyBridge2 supports `F2 in S2`
"""
function MOI.supports_constraint(::Type{MyBridge2{F2,S2}}, ::Type{F2}, ::Type{S2})
    return true
end

"""
Bridging a `F1 in S1` with `MyBridge1` requires creating constraints of type `F3 in S3` and `F3 in S4`
"""
added_constraint_types(::Type{MyBridge1})
    return [(F3, S3), (F3, S4)]
end

"""
Bridging a `F2 in S2` with `MyBridge2` requires creating constraints of type `F3 in S3`
"""
added_constraint_types(::Type{MyBridge2})
    return [(F3, S3)]
end
{{< /highlight >}}

What these method implementations declare is the following structure:

```
graph LR;
    F1[F1 in S1] -- B1 --> F33[F3 in S3];
    F1[F1 in S1] -- B1 --> F34[F3 in S4];
    F2[F2 in S2] -- B2 --> F33[F3 in S3];
```

<img src="/img/posts/bridges/diagram3.svg" style="width:40%;">

Unlike dispatch, multiple possible bridges can be defined for a given constraint $F_1 \in S_1$.
In optimization, this corresponds to multiple possible reformulations of a given constraint.  

Now that the bridges behaviour have been defined, their implementation have to be given,
again in a trimmed version of the real MOI code:

{{< highlight julia >}}
function bridge_constraint(::Type{MyBridge1}, model::MOI.ModelLike, f::F1, s::S1)
    (f3, s3) = transform_constraint_first_component(f, s)
    s4 = transform_constraint_second_set(f, s)
    new_constraint3 = MOI.add_constraint(model, f3, s3)
    new_constraint4 = MOI.add_constraint(model, f3, s4)
    return MyBridge1(new_constraint3, new_constraint4)
end

function bridge_constraint(::Type{MyBridge2}, model::MOI.ModelLike, f::F2, s::S2)
    (f3, s3) = transform_constraint_first_component(f, s)
    new_constraint3 = MOI.add_constraint(model, f3, s3)
    return MyBridge2(new_constraint3)
end
{{< /highlight >}}

Finally, the graph is for the moment split across different bridges.
The multiple dispatch mechanism uses a [method table](https://pkg.julialang.org/docs/julia/THl1k/1.1.1/devdocs/functions.html),
the bridge system uses a bridge optimizer which stores all bridges and
thus contains the necessary information to convert a constraint to a supported form.

## Problem reformulation heuristics

A bridge optimizer takes a given problem, a solver and the set of bridges,
all of which representable in a single hyper-graph, a graph with possibly
multiple edges between two given nodes.

![](/img/posts/bridges/Problem1.svg)

$P$ represents the initial problem, pointing to the constraints it contains.
There is an edge from $C_i$ to $C_j$ for each bridge reformulating $C_i$
using at least a $C_j$ constraint. A constraint $C_i$ points to $S$ if the solver
natively supports the constraint.  

Some bridges require defining multiple new constraints. That is the case of $B_5$
reformulating $C_6$ using $C_3$ and $C_4$. On the contrary, $C_3$ can be re-formulated
either in $C_2$ using $B_2$ or in $C_4$ using $B_3$. In this setting, reformulating
it in $C_2$ is appropriate, but may change depending on the solver.
A potential large number of bridges could be introduced without being on any
problem-solver path. For instance, there will likely be no semi-definite cone
constraint when the problem at hand is linear, and $S$ a simplex-based solver.
Without reasoning on specific constraints, it is hard to picture which
reformulation is efficient.  

The current bridging decision is based on a shortest-path heuristic.
One bridge is considered a unit distance, and a shortest path from all
user-facing constraints to all solver-compatible constraints is determined.
More precisely, a [Bellman-Ford](https://en.wikipedia.org/wiki/Bellman%E2%80%93Ford_algorithm)
type shortest path is used.

# Perspective & conclusion

MathOptInterface.jl may be one of the greatest strength of the JuMP ecosystem:
setting the abstractions right allows the developers to integrate more exotic
constraint types in a consistent manner.
Optimization practitioners do not limit themselves to linear and
mixed-integer problems, following improvements in performance and variety
of solvers, the recent JuMP session at JuliaCon 2019[^4] lays out the
motivation and structure of MOI, and recent
developments it enabled.
The type-based `Function in Set` structure keeps the underlying
machinery familiar to both optimization scientists formulating problems in a close
fashion and Julia programmers leveraging multiple dispatch.  

Transforming optimization problems using the bridge system is transparent,
leaving the option for advanced users to pick which paths are chosen
in the hypergraph. In the scenario where MOI was not performing these operations,
the two options are:

- **Reformulations by the modelling language**: this may mean a systematic
overhead cost of using the user-facing modelling language, especially if the used
reformulation is not ideal for a specific problem. This also creates a barrier for
other modelling languages to emerge, since a great deal of work has gone in
reformulations of the user-input. The two-layer structure of JuMP + MOI has enabled
different languages such as [Parametron.jl](https://github.com/tkoolen/Parametron.jl)
or [Convex.jl](https://github.com/JuliaOpt/Convex.jl) to emerge, sharing the same
solver interfaces and middle infrastructure. The monolithic modelling environments
historically dominant in mathematical optimization may explain to some extent why
a large part of the optimization literature is working with solver APIs directly,
thus loosing any ability to switch solver later.
- **Reformulations by the solver**: this is currently done for a lot of constraints,
without always being transparent on which reformulation is applied and what the
end-model is. This can lead to surprising behaviour when switching solvers
or passing a different formulation of the same problem, without having access
to what happens under the hood in a black-box proprietary solver.

The MOI system thus helps present and future researchers to avoid the pitfalls of the
*two-language problem* of optimization.

## Further resources

[^1]: MIPLIB 2017: Data-Driven Compilation of the 6th Mixed-Integer Programming Library, Gleixner, Ambros and Achterberg, Tobias and Christophel, Philipp and Lübbecke, Marco and Ralphs, Ted K and Hendel, Gregor and Gamrath, Gerald and Bastubbe, Michael and Berthold, Timo and Jarck, Kati and others, 2019.

[^2]: JuMP initial paper https://doi.org/10.1137/15M1020575

[^3]: JuMP tutorial at JuliaCon2018: https://www.youtube.com/watch?v=7tzFRIiseJI

[^4]: MathOptInterface, JuMP extensions and MOI-based solvers at JuliaCon2019: https://www.youtube.com/watch?v=cTmqmPcroFo

[^5]: Liberti, Leo. "Reformulations in mathematical programming: Definitions and systematics." RAIRO-Operations Research 43.1 (2009): 55-85. [Preprint](http://www.numdam.org/article/RO_2009__43_1_55_0.pdf)

[^6]: Liberti, Leo and Cafieri, Sonia and Tarissan, Fabien, Reformulations in Mathematical Programming: A Computational Approach, [DOI](https://doi.org/10.1007/978-3-642-01085-9_7), [Preprint](https://www.lix.polytechnique.fr/~liberti/arschapter.pdf)

The diagrams were designed using [MermaidJS](https://mermaidjs.github.io) & [draw.io](https://draw.io).