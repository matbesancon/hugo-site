+++
date = 2022-04-29
draft = false
tags = ["julia", "optimization", "scip"]
title = "Pruning the expression tree with recursive value identification"
summary = """
"""
math = true
diagram = false
[header]
+++

Today was the release of [SCIP.jl](https://github.com/scipopt/SCIP.jl) v0.11, the first release switching to SCIP 8.
The major change in this (massive) release was the rewrite of the nonlinear optimization part, using a so-called expression framework.
The rewrite of the wrapper had some fairly tedious parts, debugging C shared libraries is quickly a mess with cryptic error messages.
But the nonlinear rewrite gave me the opportunity to tweak the way Julia expressions are passed to SCIP in a minor way.

{{< toc >}}

# SCIP expressions

I will not go in depth into the new expression framework and will instead reference [these slides](https://scipopt.org/workshop2020/slides/minlp.pdf)
but more importantly [the SCIP 8 release report](https://arxiv.org/abs/2112.08872)

The key part is that in a nonlinear expression, each operand is defined as an *expression handler*, and new ones can be introduced by users.
Several specialized constraint types or *constraint handlers* in SCIP terminology were also removed, using the expression framework with
a generic nonlinear constraint instead.

# The Julia wrapper initial framework

As a Lisp-inspired language, (some would even a Lisp dialect),
Julia is a homoiconic language: valid Julia code can always be represented and stored in a primitive data structure.
In this case, the tree-like structure is `Expr` with fields `head` and `args`:

```julia
julia> expr = :(3 + 1/x)
:(3 + 1 / x)

julia> expr.head
:call

julia> expr.args
3-element Vector{Any}:
  :+
 3
  :(1 / x)
```

The SCIP.jl wrapper recursively destructures the Julia expression and builds up corresponding SCIP
expressions, a SCIP data structure defined either as a leaf (a simple value or a variable)
or as an operand and a number of subexpressions.
This is done through a `push_expr!` function which either:
- Creates and returns a single variable expression if the expression is a variable
- Creates and returns a single value expression if the expression is a constant
- If the expression is a function `f(arg1, arg2...)`, calls `push_expr!` on all arguments, and then creates and returns the SCIP expression corresponding to `f`.

One part remains problematic, imagine an expression like `3 * exp(x) + 0.5 * f(4.3)`, where `f`
is not a primitive supported by SCIP. It should not have to be indeed, because that part of the expression
could be evaluated at expression compile-time. But if one is walking down the expression sub-parts,
there was no way to know that a given part is a pure value, the expression-constructing procedure would
first create a SCIP expression for 4.3 and then try to find a function for `f` to apply with this expression
pointer as argument. This was the use case initially reported in [this issue](https://github.com/scipopt/SCIP.jl/issues/166)
at a time when SCIP did not support trigonometric functions yet.

Another motivation for solving this issue is on the computational and memory burden.
Imagine your expression is now `3 * exp(x) + 0.1 * cos(0.1) + 0.2 * cos(0.2) + ... + 100.0 * cos(100.0)`.
This will require producing 2 * 1000 expressions for a constant, declared, allocated and passed down to SCIP.
The solver will then likely preprocess all constant expressions to reduce them down, so it ends up being a lot of
work done on one end to undo immediately on the other.

# A lazified expression declaration

Make `push_expr!` return two values `(scip_expr, pure_value)`, with the second being a Boolean for whether the expression is a pure value or not.
At any leaf computing `f(arg1, arg2...)`.

If the expression of all arguments are `pure_value`, do **not** compute the expression and just return a null pointer, `pure_value` is true for this expression.

If at least one of the arguments is not a `pure_value`, we need to compute the actual expression. None of the `pure_value` arguments were declared as SCIP expressions yet, we create a leaf value expression for them with `Meta.eval(arg_i)`. The non-pure value arguments already have a correct corresponding SCIP expression pointer. `pure_value` is false for this expression.

Note here that we are traversing some sub-expressions twice, once when walking down the tree and once more hidden with `Meta.eval(arg_i)` which computes the value for said expression, where we delegate the expression value computation to Julia. An alternative would be to return a triplet from every `push_expr!` call `(expr_pointer, pure_value, val)` and evaluate at
each `pure_value` node the value of `f(args...)`, with the value of the arguments already computed. This would however complexity the code in the wrapper with no advantage of the runtime,
the expression evaluation is not a bottleneck for expressions that can realistically be tackled by a global optimization solver like SCIP.
