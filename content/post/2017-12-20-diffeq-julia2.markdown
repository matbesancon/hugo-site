+++
date = 2017-12-20
draft = false
tags = ["julia", "modeling", "numerical-techniques", "applied-math", "optimization"]
title = "DifferentialEquations.jl - part 2: decision from the model"
summary = """
Now that we've built a model, let's use it to make the best decision
"""
math = true

[header]
image = "posts/DiffEq/Lorenz.svg"
+++

In the [last article](/post/2017-12-14-diffeq-julia), we explored different modeling options for a
three-component systems which could represent the dynamics of a chemical
reaction or a disease propagation in a population. Building on top of this
model, we will formulate a desirable outcome and find a decision which
maximizes this outcome.

> In addition to the packages imported in the last post,
we will also use [BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl):

{{< highlight julia >}}
import DifferentialEquations
const DiffEq = DifferentialEquations
import Plots
import BlackBoxOptim
{{< /highlight >}}

## The model

The same chemical system with three components, A, B and R will be used:
$$A + B → 2B$$  $$B → R$$

The reactor where the reaction occurs must remain active for one minute.
Let's imagine that $B$ is our valuable component while $R$ is a waste.
We want to maximize the quantity of $B$ present within the system after one
minute, that's the objective function. For that purpose, we can choose to add
a certain quantity of new $A$ within the reactor at any point.
$$t\_{inject} ∈ [0,t\_{final}]$$.

## Implementing the injection

