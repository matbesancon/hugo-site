+++
date = 2019-05-08
draft = false
tags = ["optimization", "jump", "integer-optimization", "julia"]
title = "A take on Benders decomposition in JuMP"
summary = """
Cracking Benders decomposition, one cut at a time.
"""
math = true

[header]
image = ""
+++

Last Friday was a great seminar of the Combinatorial Optimization group in
Paris, celebrating the 85th birthday of Jack Edmonds, one of the founding
researchers of combinatorial optimization, with the notable Blossom matching algorithm.
{{< tweet 1124375711194722304 >}}

Laurence Wolsey and Ivana Ljubic were both giving talks on applications and
developments in Benders decompositions. It also made me want to refresh my
knowledge of the subject and play a bit with a simple implementation.

{{< tweet 1124327078625722368 >}}

{{% toc %}}

## High-level idea

Problem decompositions are used on large-scale optimization problems with a
particular structure. The decomposition turns a compact, hard-to-solve
formulation into an easier one but of great size. In the case of Benders,
great size means a number of constraints growing exponentially
with the size of the input problem. Adding all constraints upfront would be too
costly. Furthermore, in general, only a small fraction of these constraints will be
active in a final solution, the associated algorithm is to generate them incrementally,
re-solve the problem with the new constraint until no relevant constraint can
be found anymore.

We can establish a more general pattern of on-the-fly addition of
information to an optimization problem, which entails two components:

1. An incrementally-built problem, called **Restricted Master Problem** (RMP) in decomposition.
2. An **oracle** or **sub-problem**, taking the problem state and building the new required structure (here a new constraint).

Sounds familiar? Benders can be seen as the "dual twin" of the Dantzig-Wolfe
decomposition I had played with in a [previous post]({{< ref "/post/2018-05-25-colgen2.markdown" >}}).

## Digging into the structure

Now that we have a general idea of the problem at hand, let's see the specifics.
Consider a problem such as:
$$ \min\_{x,y} f(y) + c^T x $$
s.t. $$ G(y) \in \mathcal{S}$$
     $$ A x + D y \geq b $$
     $$ x \in \mathbb{R}^{n_1}\_{+}, y \in \mathcal{Y} $$

We will not consider the constraints specific to $y$ (the first row) nor the
$y$-component of the objective. The key assumption of Benders is that if the $y$
are fixed, the problem on the $x$ variables is fast to solve.
Lots of heuristics use this idea of "fix-and-optimize" to avoid incorporating
the "hard" variables in the problem, Benders leverages several properties to
bring the idea to exact methods (exact in the sense of proven optimality).

Taking the problem above, we can simplify the structure by abstracting away
(i.e. projecting out) the $x$ part:
$$ \min\_{y} f(y) + \phi(y) $$
s.t. $$ G(y) \in \mathcal{S}$$
     $$ y \in \mathcal{Y} $$

Where:
$$ \phi(y) = \min_{x} \\{c^T x, Ax \geq b - Dy, x \geq 0 \\} $$

$\phi(y)$ is a non-smooth function, with $\, dom\ \phi \,$ the feasible domain
of the problem. If you are familiar with bilevel optimization, this could
remind you of the *optimal value function* used to describe lower-level problems.
We will call $SP$ the sub-problem defined in the function $\phi$.

The essence of Benders is to start from an outer-approximation (overly optimistic)
by replacing $\phi$ with a variable $\eta$ which might be higher than the min value,
and then add cuts which progressively constrain the problem.
The initial outer-approximation is:

$$ \min\_{y,\eta} f(y) + \eta $$
s.t. $$ G(y) \in \mathcal{S}$$
     $$ y \in \mathcal{Y} $$

Of course since $\eta$ is unconstrained, the problem will start unbounded.
What are valid cuts for this? Let us define the dual of the sub-problem $SP$,
which we will name $DSP$:
$$ \max\_{\alpha} (b - Dy)^T \alpha  $$
s.t. $$ A^T \alpha \leq c $$
     $$ \alpha \geq 0 $$

Given that $\eta \geq min SP$, by duality, $\eta \geq max DSP$.
Furthermore, by strong duality of linear problems, if $\eta = \min \max\_{y} DSP$,
it is exactly equal to the minimum of $\phi(y)$ and yields the optimal solution.

