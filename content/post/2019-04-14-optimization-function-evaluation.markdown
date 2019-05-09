+++
date = 2019-04-29
draft = false
tags = ["optimization", "jump", "functional", "python", "julia"]
title = "Variables are not values: types and expressions in mathematical optimization"
summary = """
Some digging in representations for optimization modelling
"""
math = true

[header]
image = ""
+++

This week, I came across Richard Oberdieck's [post](https://github.com/RichardOberdieck/optimization-blog/blob/master/Why%20'evaluate'%20is%20the%20feature%20I%20am%20missing%20the%20most%20from%20commercial%20MIP%20solvers.ipynb),
"Why 'evaluate' is the feature I am missing the most from commercial MIP solvers".
It would indeed be practical to have for the reasons listed by the author, but
some barriers stand to have it as it is expressed in the snippets presented.  

{{% toc %}}

# Initial problem statement

The author first tests the optimization of a non-linear function through scipy
as such:

{{< highlight python>}}
func = lambda x: np.cos(14.5 * x - 0.3) + (x + 0.2) * x
func(5) # 25.001603108415402
{{< /highlight >}}

So far so good, we are defining a scalar function, passing it a scalar value
at which it evaluates and returns the value, which is what it is
supposed to do.

Now the real gripe comes when moving on to developing against a black box
solver (often commercial, closed-source), commonly used for linear,
mixed-integer problems:
{{< highlight python>}}
import xpress as xp

# Define the model and variables
Model = xp.problem()
x = xp.var(lb=0, ub=10)
Model.addVariable(x)

# Define the objective and solve
test_objective = 5*x
Model.setObjective(test_objective)
Model.solve()
# test_objective(5) does not work
{{< /highlight >}}

One first problem to notice here is that `test_objective`
is at best an expression, not a function, meaning it does
not depend on an input argument but on decision variables declared globally.
That is one point why it cannot be called.  

Now, the rest of this article will be some thoughts on how optimization problems
could be structured and represented in a programming language.  

One hack that could be used is being able to set the values of `x`, but this
needs to be done at the global level:
{{< highlight python>}}
x = xp.var(lb=0, ub=10)
Model.addVariable(x)

# Define the objective
test_objective = 5*x

x.set(5)
# evaluates test_objective with the set value of x
xp.evaluale(test_objective)
{{< /highlight >}}

Having to use the global scope, with an action on one
object (the variable `x`) modifying another
(the `test_objective` expression) is called a side-effect and quickly makes
things confusing as your program grows in complexity. You have to contain the
state in some way and keep track. Keeping track of value changes is
more or less fine, but the hardest part is keeping track
of value definitions. Consider the following example:
{{< highlight python>}}
x = xp.var(lb=0, ub=10)
Model.addVariable(x)
y = xp.var(lb=0, ub=10)
Model.addVariable(y)

# Define the objective and solve
test_objective = 5*x + 2*y
xp.evaluale(test_objective) # no variable set, what should this return?

x.set(5)
xp.evaluale(test_objective) # y is not set, what should this return?
{{< /highlight >}}

# A terminology problem

We are touching a more fundamental problem here, **variables are not values**
and cannot be considered as such. Merging the term "variable" for variables
of your Python/Julia/other program with the decision variables from an
optimization problem creates a great confusion.
Just like variables, the term function is confusing here:
most optimization techniques exploit the problem structure,
think linear, disciplined convex, semi-definite; anything beyond non-linear
differentiable or black-box optimization will use the specific structure
in a specialized algorithm.
If standard functions from your programming language are used, no structure
can be leveraged by the solver, which only sees a function pointer it can pass
values to. So working with mathematical optimization forces you to re-think
what you call "variables" and what you call "functions".  

There is something we can do for the function part, which is defining
arithmetic rules over variables and expressions, which is for instance what
the JuMP modelling framework does:
{{< highlight julia>}}
using JuMP
m = Model()
@variable(m, x1 >= 0)
@variable(m, x2 >= 0)

# random affine function
f(a, b) = π + 3a + 2b

f(x1, x2) # returns a JuMP.GenericAffExpr{Float64,VariableRef}