There is one major feature of DifferentialEquations.jl we haven't explored yet:
the [event handling system](http://docs.juliadiffeq.org/latest/features/callback_functions.html).
This allows for the system state to change at a particular point in time,
depending on conditions on the time, state, etc...

{{< highlight julia >}}
# defining the problem
const α = 0.8
const β = 3.0
diffeq = function(t, u, du)
    du[1] = - α * u[1] * u[2]
    du[2] = α * u[1] * u[2] - β * u[2]
    du[3] = β * u[2]
end
u₀ = [49.0;1.0;0.0]
tspan = (0.0, 1.0)
prob = DiffEq.ODEProblem(diffeq, u₀, tspan)

const A_inj = 30
inject_new = function(t0)
    condition(t, u, integrator) = t0 - t
    affect! = function(integrator)
        integrator.u[1] = integrator.u[1] + A_inj
    end
    callback = DiffEq.ContinuousCallback(condition, affect!)
    sol = DiffEq.solve(prob, callback=callback)
    sol
end

# trying it out with an injection at t=0.4
sol = inject_new(0.4)
Plots.plot(sol)
{{< /highlight >}}

![Injection simulation](/img/posts/DiffEq/inject.png)

The `ContinuousCallback` construct is the central element here, it takes as
information:

* When to trigger the event, implemented as the `condition` function. It triggers
when this function reaches 0, which is here the case when $t = t₀$.
* What to do with the state at that moment. The state is encapsulated within
the *integrator* variable. In our case, we add 30 units to the concentration in *A*.

As we can see on the plot, a discontinuity appears on the concentration in A
at the injection time, the concentration in B restarts increasing.  

## Finding the optimal injection time: visual approach

From the previously built function, we can get the whole solution with a given
injection time, and from that the final state of the system.

{{< highlight julia >}}
tinj_span = 0.05:0.005:0.95
final_b = [inject_new(tinj).u[end][2] for tinj in tinj_span]
Plots.plot(tinj_span, final_b)
{{< /highlight >}}

Using a plain for comprehension, we fetch the solution of the simulation for
the callback built with each $t\_{inject}$.

![Quantity of B](/img/posts/DiffEq/optimal_inject.png)

Injecting $A$ too soon lets too much time for the created $B$ to turn into $R$,
but injecting it too late does not let enough time for $B$ to be produced from
the injected $A$. The optimum seems to be around ≈ 0.82,

## Finding the optimum using BlackBoxOptim.jl

The package requires an objective function which takes a vector as input.
In our case, the decision is modeled as a single variable (the injection time),
**it's crucial to make the objective use a vector nonetheless**, otherwise
calling the solver will just explode with cryptic errors.

{{< highlight julia >}}
compute_finalb = tinj -> -1 * inject_new(tinj[1]).u[end][2]
# trust the default algorithm
BlackBoxOptim.bboptimize(compute_finalb, SearchRange=(0.1,0.9), NumDimensions=1)
# use probabilistic descent
BlackBoxOptim.bboptimize(compute_finalb, SearchRange=(0.1,0.9), NumDimensions=1, Method=:probabilistic_descent)
{{< /highlight >}}

The function `inject_new` we defined above returns the complete solution
of the simulation, we get the state matrix `u`, from which we extract the
final state `u[end]`, and then the second component, the concentration in
B: `u[end][2]`. The black box optimizer minimizes the objective, while we want
to maximize the final concentration of B, hence the -1 multiplier used for  
`compute_finalb`.  

The `bboptimize` function can also be passed a `Method` argument specifying
the optimization algorithm. In this case, the function is smooth, so we can
suppose gradient estimation methods would work pretty well. We also let the
default algorithm (differential evolution) be used. After some lines logging
the progress on the search, we obtain the following for both methods:
```
Best candidate found: [0.835558]
Fitness: -24.039369448
```

More importantly, we can refer to the number of evaluations of the objective
function as a measure of the algorithm performance, combined with the time taken.

For the probabilistic descent:
```
Optimization stopped after 10001 steps and 10.565439939498901 seconds
Steps per second = 946.5767689058794
Function evals per second = 1784.6866867802482
Improvements/step = 0.0
Total function evaluations = 18856
```

For the differential evolution:
```
Optimization stopped after 10001 steps and 5.897292137145996 seconds
Steps per second = 1695.863078751937
Function evals per second = 1712.8200138459472
Improvements/step = 0.1078
Total function evaluations = 10101
```

We found the best injection time (0.835558), and the corresponding final
concentration (24.04).

## Extending the model

The decision over one variable was pretty straightforward. We are going to
extend it by changing how the $A$ component is added at $t\_{inject}$.
Instead of being completely dissolved, a part of the component will keep being
poured in after $t\_{inject}$. So the decision will be composed of two variables:  

* The time of the beginning of the injection
* The part of $A$ to inject directly and the part to inject in a
continuous fashion. We will note the fraction injected directly $\delta$.

Given a fixed available quantity $A₀$ and a fraction to inject directly $\delta$,
the concentration in A is increased of $\delta \cdot A₀$ at time $t\_{inject}$,
after which the rate of change of the concentration in A is increased by a
constant amount, until the total amount of A injected (directly and over time)
is equal to the planned quantity.  

We need a new variable in the state of the system, $u\_4(t)$, which stands
for the input flow of A being active or not.

* $u(t) = 0$ if $t < t\_{inject}$
* $u(t) = 0$ if the total flow of A which has been injected is equal to the planned quantity
* $u(t) = \dot{A}\ $ otherwise, with $\dot{A}\ $ the rate at which A is being poured.

## New Julia equations

We already built the key components in the previous sections. This time we need
two events:

* A is directly injected at $t\_{inject}$, and then starts being poured at constant rate
* A stops being poured when the total quantity has been used

{{< highlight julia >}}
const inj_quantity = 30.0;
const inj_rate = 40.0;

diffeq_extended = function(t, u, du)
    du[1] = - α * u[1] * u[2] + u[4]
    du[2] = α * u[1] * u[2] - β * u[2]
    du[3] = β * u[2]
    du[4] = 0.0
end

u₀ = [49.0;1.0;0.0;0.0]
tspan = (0.0, 1.0)
prob = DiffEq.ODEProblem(diffeq_extended, u₀, tspan)
{{< /highlight >}}

We wrap the solution building process into a function taking the starting time
and the fraction being directly injected as parameters:

{{< highlight julia >}}
inject_progressive = function(t0, direct_frac)
    condition_start(t, u, integrator) = t0 - t
    affect_start! = function(integrator)
        integrator.u[1] = integrator.u[1] + inj_quantity * direct_frac
        integrator.u[4] = inj_rate
    end
    callback_start = DiffEq.ContinuousCallback(
        condition_start, affect_start!, save_positions=(true, true)
    )
    condition_end(t, u, integrator) = (t - t0) * inj_rate - inj_quantity * (1 - direct_frac)
    affect_end! = function(integrator)
        integrator.u[4] = 0.0
    end
    callback_end = DiffEq.ContinuousCallback(condition_end, affect_end!, save_positions=(true, true))
    sol = DiffEq.solve(prob, callback=DiffEq.CallbackSet(callback_start, callback_end), dtmax=0.005)
end

Plots.plot(inject_progressive(0.6,0.6))
{{< /highlight >}}

We can notice `callback_start` being identical to the model we previously built,
while `condition_end` corresponds to the time when the total injected
quantity reaches `inj_quantity`. The first events activates $u₄$ and sets it
to the nominal flow, while the second callback resets it to 0.

![Constant rate](/img/posts/DiffEq/const_rate.png)

BlackBoxOptim.jl can be re-used to determine the optimal decision:

{{< highlight julia >}}
objective = function(x)
    sol = inject_progressive(x[1], x[2])
    -sol.u[end][2]
end
BlackBoxOptim.bboptimize(objective, SearchRange=[(0.1,0.9),(0.0,1.0)], NumDimensions=2)
{{< /highlight >}}

The optimal solution corresponds to a complete direct injection
($\delta \approx 1$) with $t\_{inject}\^{opt}$ identical to the previous model.
This means pouring the A component in a continuous fashion does not allow to
produce more $B$ at the end of the minute.

## Conclusion

We could still built on top of this model to keep refining it, taking more
phenomena into account (what if the reactions produce heat and are sensitive
to temperature?). The structures describing models built with
DifferentialEquations.jl are transparent and easy to use for further manipulations.

One point on which I place expectations is some additional interoperability
between DifferentialEquations.jl and [JuMP](https://github.com/JuliaOpt/JuMP.jl),
a Julia meta-package for optimization. Some great work was already performed to
combine the two systems, one use case that has been described is the parameter
identification problem (given the evolution of concentration in the system,
identify the α and β parameters).  

But given that the function I built from a parameter was a black box
(without an explicit formula, not a gradient), I had to use BlackBoxOptim,
which is amazingly straightforward, but feels a bit overkill for smooth
functions as presented here. Maybe there is a different way to build the
objective function, using parametrized functions for instance, which could
make it transparent to optimization solvers.  

If somebody has info on that last point or feedback, additional info you'd like
to share regarding this post, hit me on [Twitter](https://twitter.com/MathieuBesancon).
Thanks for reading!

-----
<font size="0.7">
 [1] Cover image: Lorenz attractor on [Wikimedia](https://commons.wikimedia.org/wiki/File:Lorenz_attractor2.svg), again.
</font>
