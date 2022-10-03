+++
date = 2022-10-03
draft = false
tags = ["julia", "optimization", "scip", "integer-optimization"]
title = "SCIP plugins and the cut selection interface"
summary = """
"""
math = true
diagram = false
[header]
+++

This is a short post on the cut selection mechanism in SCIP
and things I used for its implementation in the [SCIP.jl](https://github.com/scipopt/SCIP.jl) Julia wrapper.
You can check out the corresponding [pull request](https://github.com/scipopt/SCIP.jl/pull/245) for completeness.

{{< toc >}}

# Callbacks?

The space of mixed-integer optimization solvers is mostly divided between
commercial closed-source and academic solvers open in source code.
In the second cluster, [SCIP](https://scipopt.org) stands out for the tunability of the solving
process, like all solvers through some parameters but more importantly through *callbacks*.

Callbacks are functions that are passed to a solver (or another function more generally) by the user
with an expected behavior.
Conceptually, they are the most elementary building block for *Inversion of Control*.

A basic callback system implemented in many solvers is a printing or logging callback,
the user function is called at every iteration of a solving process with some iteration-specific information to print or log,
here is a Julia example with gradient descent:
```julia
function my_solver(x0::AbstractVector{T}, gradient_function::Function, callback::Function)
    x = x0
    while !terminated
        g = gradient_function(x)
        stepsize = compute_stepsize(x)
        callback(x, g, stepsize)
        x = x - gamma * g
        terminated = ...
    end
    return x
end
```

In this example, the callback is not expected to modify the solving process but contains all the information
about the current state and can record or print data.

The C version of it would be something like:
```c
#include <stdbool.h>

// defining the function types
typedef void (*Gradient)(double* gradient , double* x);
typedef void (*Callback)(double* gradient , double* x, double stepsize);

void my_solver(double* x, Gradient gradient_function, Callback callback) {
    double* gradient = initialize_gradient(x);
    double stepsize;
    bool terminated = false;
    while (!terminated) {
        gradient_function(gradient, x);
        stepsize = compute_stepsize(gradient, x);
        callback(x, gradient, stepsize);
        update_iterate(x, gradient, stepsize);
        terminated = ...;
    }
}
```

# SCIP plugins

SCIP plugins are generic interfaces for certain components of the solver such as cutting plane generators
(also called separators), heuristics, constraints.
Think of interfaces as a bundle of functions that have a grouped logic, they are another step in Inversion of Control
often referred to as *Dependency Injection*.
Since C does not have a native mechanism for this (think C++ abstract classes, Haskell data classes, Rust traits),
the SCIP developers just cooked up their own with macros for the sugar of an interface.

SCIP plugins are listed on the page for [how to add them](https://www.scipopt.org/doc/html/HOWTOADD.php).

# Cut selection

A cut is a linear inequality $\alpha^T x \leq \beta$ such that:
1. at least one optimal solution remains feasible with that cut (in general, cuts will not remove optimal solutions),
2. a part of the feasible region of the convex relaxation is cut off (otherwise, the cut is trivial and useless).

In SCIP 8, a cut selector plugin was added, see the description in [the SCIP 8 release report](https://arxiv.org/abs/2112.08872).
It was originally motivated by [this paper](https://arxiv.org/abs/2202.10962) including a subset of the SCIP 8 authors
on adaptive cut selection, showing that a fixed selection rule could perform poorly.

There is ongoing research on cut selection at ZIB and other places, having seen that smarter rules do make a difference.

The selection problem can be stated as follows: given a set of previously generated cuts (some might be locally valid at the current node only),
which ones should be added to the linear relaxation before continuing the branching process?

Instinctively, a cut should be added only if it improves the current relaxation. If the current linear programming relaxation solution
is not cut off by a cut, that cut is probably not relevant at the moment, even though it might cut off another part of the polytope.
Example of criteria currently used to determine whether a cut should be added are:
- efficacy: how far is the current LP relaxation from the new hyperplane,
- sparsity: how many non-zeros coefficients does the cut have
- orthogonality (to other constraints), a cut that is parallel to another cut means that one of them is redundant.

Instead of trying to come up with fixed metrics and a fixed rule, the cut selector allows users to define their own rule
by examining all cuts and the current state of the solver.

# Cut selector interface

I will focus here on the Julia interface, some parts are very similar to what would be implemented
by a C or C++ user, except for memory management that is done automatically here.

The cut selector interface is pretty simple, it consists on the Julia side of
- a structure that needs to be a subtype of `AbstractCutSelector`,
- one key function that has to be implemented.

The low-level cut selection function that SCIP expects has the following signature,
I will give the Julia version but the C one is strictly identical:

```julia
function select_cut_lowlevel(
    scip::Ptr{SCIP},
    cutsel_::Ptr{SCIP_CUTSEL},
    cuts_::Ptr{Ptr{SCIP_ROW}},
    ncuts::Cint,
    forced_cuts_::Ptr{Ptr{SCIP_ROW}},
    nforced_cuts::Cint,
    root_::SCIP_Bool,
    maxnslectedcuts::Cint,
    nselectedcuts_::Ptr{Cint},
    result_::Ptr{SCIP_RESULT}
)::SCIP_RETCODE
```

The function takes a pointer to the SCIP model, the pointer to our cut selection plugin that
is stored within SCIP, a vector of cuts (passed as a pointer and a length),
a vector of **forced** cuts, that is, cuts that will be added to the linear relaxation independently of the
cut selection procedure, whether we are at the root node of the branch-and-bound tree and what is the maximum number of cuts
we are allowed to accept.

Forced cuts are interesting to have because they let us avoid adding redundant cuts.
This function is expected to sort the array of cuts by putting the selected cuts first
and updating the value of `nselectedcuts_` and `result_`.

This interface is quite low-level from a Julia perspective, and passing all arguments C-style is cumbersome.
The SCIP.jl wrapper thus lets users define their selector with a single function to implement:

```julia
function select_cuts(
    cutsel::AbstractCutSelector,
    scip::Ptr{SCIP_},
    cuts::Vector{Ptr{SCIP_ROW}},
    forced_cuts::Vector{Ptr{SCIP_ROW}},
    root::Bool,
    maxnslectedcuts::Integer,
    )
end
```

This function returns the output values in a tuple `(retcode, nselectedcuts, result)`
instead of passing them as arguments and lets the user manipulate vectors instead of raw pointers.
The raw function can be passed to C, but the user only see the idiomatic Julia one.
On each of the `Ptr{SCIP_ROW}`, the user can call any of the C functions, all SCIP C functions are available in
the `SCIP.LibSCIP` submodule. They can compute for instance parallelism between rows, get the number of non-zeros,
or get the coefficients $\alpha$, left and right-hand side (rows are two-sided in SCIP) and compute quantities of interest themselves.

Here is the complete example for a cut selector that never selects any cut:
```julia
# the struct needs to be mutable here
mutable struct PickySelector <: SCIP.AbstractCutSelector
end

function SCIP.select_cuts(
        cutsel::PickySelector, scip, cuts::Vector{Ptr{SCIP_ROW}},
        forced_cuts::Vector{Ptr{SCIP_ROW}}, root::Bool, maxnslectedcuts::Integer,
    )
    # return code, number of cuts, status
    return (SCIP.SCIP_OKAY, 0, SCIP.SCIP_SUCCESS)
end
```

We have now defined a cut selector that implements the interface but SCIP does not know about it yet.
In the Julia interface, we added a wrapper function that takes care of the plumbing parts:
```julia
cutselector = PickySelector()
o = SCIP.Optimizer()
SCIP.include_cutsel(o, cutselector)
```

## Some C-Julia magic

The simplicity of the interface is enabled by some nice-to-have features.

`@cfunction` lets us take a Julia function that is compatible with C, that is,
it can accept arguments that are compatible with the C type system, and produces a function pointer for it.
In our case, a function pointer is precisely what we need to pass to SCIP.
But to create a C function pointer, we need the full concrete type declared ahead of time,
`@cfunction` thus takes the return type and a tuple of the argument types to create the pointer:
```julia
func_pointer = @cfunction(
    select_cut_lowlevel,
    SCIP_RETCODE,
    (
        Ptr{SCIP_}, Ptr{SCIP_CUTSEL},
        Ptr{Ptr{SCIP_ROW}}, Cint, Ptr{Ptr{SCIP_ROW}},
        Cint, SCIP_Bool, Cint, Ptr{Cint}, Ptr{SCIP_RESULT}
    ),
)
```

The other nice-to-have feature here is wrapping a Julia Vector around a raw data pointer without copying data,
remember that in the low-level interface, cuts are passed as a pointer and a number of elements
`(cuts::Ptr{Ptr{SCIP_ROW}}, ncuts::Cint)`.
We can wrap a `Vector` around it directly:
```julia
cut_vector = unsafe_wrap(Vector, cuts, ncuts)
```

A very useful use case for this is shown in the test, one can get the cut vector, and then sort them in-place
with a custom criterion:
```julia
sort!(cut_vector, by=my_selection_criterion)
```

This will sort the elements in-place, thus modifying the array passed as a double pointer.