@variable(m, y)
f(x1, x2) + y  # also builds a JuMP.GenericAffExpr{Float64,VariableRef}
{{< /highlight >}}

This works especially well with affine functions because composing affine
expressions builds other affine expressions but gets more complex any time
other types of constraints are added. For some great resource on types and
functions for mathematical optimization, watch Prof. Madeleine Udell's
[talk](https://www.youtube.com/watch?v=skLGTYs5kAk) at JuliaCon17 (the Julia
syntax is from a pre-1.0 version, it may look funny).  

# Encoding possibilities as sum-types

Getting back to evaluation, to make this work, you need to know what
**values** variables hold. What if the model hasn't been optimized yet?
You could take:
1. A numerical approach and return `NaN` (floating point value for Not-A-Number)
2. An imperative approach and throw an error when we evaluate an expression without values set or the model optimized
3. A typed functional approach and describe the possibility of presence/absence of a value through types

The first approach was JuMP 0.18 and prior, the second is JuMP 0.19 and onward,
the third is the one of interest to us, if we want to describe what is happening
through types.

If you show these three options to a developer used to statically-typed
functional programming, they would tell you that the first option coming to mind
is an *option*, a type which can be either some value or nothing.
In the case of an optimization model, it would be some numerical value
if we have a value to return (that is, we optimized the model and found a
solution).
The problem is, there are many reasons for which you may have or not a value.
What you could do in that case is get more advanced information from your model.
This is the approach `JuMP` is taking with a bunch of model attributes you
can query at any time, see the [documentation](http://www.juliaopt.org/JuMP.jl/stable/solutions/)
for things you can query at any time.

The problem is that querying information on the status of the problem (solved,
unsolved, impossible to solve...) and getting values attached to variables can
be unrelated.
{{< highlight julia>}}
m = Model()
@variable(m, x >= 0)
@variable(m, y >= 0)

# getting status: nothing because not optimized
termination_status(m)
# OPTIMIZE_NOT_CALLED::TerminationStatusCode = 0

primal_status(m) # NO_SOLUTION::ResultStatusCode = 0

JuMP.value(x) # ERROR: NoOptimizer()
# woops, we forgot that we hadn't optimized yet
{{< /highlight >}}

This is indeed because `x` does not exist by itself, there is
a "magic bridge" between the variable `x` and the model `m`.
The computer science term for this "magic bridge" is a
**[side-effect](https://en.wikipedia.org/wiki/Side_effect_(computer_science))**,
the same kind as mentioned earlier when we set the value of a variable at the
global scope. Again, they are fine at a small scale but are often the parts
making a program confusing. Every time I'm reviewing some code by researchers
starting out, the first thing I encourage them to do is to create self-contained
bits of code within functions and remove mutable global state.

# A typed solution for describing mathematical problems

We stated that the variables and model are bound together. In that case, let
us not split them but describe them as one thing and since this one thing
accepts different possible states, we will use
[tagged unions](https://en.wikipedia.org/wiki/Tagged_union), which you can
think of as C enumerations with associated values. Other synonyms for this
construct are sum types (as in OCaml and Haskell).  

We can think of the solution process of an optimization problem at a high level
as a function:
```
solve(Model(Variables, Constraints, Objective)) -> OptimizationResult
```

Where `OptimizationResult` is a sum type:
```
OptimizationResult = Infeasible(info) | Unbounded(info) | Optimal(info) | NearOptimal(info) ...
```

In this case, everything can stay immutable, expressions including objective
and constraints are only used to build the model in input, they can be
evaluated at any points and just describe some expressions of variables.
The **value** of the variables resulting from the optimization are on
available in cases where it makes sense. If the results are stored in the
solution info structure, we can query values where it makes sense only,
here in the `Optimal` and `NearOptimal` cases, with a syntax like:
```
match OptimizationResult {
    Optimal(info) -> value(info, x) # or info.value(x)
    Infeasible(info) -> ...
    Unbounded(info)  -> ...
}
```

Internally, info would keep an association from variables to corresponding
values. No more confusion on what binding of your computer program represents
what symbolic variable of your problem.

So why would we keep using these bindings associated with variables, if they
have never been independent from the problem in the first place? The obvious
reason that comes to mind is practical syntax, we can write expressions in
a quasi-mathematical way (here in JuMP):
{{< highlight julia>}}
@expression(m, 3x + 2x^2 <= 4y)
{{< /highlight >}}

While if variables were attached to the model, the required syntax would be
in the flavour of:
{{< highlight julia>}}
@expression(m, 3m[:x] + 2m[:x]^2 <= 4m[:y])
{{< /highlight >}}

Which quickly becomes hard to read. Can we do better?

# Stealing a solution elsewhere

I stumbled upon an interesting solution to such problem while reading the
documentation for various probabilistic programming languages built on top
of Julia. Here is one example from [Turing.jl](http://turing.ml/docs/get-started)
{{< highlight julia>}}
@model gdemo(x, y) = begin
  s ~ InverseGamma(2,3)
  m ~ Normal(0,sqrt(s))
  x ~ Normal(m, sqrt(s))
  y ~ Normal(m, sqrt(s))
end

# sample from the model using an algorithm
chn = sample(gdemo(1.5, 2), HMC(1000, 0.1, 5))
{{< /highlight >}}

It's just one step away from imagining the same for optimization:
{{< highlight julia>}}
@optim_model linmodel(a, b) = begin
  x[1:10] >= 0
  5 <= y <= 10
  z ∈ 𝔹
  cons1: y - 5 <= 5z
  cons2: x + y >= 3
  Min x
end

result = optimize(linmodel)
{{< /highlight >}}

Naming the constraints would be necessary to retrieve associated dual values.
Retrieving values associated with variables could be done in an associative
structure (think a dictionary/hash map). This structure removes any confusion as
to what belongs where in an optimization model. The variables `x, y, z` are
indeed defined within a given model and explicitly **belong** to it.  

Why are interfaces not built this way? Warning, speculative opinions below:  

One reason is the ubiquity of C & C++ in optimization.
The vast majority of commonly used solvers is built
in either of these, supporting limited programming constructs and based on
passing pointers around to change the values pointed to. Because the solvers are
built like this, interfaces follow the same constructions. Once a dominant
number of interfaces are identical, building something widely different is a
disadvantage with a steeper learning curve.  

Another more nuanced reason is that declarative software is hard to get right.
One often has to build everything upfront, here in the `@optim_model` block.
Getting meaningful errors is much harder, and debugging optimization models
is already a tricky business.  

Lastly, lots of algorithms are based on incremental modifications of models
(think column and row generation), or combinations with other bricks. This
requires some "hackability" of the model. If one looks at Algebraic Modelling
Languages, everything seems to fall apart once you try to implement
decompositions. Usually it involves a completely different syntax for the
decomposition scheme (the imperative part) and for the model declaration
(the declarative part).  

So overall, even though side-effects are a central part of the barrier to
the expression of mathematical optimization in a mathematical, type-based
declarative way, they are needed because of the legacy of solvers and some
algorithms which become hairy to express without it.

# Further resources

As pointed above, Prof. Madeleine Udell's [talk](https://www.youtube.com/watch?v=skLGTYs5kAk)
gives some great perspectives on leveraging types for expressive optimization
modelling. For the brave and avid readers, this
[PhD thesis](https://www.cs.cmu.edu/~rwh/theses/agarwal.pdf) tackles
the semantics of a formal language for optimization problems.
If you have further resources on the subject, please reach out.   

Thanks Richard for the initial post and the following discussion which led to
this post. For shorter and nicely written posts on optimization, go read his
[blog](https://github.com/RichardOberdieck/optimization-blog).  

**Note**: I try never to use the terms "mathematical programming" and
"mathematical program" which are respectively synonyms for
"mathematical optimization" and "mathematical optimization problem" respectively.
We can see why in this post: this kind of context where the term "program"
could refer to a computer program or a mathematical problem becomes very
confusing. We are in 2019 and the term "program" is now universally understood
as a computer program. Moreover, "mathematical programming" merely refers to
a problem specification, it is very confusing to say that
"linear/semi-definite/convex programming" is merely meant as putting together
a bunch of equations, not at all about how to tackle these.

--------
