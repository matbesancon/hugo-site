+++
date = 2020-01-23
draft = false
tags = ["julia", "automatic-differentiation", "optimization", "integer-optimization", "jump"]
title = "Differentiating the discrete: Automatic Differentiation meets Integer Optimization"
summary = """
What can automated gradient computations bring to mathematical optimizers, what does it take to compute?
"""
math = true
diagram = false
+++

![](/img/posts/diff_discrete/graph1.svg)

{{< toc >}}

In continuous convex optimization, duality is often the theoretical foundation for
computing the sensibility of the optimal value of a problem to
one of its parameters. In the non-linear domain, it is fairly standard to assume
one can compute at any point of the domain the function $f(x)$ and gradient
$\nabla f(x)$.  

What about discrete optimization?   
The first thought would be that differentiating
the resolution of a discrete problem does not make sense, the information it yields
since infinitesimal variations in the domain of the variables do not make sense.  

However, three cases come to mind for which asking for gradients makes perfect sense:

1. In mixed-integer linear problems, some variables take continuous values.
All linear expressions are differentiable, and every constraint coefficient,
right-hand-side and objective coefficient can have an attached partial derivative.

2. Even in pure-integer problems, the objective value will be a continuous
function of the coefficients, possibly locally smooth, for which one can get
the partial derivative associated with each weight.

3. We might be interested in computing the derivative of **some** expression
of the variables with respect to some parameters, without this expression
being the objective.

For these points, some duality-based techniques and reformulations can be used,
sometimes very expensive when the input size grows.
One common approach is to first
solve the problem, then fixing the integer variables and re-solving the
continuous part of the problem to compute the dual values associated with
each constraint, and the reduced cost coefficients.
This leads to solving a NP-hard problem, followed by a second solution from
scratch of a linear optimization problem, still, it somehow works.

More than just solving the model and computing results, one major use case
is embarking the result of an optimization problem into another more complete
program. The tricks developed above cannot be integrated with an automated way
of computing derivatives.

# Automatic Differentiation

Automatic Differentiation is far from new, but has known a gain in attention
in the last decade with its used in ML, increasing the usability of the available
libraries. It consists in getting an augmented information out of a function.  

If a function has a type signature `f: a -> b`, the goal is, without modifying
the function, to compute a derivative, which is also a function, which to every
point in the domain, yields a linear map from domain to co-domain `df: a -> (a -o b)`,
where `a -o b` denotes a linear map, regardless of underlying representation (matrix, function, ...).
See the talk and paper[^1] for a type-based formalism of AD if you are ok with programming language formalism.

## Automatic differentiation on a pure-Julia solver

