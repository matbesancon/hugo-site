
+++
date = 2019-02-24
draft = false
tags = ["optimization", "julia"]
title = "Multiple dispatch - an example for mathematical optimizers"
summary = """
Leveraging one of Julia central features for clearer formulation of an optimization problem.
"""
math = true

[banner]
image = ""
+++

In a recent pull request on a personal project, I spent some time designing
an intuitive API for a specific problem. After reaching a satisfying result,
I realized this would never have been possible without one of the central
mechanisms of the Julia language: **multiple dispatch**. Feel free to read the
[Julia docs](https://docs.julialang.org/en/v1/manual/methods/) on the topic
or what [Wikipedia](https://en.wikipedia.org/wiki/Multiple_dispatch) has to say
about it.

This post is a walkthrough for multiple dispatch for a case in mathematical
optimization. The first part will introduce the problem context and requires
some notion in mathematical optimization, if this stuff is scary, feel free to
skip to the rest directly.

{{< toc >}}

# Refresher on if-then-else constraints

I promised an example oriented towards mathematical optimization, here it is:
it is common to model constraints with two variables $(x, y)$,
$x$ continuous and $y$ binary stating:

- $y = 0 \Rightarrow x = 0$
- If $y = 1$, there is no specific constraint on $x$

Some examples of models with such constraint:

- **Facility location**: if a wharehouse is not opened, $y = 0$, then the quantity
served by this point has to be $x = 0$, otherwise, the quantity can go up to
the wharehouse capacity.
- **Unit commitment** (a classic problem for power systems): if a power plant
has not been activated for a given hour, then it cannot supply any power,
otherwise, it can supply up to its capacity.
- **Complementarity constraints**: if a dual variable $\lambda$ is 0,
then the corresponding constraint is not active (in non-degenerate cases,
the slack variable is non-zero)

Logical constraints with such if-then-else structure cannot be handled by
established optimization solvers, at least not in an efficient way. There are
two usual ways to implement this, "big-M" type constraints and special-ordered
sets of type 1 `SOS1`.

A SOS1 constraint specifies that out of a set of variables or expressions,
at most one of them can be non-zero. In our case, the if-then-else constraint
can be modeled as:
$$SOS1(x,\, 1-y)$$

Most solvers handling integer variables can use these $SOS1$ constraints
within a branch-and-bound procedure.

The other formulation is using an upper-bound on the $x$ variable, usually
written $M$, hence the name:

$$x \leq M \cdot y $$

If $y=0$, $x$ can be at most 0, otherwise it is bounded by $M$. If $M$
is sufficiently big, the constraint becomes inactive.
However, smaller $M$ values yield tighter formulations, solved more efficiently.
See [Paul Rubin's](https://orinanobworld.blogspot.com/2018/09/choosing-big-m-values.html)
detailed blog post on the subject. If we want bounds as tight as possible, it
is always preferable to choose one bound per constraint, instead of one unique
$M$ for them all, which means we need a majorant of all individual $M$.

As a rule of thumb, big-M constraints are pretty efficient if $M$ is tight,
but if we have no idea about it, SOS1 constraints may be more interesting,
see [1] for recent numerical experiments applied to bilevel problems.

# Modeling if-then-else constraints

Now that the context is set, our task is to model if-then-else constraints
in the best possible way, in a modeling package for instance. We want the user
to specify something as:

{{< highlight julia>}}
function handle_ifthenelse(x, y, method, params)
    # build the constraint with method using params
end
{{< /highlight >}}

Without a dispatch feature baked within the language, we will end up doing
it ourselves, for instance in:

{{< highlight julia>}}
function handle_ifthenelse(x, y, method, params)
    if typeof(method) == SOS1Method
        # model as SOS1Method
    elseif typeof(method) == BigMMethod
        # handle as big M with params
    else
        throw(MethodError("Method unknown"))
    end
end
{{< /highlight >}}

NB: if you have to do that in Julia, there is a `isa(x, T)` function
verifying if `x` is a `T` in a more concise way, this is verifying sub-typing
instead of type equality, which is much more flexible.

The function is way longer than necessary, and will have to be modified every
time. In a more idiomatic way, what we can do is:

{{< highlight julia>}}
struct SOS1Method end
struct BigMMethod end

function handle_ifthenelse(x, y, ::SOS1Method)
    # model as SOS1Method
end

function handle_ifthenelse(x, y, ::BigMMethod, params)
    # handle as big M with params
end
{{< /highlight >}}

Much better here, three things to notice:

- This may look similar to pattern matching in function arguments if you are
familiar with languages as Elixir. However, the method to use can be determined
using static dispatch, i.e. at compile-time.
- We don't need to carry around `params` in the case of the SOS1 method,
since we don't use them, so we can adapt the method signature to pass only
what is needed.
- This code is much easier to document, each method can be documented on
its own type, and the reader can refer to the method directly.

Cherry on top, any user can define their own technique by importing our function
and defining a new behavior:
{{< highlight julia>}}
import OtherPackage # where the function is defined

struct MyNewMethod end

function handle_ifthenelse(x, y, ::MyNewMethod)
    # define a new method for ifthenelse, much more efficient
end
{{< /highlight >}}

# Handling big M in an elegant way

We have seen how to dispatch on the technique, but still we are missing one
point: handling the `params` in big-M formulations. If you have pairs of $(x_j,y_j)$,
then users may want:

$$ x_j \leq M_j \cdot y_j\,\, \forall j $$

Or:
$$ x_j \leq M \cdot y_j\,\, \forall j $$

The first formulation requires a vector of M values, and the second one
requires a scalar. One default option would be to adapt to the most general one:
if several M values are given, build a vector, if there is only one, repeat it
for each $j$. One way to do it using dynamic typing:
{{< highlight julia>}}
struct BigMMethod end

function handle_ifthenelse(x, y, ::BigMMethod, M::Union{Real,AbstractVector{<:Real}})
    if M isa Real
        # handle with one unique M
    else
        # it is a vector
        # handle with each M[j]
    end
end
{{< /highlight >}}

Note that we can constrain the type of M to be either a scalar or a Vector
using `Union` type. Still, this type verification can be done using dispatch,
and we can handle the multiple cases:

{{< highlight julia>}}
struct BigMMethod end

"""
Use one unique big M value
"""
function handle_ifthenelse(x, y, ::BigMMethod, M::Real)
    # handle with one unique M
end

"""
Use a vector of big M value
"""
function handle_ifthenelse(x, y, ::BigMMethod, Mvec::AbstractVector)
    # handle with each Mvec[j]
end
{{< /highlight >}}

This solution is fine, and resolving most things at compile-time.
Also, note that we are defining one signature as a convenience way redirecting
to another.

# Polishing our design: enriched types

The last solution is great, we are dispatching on our algorithm and parameter
types. However, in a realistic research or development work, many more
decisions are taken such as algorithms options, number types, various parameters.
We will likely end up with something similar to:

{{< highlight julia>}}
function do_science(x, y, z,
                    ::Alg1, params_alg_1,
                    ::Alg2, params_alg_2,
                    ::Alg3, # algortithm 3 does not need parameters
                    ::Alg4, params_alg_4)
    # do something with params_alg_1 for Alg1
    # do something with params_alg_2 for Alg2
    # ...
end
{{< /highlight >}}

Requiring users to pass all arguments and types in the correct order.
A long chain of positional arguments like this end makes for error-prone
and cumbersome interfaces. Can we change this? We created all our types as
empty structures `struct A end` and use it just to dispatch. Instead,
we could store adapted parameters within the corresponding type:

{{< highlight julia>}}
struct Alg1
    coefficient::Float64
    direction::Vector{Float64}
end

# define other types

function do_science(x, y, z, a1::Alg1, a2::Alg2, ::Alg3, a4::Alg4)
    # do something with params_alg_1 for Alg1
    # a1.coefficient, a1.direction...
    # do something with Alg2
    # ...
end
{{< /highlight >}}

Getting back to our initial use case of `BigMMethod`, we need to store
the $M$ value(s) in the structure:
{{< highlight julia>}}
struct BigMMethod
    M::Union{Float64, Vector{Float64}}
end
{{< /highlight >}}

This seems fine, however, the Julia compiler cannot know the type of the `M`
field at compile-time, instead, we can use a type parameter here:
{{< highlight julia>}}
struct BigMMethod{MT<:Union{Real, AbstractVector{<:Real}}}
    M::MT
    BigMMethod(M::MT) where {MT} = new{MT}(M)
end
{{< /highlight >}}

When constructing the BigMMethod with this definition, it can be specialized
on `MT`, the type of `M`, two examples of valid definitions are:
{{< highlight julia>}}
BigMMethod(3.0)
# result: BigMMethod{Float64}(3.0)

BigMMethod(3)
# result: BigMMethod{Int}(3)

BigMMethod([3.0, 5.0])
# result BigMMethod{Vector{Float64}}([3.0, 5.0])
{{< /highlight >}}

The advantage is we can now specialize the `handle_ifthenelse`
signature on the type parameter of M, as below:

{{< highlight julia>}}
"""
Use one unique big M value
"""
function handle_ifthenelse(x, y, bm::BigMMethod{<:Real})
    # handle with one unique M bm.M
end

"""
Use a vector of big M value
"""
function handle_ifthenelse(x, y, bm::BigMMethod{<:AbstractVector})
    # handle with each bm.M[j]
end
{{< /highlight >}}

The advantage is a strictly identical signature, whatever the method and
its parameters, users will always call it with:
`handle_ifthenelse(x, y, bm::BigMMethod{<:AbstractVector})`

# Conclusion: avoiding a clarity-flexibility trade-off

In this simple but commonly encountered example, we leveraged multiple dispatch,
the ability to choose a function implementation depending on the type of its
arguments. This helped us define a homogeneous interface for specifying a type
of constraint, specializing on the method (SOS1 or big M) and on the data
available (one M or a vector of M values).

Performance bonus, this design is providing the Julia compiler with strong type
information while remaining flexible for the user. In Julia terminology,
this property is called [type stability](https://docs.julialang.org/en/v1/manual/performance-tips/#Avoid-changing-the-type-of-a-variable-1).
We would not have benefitted from this property if we had used reflection-based
design (with `typeof()` and `isa`).

This idea of using big-M as an example did not come up in the abstract but is
a simplification of the design used in the
[BilevelOptimization.jl](https://github.com/matbesancon/BilevelOptimization.jl)
package. Remember I mentioned complementarity constraints, it is exactly this
use case.

If you are interested in more examples of multiple dispatch and hands-on
use cases for the Julia type system, check out
[these](https://blog.moelf.xyz/real-world-example-for-julia-typing/)
[two](https://white.ucc.asn.au/2018/10/03/Dispatch,-Traits-and-Metaprogramming-Over-Reflection.html)
articles.
Feel free to reach out any way you prefer, [Twitter](https://twitter.com/matbesancon),
[email](/#contact).


--------

Edit 1: thanks BYP for sharp proofreading and constructive critics.  

Edit 2: Thanks Mathieu Tanneau for pointing out the alternative solution of
indicator constraints instead of big M, as documented in [Gurobi](http://www.gurobi.com/documentation/7.5/refman/constraints.html), [CPLEX](https://www.ibm.com/support/knowledgecenter/SSSA5P_12.8.0/ilog.odms.cplex.help/CPLEX/UsrMan/topics/discr_optim/indicator_constr/01_indicators_title_synopsis.html).


Edit 3: For more info on big M constraints and underlying issues, you can read
[Thiago Serra](https://twitter.com/thserra)'s [post](https://thiagoserra.com/2017/06/15/big-m-good-in-practice-bad-in-theory-and-ugly-numerically/), which includes nice visualizations of the problem space.

--------

Sources:

[1] Henrik Carøe Bylling's thesis, KU, http://web.math.ku.dk/noter/filer/phd19hb.pdf
