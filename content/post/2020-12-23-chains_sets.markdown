+++
date = 2020-12-23
draft = false
tags = ["julia", "optimization", "jump", "automatic-differentiation"]
disableToc = false
title = "Sets, chains and rules - part I"
summary = """
The Pandora box from simple set membership.
"""
math = true
diagram = false
[header]

+++

{{< toc >}}

In this post, I will develop the process through which the
[MathOptSetDistances.jl](https://github.com/matbesancon/MathOptSetDistances.jl)
package has been created and evolved. In the second one, I will go over the differentiation part.

# MathOptInterface and the motivation

[MathOptInterface.jl](https://jump.dev/MathOptInterface.jl/dev/) or MOI
for short is a Julia package to unify *structured constrained* optimization problems.
The abstract representation of problems MOI addresses is as follows:

$$
\\begin{align}
\min_{x}\\,\\, & F(x) \\\\\\\\
\text{s.t.}\\,\\, & G_k(x) \in \mathcal{S}_k \\,\\, \forall k \\\\\\\\
& x \in \mathcal{X}.
\\end{align}
$$

$\mathcal{X}$ is the domain of the decision variables,
$F$ is the objective function, mapping values of the variables to the real line.
The constrained aspect comes from the constraints $G_k(x) \in \mathcal{S}_k$,
some mappings of the variables $G_k$ have to belong to a certain set $\mathcal{S}_k$.
See this [recent paper](https://arxiv.org/abs/2002.03447) on MOI for more information
on this representation.

The **structured** aspect comes from the fact that a specific form of $F$, $G$
and $\mathcal{S}$ is known in advance by the modeller. In other words, MOI
does not deal with arbitrary unknown functions or black-box sets.
For such cases, other tools are more adapted.

From a given problem in this representation, two operations can be of interest
within a solution algorithm or from a user perspective:

1. Given a value for $x$, evaluating a function $F(x)$ or $G(x)$,
2. Given a value $v$ in the co-domain of $G_k$, asserting whether $v \in S_k$.

The first point is addressed by the function `eval_variables` in the `MOI.Utilities` submodule
([documentation](https://jump.dev/MathOptInterface.jl/v0.9/apireference/#MathOptInterface.Utilities.eval_variables)).

The second point appears as simple (or at least it did to me) but is trickier.
What tolerance should be set?
Most solvers include a numerical tolerance on constraint violations, should this
be propagated from user choices, and how?

The deceivingly simple feature ended up opening one of the
[longest discussions](https://github.com/jump-dev/MathOptInterface.jl/pull/1023)
in the MOI repository.

> Fairly straightforward[...]  

*Optimistic me, beginning of the PR, February 2020*

A more meaningful query for solvers is, given a value $v$, what is the
**distance** from $v$ to the set $\mathcal{S}$:

$$
\\begin{align}
(\text{δ(v, s)})\\,\\,\min_{v_p}\\,\\, & \text{dist}(v_p, v) \\\\\\\\
\text{s.t.}\\,\\, & v_p \in \mathcal{S} \\\\\\\\
& v \in \mathcal{V}.
\\end{align}
$$

The optimal value of the problem above noted $δ(v, s)$ depends on the
notion of the distance taken between two values in the domain $\mathcal{V}$,
noted $dist(\cdot,\cdot)$ here.
In terms of implementation, the signature is roughly:

```julia
distance_to_set(v::V, s::S) -> Real
```

*Aside:*
this is an example where multiple dispatch brings great value to the design:
the implementation of `distance_to_set` depends on both the value type `V`
and the type of set `S`. See why it's useful in the
[Bonus section]({{< relref "# Bonus" >}} "").

If $\mathcal{S}$ was a generic set, computing this distance would be as hard as
solving an optimization problem with constraints $v \in \mathcal{S}$ but
since we are dealing with structured optimization, many particular sets have
closed-form solutions for the problem above.

# Examples

$\\|\cdot\\|$ will denote the $l_2-$norm if not specified.

The distance computation problem defined by the following data:

$$
\\begin{align}
& v \in \mathcal{V} = \mathbb{R}^n,\\\\
& \mathcal{S} = \mathbb{Z}^n,\\\\
& dist(a, b) = \\|a - b\\|
\\end{align}
$$

consists of rounding element-wise to the closest integer.

The following data:

$$
\\begin{align}
& v \in \mathcal{V} = \mathbb{R}^n,\\\\
& \mathcal{S} = \mathbb{R}^n_+,\\\\
& dist(a, b) = \\|a - b\\|
\\end{align}
$$

find the closest point in the positive orthant, with a result:

$$
v_{p}\\left[i\\right] = \text{max}(v\\left[i\\right], 0) \\,\\, \forall i \in \\{1..n\\}.
$$

# Set projections

The distance from a point to a set tells us how far a given candidate is from
respecting a constraint. But for many algorithms, the quantity of interest is
the projection itself:

$$
\Pi_{\mathcal{S}}(v) \equiv \text{arg}\min_v \delta(v, \mathcal{S}).
$$

Like the optimal distance, the best projection onto a set can often be defined
in closed form i.e. without using generic optimization methods.

We also keep the convention that the projection of a point already in the set is
always itself:
$$
δ(v, \mathcal{S}) = 0 \\,\\, \Leftrightarrow \\,\\, v \in \mathcal{S} \\,\\, \Leftrightarrow \\,\\, \Pi_{\mathcal{S}}(v) = v.
$$

The interesting thing about projections is that once obtained, a distance
can be computed easily, although only computing the distance can be slightly
more efficient, since we do not need to allocate the projected point.

# User-defined distance notions

Imagine a set defined using two functions:
$$
\begin{align}
\mathcal{S} = \\{v \in \mathcal{V}\\,\|\\, f(v) \leq 0, g(v)\leq 0 \\}.
\end{align}
$$

The distance must be evaluated with respect to two values:
$$
(max(f(v), 0), max(g(v), 0)).
$$

Here, the choice boils down to a norm, but hard-coding it seems harsh and rigid for users.
Even if we plan correctly and add most norms people would expect, someone will
end up with new exotic problems on [sets](https://github.com/blegat/SetProg.jl),
[complex numbers](https://github.com/jump-dev/ComplexOptInterface.jl) or function spaces.

The solution that came up after discussions is adding a type to dispatch on,
specifying the notion of distance used:
```julia
function distance_to_set(d::D, v::V, s::S)
        where {D <: AbstractDistance, V, S <: MOI.AbstractSet}
    # ...
end
```

which can for instance encode a p-norm or anything else.
In many cases, there is no ambiguity, and the package defines `DefaultDistance()`
exactly for this.

# Bonus

If you are coming from a class-based object-oriented background, a common
design choice is to define a `Set` abstract class with a method `project_on_set(v::V)` to implement.
This would work for most situations, since a set often implies a domain `V`.
What about the following:

```julia
# Projecting onto the reals (no-op)
project_on_set(v::AbstractVector{T}, s::Reals) where {T <: Real}

# Projecting onto the reals (actual work)
project_on_set(v::AbstractVector{T}, s::Reals) where {T <: Complex}
```

Which "class" should own the implementation in that case?
From what I observed, libraries end up with either an enumeration:

```julia
if typeof(v) == AbstractVector{<:Reals}
    # ...
elseif # ...
end
```

or when the number of possible domains is expected to be low, with several methods:

```julia
# in the set class Reals
function project_real(v::AbstractVector{T}) where {T <: Real}
end

function project_complex(v::AbstractVector{T}) where {T <: Complex}
end

function project_scalar(v::T) where {T <: Real}
end
```

As a last remark, one may wonder why would one define trivial sets as the `MOI.Reals`
or the `MOI.Zeros`. A good example where this is needed is the polyhedral cone:
$$
A x = 0
$$
with $x$ a vector. This makes more sense to define $Ax$ as the function and  
`MOI.Zeros` as the set.