[ConstraintSolver.jl](https://github.com/Wikunia/ConstraintSolver.jl) is a recent
project by [Wikunia](https://github.com/Wikunia). As the name indicates, it is a
[constraint programming](https://en.wikipedia.org/wiki/Constraint_programming)
solver, a more Computer-Science-flavoured approach to integer optimization.
As a Julia solver, it can leverage both multiple dispatch and the type system
to benefit from some features for free. One example of such
feature is automatic differentiation: if your function is generic enough
(not relying on a specific implementation of number types, such as `Float64`),
gradients with respect to some parameters can be computed by calling the function
just once (forward-mode automatic differentiation).

# Example problem: weighted independent set

Let us consider a classical problem in combinatorial optimization, given an undirected graph
$G = (V, E)$, finding a subset of the vertices, such that no two vertices in the
subset are connected by an edge, and that the total weight of the chosen vertices
is maximized.

## Optimization model of the weighted independent set

Formulated as an optimization problem, it looks as follows:

$$\\begin{align}
(\mathcal{P}): \\max\_{x} & \\sum\_{i \\in V} w\_i x\_i \\\\\\\\
\\text{s.t.} \\\\\\\\
& x\_i + x\_j \\leq 1 \\,\\, \\forall (i,j) \\in E \\\\\\\\
& x \\in \\mathbb{B}^{|V|}
\\end{align}
$$

Translated to English, this would be maximizing the weighted sum of picked
vertices, which are decisions living in the $|V|$-th dimensional binary space,
such that for each edge, no two vertices can be chosen.
The differentiable function here is the objective value of such optimization
problem, and the parameters we differentiate with respect to are the weights
attached to each vertex $w_i$. We will denote it $f(w) = \max_x (\mathcal{P}_w)$.

If a vertex $i$ is not chosen in a solution, there are two cases:

- the vertex has the same weight as at least one other, say $j$, such that
swapping $i$ and $j$ in the selected subset does not change the optimal value.
of $\mathcal{P}$.
In that case, there is a kink in the function, a discontinuity of the derivative,
which may not be computed correctly by automatic differentiation.
This is related to the phenomenon of degeneracy in the simplex algorithm,
multiple variables could be chosen equivalently to enter the base.
- there is no other vertex with the same weight, such that swapping the two
maintains the same objective value. In that case, the derivative is $0$,
small enough variations of the weight does not change the solution nor the objective.

If a vertex $i$ is chosen in a solution, then $x_i = 1$, and the corresponding
partial derivative of the weight is $\frac{\partial f(w)}{\partial w_i} = 1$.  

## A Julia implementation

We will import a few packages, mostly MathOptInterface.jl (MOI), the foundation for
constrained optimization, the solver itself, the Test standard lib, and ForwardDiff.jl
for automatic differentiation.

```julia
using Test
import ConstraintSolver
const CS = ConstraintSolver

import MathOptInterface
const MOI = MathOptInterface

import ForwardDiff
```

Let us first write an implementation for the max-weight independent set problem.
We will use a 4-vertex graph, looking as such:

![Weighted graph](/img/posts/diff_discrete/graph2.svg)

The optimal answer here is to pick vertices 1 and 4 (in orange).

```julia
@testset "Max independent set MOI" begin
    matrix = [
        0 1 1 0
        1 0 1 0
        1 1 0 1
        0 0 1 0
    ]
    model = CS.Optimizer()
    x = [MOI.add_constrained_variable(model, MOI.ZeroOne()) for _ in 1:4]
    for i in 1:4, j in 1:4
        if matrix[i,j] == 1 && i < j
            (z, _) = MOI.add_constrained_variable(model, MOI.GreaterThan(0.0))
            MOI.add_constraint(model, z, MOI.Integer())
            MOI.add_constraint(model, z, MOI.LessThan(1.0))
            f = MOI.ScalarAffineFunction(
                [
                    MOI.ScalarAffineTerm(1.0, x[i][1]),
                    MOI.ScalarAffineTerm(1.0, x[j][1]),
                    MOI.ScalarAffineTerm(1.0, z),
                ], 0.0
            )
            MOI.add_constraint(model, f, MOI.EqualTo(1.0))
        end
    end
    weights = [0.2, 0.1, 0.2, 0.1]
    terms = [MOI.ScalarAffineTerm(weights[i], x[i][1]) for i in eachindex(x)]
    objective = MOI.ScalarAffineFunction(terms, 0.0)
    MOI.set(model, MOI.ObjectiveFunction{typeof(objective)}(), objective)
    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.optimize!(model)
    # add some tests
end
```

Why the additional code with`(z, _) = MOI.add_constrained_variable(model, MOI.GreaterThan(0.0))`?
*ConstraintSolver.jl* does not yet support constraints of the type `a x + b y <= c`,
but linear equality constraints are fine, so we can derive equivalent formulations by adding a
slack variable `z`.

For this problem, the tests could be on both the solution and objective value, as follows:
```julia
@test MOI.get(model, MOI.VariablePrimal(), x[4][1]) == 1
@test MOI.get(model, MOI.VariablePrimal(), x[1][1]) == 1
@test MOI.get(model, MOI.ObjectiveValue()) ≈ 0.3
```

An equivalent JuMP version would look look this:
```julia
matrix = [
    0 1 1 0
    1 0 1 0
    1 1 0 1
    0 0 1 0
]
m = Model(with_optimizer(CS.Optimizer))
x = @variable(m, x[1:4], Bin)
for i in 1:4, j in i+1:4
    if matrix[i,j] == 1
        zcomp = @variable(m)
        JuMP.set_binary(zcomp)
        @constraint(m, x[i] + x[j] + zcomp == 1)
    end
end
w = [0.2, 0.1, 0.2, 0.1]
@objective(m, Max, dot(w, x))
optimize!(m)
```

Why are we not using JuMP, which is much more concise and closer to the
mathematical formulation?  

JuMP uses `Float64` for all value types, which means we do not get the benefit of
generic types, while `MathOptInterface` types are parameterized by the numeric type used.
To be fair, maintaining type genericity on a project as large as JuMP
is hard without making performance compromises. JuMP is not built of functions, but
of a model object which contains a mutable state of the problem being constructed,
and building an Algebraic Modelling Language without this incremental build of the
model has not proved successful till now. One day, we may get a powerful declarative
DSL for mathematical optimization, but it has not come yet.  
  
Back to our problem, we now have a way to compute the optimal value and solution.
Let us implement our function $f(w)$:

```julia

function weighted_stable_set(w)
    matrix = [
        0 1 1 0
        1 0 1 0
        1 1 0 1
        0 0 1 0
    ]
    model = CS.Optimizer(solution_type = Real)
    x = [MOI.add_constrained_variable(model, MOI.ZeroOne()) for _ in 1:4]
    for i in 1:4, j in 1:4
        if matrix[i,j] == 1 && i < j
            (z, _) = MOI.add_constrained_variable(model, MOI.GreaterThan(0.0))
            MOI.add_constraint(model, z, MOI.Integer())
            MOI.add_constraint(model, z, MOI.LessThan(1.0))
            f = MOI.ScalarAffineFunction(
                [
                    MOI.ScalarAffineTerm(1.0, x[i][1]),
                    MOI.ScalarAffineTerm(1.0, x[j][1]),
                    MOI.ScalarAffineTerm(1.0, z),
                ], 0.0
            )
            MOI.add_constraint(model, f, MOI.EqualTo(1.0))
        end
    end
    terms = [MOI.ScalarAffineTerm(w[i], x[i][1]) for i in eachindex(x)]
    objective = MOI.ScalarAffineFunction(terms, zero(eltype(w)))
    MOI.set(model, MOI.ObjectiveFunction{typeof(objective)}(), objective)
    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.optimize!(model)
    return MOI.get(model, MOI.ObjectiveValue())
end
```

We can now compute the gradient in one function call with ForwardDiff:

```julia
@testset "Differentiating stable set" begin
    weights = [0.2, 0.1, 0.2, 0.1]
    ∇w = ForwardDiff.gradient(weighted_stable_set, weights)
    @test ∇w[1] ≈ 1
    @test ∇w[4] ≈ 1
    @test ∇w[2] ≈ ∇w[3] ≈ 0
end
```

To understand how this derivative computation can work with just few
function calls (proportional to the size of the input), one must dig
a bit deeper in [Dual Numbers](https://en.wikipedia.org/wiki/Dual_number).
I will shamelessly refer to [my slides](https://matbesancon.xyz/slides/ad4dev#/12)
at the Lambda Lille meetup for an example implementation in Haskell.

# Why not reverse-mode?

I mentioned that the cost of computing the value & derivatives is proportional
to the size of the input, which can increase rapidly for real-world problems.
This is specific to so-called *forward mode* automatic differentiation.
We will not go over the inner details of forward versus reverse.
As a rule of thumb, forward-mode has less overhead, and is better when the
dimension of the output far exceeds the dimension of the input, while
reverse-mode is better when the dimension of the input exceeds the one
of the output.  

## Giving reverse with Zygote a shot

Getting back to our question, the answer is rather down-to-earth,
the reverse-mode I tried simply did not work there.
Reverse-mode requires tracing the normal function call, building a
"tape", this means that it needs a representation of the function
(as a graph or other).
I gave [Zygote.jl](https://github.com/FluxML/Zygote.jl)
a try, which can be done by replacing `ForwardDiff.gradient(f,x)` with
`Zygote.gradient(f, x)` in the snippet above.
Building a representation of the function means *Zygote* must have a
representation of all operations performed. For the moment,
this is still restricted to a subset of the Julia language
(which is far more complex than commonly encountered mathematical functions
built as a single expression). This subset still excludes throwing and
handling exceptions, which is quite present in both ConstraintSolver.jl
and MathOptInterface.  

I have not tried the other reverse tools for the sake of conciseness (and time),
so feel free to check out [Nabla.jl](https://github.com/invenia/Nabla.jl),
[ReverseDiff.jl](https://github.com/JuliaDiff/ReverseDiff.jl)
and [Tracker.jl](https://github.com/FluxML/Tracker.jl).

## How could this be improved?

A first solution could be to move the idiom of Julia from `throw/try/catch`
to handling errors as values, using something like the `Result/Either` type
in Scala / Haskell / Rust and [corresponding libraries](https://github.com/iamed2/ResultTypes.jl).  

Another alternative, currently happening is to keep pushing Zygote to support
more features from Julia, going in the direction of supporting differentiation
of any program, as dynamic as it gets.  

One last option for the particular problem of exception handling would be
to be able to opt-out of input validation, with some `@validate expr`,
with `expr` potentially throwing or handling an error, and a `@nocheck`
or `@nothrows` macro in front of the function call, considering the function
will remain on the happy path and not guaranteeing validity or error messages
otherwise. This works exactly like the `@boundscheck`, `@inbounds` pair for
index validation.

# Conclusion, speculation, prospect

This post is already too long so we'll stop there.
The biggest highlights here are that:

- In discrete problems, we also have some continuous parts.
- Julia's type system allows AD to work almost out of the box in most cases.
- With JuMP and MOI, solving optimization problems is just another algorithmic building block in your Julia program, spitting out results, and derivatives if you make them.
- I believe that's why plugging in solvers developed in C/C++ is fine, but not always what we want. I would be ready to take a performance hit on the computation time of my algorithms to have some hackable, type-generic MILP solver in pure Julia.[^2]

## Special mentions

Thanks a lot to [Wikunia](https://github.com/Wikunia/), first for developing ConstraintSolver.jl,
without which none of this would have been possible, and for the open discussion on the multiple
issues I posted. Don't hesitate to check out his [blog](https://opensourc.es/blog/constraint-solver-1),
where the whole journey from 0 to a constraint solver is documented.  

[^1]: [The simple essence of automatic differentiation](http://conal.net/papers/essence-of-ad/), Conal Elliott, Proceedings of the ACM on Programming Languages (ICFP), 2018
[^2]: I believe a pure-Julia solver could be made as fast as a C/C++ solver, but developing solvers is an enormous amount of work and micro-optimizations, tests on industrial cases. The new [HiGHS](https://highs.dev) solver however shows that one can get pretty good results by developing a linear solver from scratch with all modern techniques already baked in.