One thing to note about the feasible domain of $DSP$, it does not depend on
the value of $y$. This means $z$ feasible for all values of the dual is
equivalent to being feasible for all extreme points and rays of the dual
polyhedron. Each of these can yield a new cut to add to the relaxed problem.
For the sake of conciseness, I will not go into details on the case when
the sub-problem is not feasible for a $y$ solution. Briefly, this is equivalent
to the dual being unbounded, it thus defines an extreme ray which must be cut
out. For more details, you can check [these lecture notes](http://www.iems.ucf.edu/qzheng/grpmbr/seminar/Yuping_Intro_to_BendersDecomp.pdf).

## A JuMP implementation

We will define a simple implementation using [JuMP](http://www.juliaopt.org/JuMP.jl/stable/),
a generic optimization modeling library on top of Julia, usable with various
solvers. Since the master and sub-problem resolutions are completely independent,
they can be solved in separated software components, even with different solvers.
To highlight this, we will use [SCIP](https://github.com/SCIP-Interfaces/SCIP.jl)
to solve the master problem and COIN-OR's [Clp](https://github.com/juliaopt/Clp.jl)
to solve the sub-problem.  

We can start by importing the required packages:

{{< highlight julia>}}
using JuMP
import SCIP
import Clp
using LinearAlgebra: dot
{{< /highlight >}}

### Defining and solving dual sub-problems

Let us store static sub-problem data in a structure:

{{< highlight julia>}}
struct SubProblemData
    b::Vector{Float64}
    D::Matrix{Float64}
    A::Matrix{Float64}
    c::Vector{Float64}
end
{{< /highlight >}}

And the dual sub-problem is entirely contained in another structure:

{{< highlight julia>}}
struct DualSubProblem
    data::SubProblemData
    α::Vector{VariableRef}
    m::Model
end

function DualSubProblem(d::SubProblemData, m::Model)
    α = @variable(m, α[i = 1:size(d.A, 1)] >= 0)
    @constraint(m, dot(d.A, α) .<= d.c)
    return DualSubProblem(d, α, m)
end
{{< /highlight >}}

The `DualSubProblem` is constructed from the static data and a JuMP model.
We mentioned that the feasible space of the sub-problem is independent of the
value of $y$, thus we can add the constraint right away. Only to optimize it
do we require the $\hat{y}$ value, which is used to set the objective.
We can then either return a feasibility cut or optimality cut depending on
the solution status of the dual sub-problem:

{{< highlight julia>}}
function JuMP.optimize!(sp::DualSubProblem, yh)
    obj = sp.data.b .- sp.data.D * yh
    @objective(sp.m, Max, dot(obj, sp.α))
    optimize!(sp.m)
    st = termination_status(sp.m)
    if st == MOI.OPTIMAL
        α = JuMP.value.(sp.α)
        return (:OptimalityCut, α)
    elseif st == MOI.DUAL_INFEASIBLE
        return (:FeasibilityCut, α)
    else
        error("DualSubProblem error: status $status")
    end
end
{{< /highlight >}}

### Iterating on the master problem

The main part of the resolution holds here in three steps.

1. Initialize a master problem with variables $(y,\eta)$
2. Optimize and pass the $\hat{y}$ value to the sub-problem.
3. Get back a dual value $\alpha$ from the dual sub-problem
4. Is the constraint generated by the $\alpha$ value already respected?
- If yes, the solution is optimal.
- If no, add the corresponding cut to the master problem, return to 2.

{{< highlight julia>}}
function benders_optimize!(m::Model, y::Vector{VariableRef}, sd::SubProblemData, sp_optimizer, f::Union{Function,Type}; eta_bound::Real = -1000.0)
    subproblem = Model(with_optimizer(sp_optimizer))
    dsp = DualSubProblem(sd, subproblem)
    @variable(m, η >= eta_bound)
    @objective(m, Min, f(y) + η)
    optimize!(m)
    st = MOI.get(m, MOI.TerminationStatus())
    # restricted master has a solution or is unbounded
    nopt_cons, nfeas_cons = (0, 0)
    @info "Initial status $st"
    cuts = Tuple{Symbol, Vector{Float64}}[]
    while (st == MOI.DUAL_INFEASIBLE) || (st == MOI.OPTIMAL)
        optimize!(m)
        st = MOI.get(m, MOI.TerminationStatus())
        ŷ = JuMP.value.(y)
        η0 = JuMP.value(η)
        (res, α) = optimize!(dsp, ŷ)
        if res == :OptimalityCut
            @info "Optimality cut found"
            if η0 ≥ dot(α, (dsp.data.b - dsp.data.D * ŷ))
                break
            else
                nopt_cons += 1
                @constraint(m, η ≥ dot(α, (dsp.data.b - dsp.data.D * y)))
            end
        else
            @info "Feasibility cut found"
            nfeas_cons += 1
            @constraint(m, 0 ≥ dot(α, (dsp.data.b - dsp.data.D * y)))
        end
        push!(cuts, (res, α))
    end
    return (m, y, cuts, nopt_cons, nfeas_cons)
end
{{< /highlight >}}

Note that we pass the function an already-built model with variable $y$ defined.
This allows for a prior flexible definition of constraints of the type:
$$y \in \mathcal{Y}$$
$$G(y) \in \mathcal{S}$$

Also, we return the $\alpha$ values found by the sub-problems and the number of
cuts of each type. Finally, one "hack" I'm using is to give an arbitrary lower
bound on the $\eta$ value, making it (almost) sure to have a bounded initial
problem and thus a defined initial solution $y$.  

We will re-use the small example from the lecture notes above:

{{< highlight julia>}}
function test_data()
    c = [2., 3.]
    A = [1 2;2 -1]
    D = zeros(2, 1) .+ [1, 3]
    b = [3, 4]
    return SimpleBenders.SubProblemData(b, D, A, c)
end

data = test_data()
# objective function on y
f(v) = 2v[1]
# initialize the problem
m = Model(with_optimizer(SCIP.Optimizer))
@variable(m, y[j=1:1] >= 0)
# solve and voilà
(m, y, cuts, nopt_cons, nfeas_cons) = SimpleBenders.benders_optimize!(m, y, data, () -> Clp.Optimizer(LogLevel = 0), f)
{{< /highlight >}}

The full code is available on
[Github](https://github.com/matbesancon/SimpleBenders.jl), run it, modify it
and don't hesitate to submit pull requests and issues, I'm sure there are :)

Benders is a central pillar for various problems in optimization, research is
still very active to bring it to non-linear convex or non-convex sub-problems
where duality cannot be used. If you liked this post or have questions,
don't hesitate to react or ping me on [Twitter](https://twitter.com/matbesancon).

--------
