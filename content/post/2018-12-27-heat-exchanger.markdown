+++
date = 2018-12-27
draft = false
tags = ["engineering", "julia"]
title = "Winter warm-up: toy models for heat exchangers"
summary = """

"""
math = true

[header]
image = "/posts/heatex/frozen_land.jpg"
+++

Enjoying the calm of the frozen eastern French countryside for the last week of 2018,
I was struck by nostalgia while reading a SIAM news article [1] on a
near-reversible heat exchange between two flows and decided to dust off my
thermodynamics books (especially [2]).

Research in mathematical optimization was not the
obvious path I was on a couple years ago. The joint bachelor-master's program
I followed in France was in process engineering, a discipline crossing
transfer phenomena (heat exchange, fluid mechanics, thermodynamics), control,
knowledge of the matter transformations at hand
(chemical, biochemical, nuclear reactions) and industrial engineering
(see note at the end of this page).

**Hypotheses** Throughout the article, we will use a set of flow hypotheses
which build up the core of our model for heat exchange.
These can seem odd but are pretty common in process engineering and
realistic in many applications.

1. The two flows advance in successive "layers".
2. Each layer has a homogeneous temperature; we therefore ignore boundary layer effects.
3. Successive layers do not exchange matter nor heat. The rationale behind this
is that the temperature difference between fluids is significantly higher than between layers.
4. Pressure losses in the exchanger does not release a significant heat compared to
the fluid heat exchange.
5. The fluid and wall properties are constant with temperature.

## Starting simple: parallel flow heat exchange

In this model, both flows enter the exchanger on the same side, one at a
hot temperature, the other at a cold temperature. Heat is exchanged along the
exchanger wall, proportional at any point to the difference in temperature
between the two fluids. We therefore study the evolution of two variables
$u_1(x)$ and $u_2(x)$ in an interval $x \in [0,L]$ with $L$ the length of
the exchanger.

In any layer $[x, x + \delta x]$, the heat exchange is equal to:
$$\delta \dot{Q} = h \cdot (u_2(x) - u_1(x)) \cdot \delta x$$
with $h$ a coefficient depending on the wall heat exchange properties.

Moreover, the variation in internal energy of the hot flow is equal to
$\delta \dot{Q}$ and is also expressed as:

$$ c_2 \cdot \dot{m}_2 \cdot (u_2(x+\delta x) - u_2(x)) $$
$c_2$ is the calorific capacity of the hot flow and  $\dot{m}_2$ its
mass flow rate. The you can check that the given expression is a power.
The same expressions apply to the cold flow.
Let us first assume the following:

$$c_2 \cdot \dot{m}_2 = c_1 \cdot \dot{m}_1$$

{{< highlight julia>}}
import DifferentialEquations
const DiffEq = DifferentialEquations
using Plots

function parallel_exchanger(du,u,p,x)
    h = p[1] # heat exchange coefficient
    Q = h * (u[1]-u[2])
    du[1] = -Q
    du[2] = Q
end

function parallel_solution(L, p)
    problem = DiffEq.ODEProblem(
      parallel_exchanger, # function describing the dynamics of the system
      u₀,                 # initial conditions u0
      (0., L),            # region overwhich the solution is built, x ∈ [0,L]
      p,                  # parameters, here the aggregated transfer constant h
    )
    return DiffEq.solve(problem, DiffEq.Tsit5())
end

plot(parallel_solution([0.0,100.0], 50.0, (0.05)))
{{< /highlight >}}

$$ u_1(x) = T\_{eq} \cdot (1 - e^{-h\cdot x}) $$
$$ u_2(x) = (100 - T\_{eq}) \cdot e^{-h\cdot x} + T\_{eq} $$

With $T\_{eq}$ the limit temperature, trivially 50°C with equal flows.

(Full disclaimer: I'm a bit rusty and had to double-check for errors)

<img src="/img/posts/heatex/parallel.svg">

This model is pretty simple, its performance is however low from
a practical perspective. First on the purpose itself, we can compute for two
fluids the equilibrium temperature. This temperature can be adjusted
by the ratio of two mass flow rates but will remain a weighted average.
Suppose the goal of the exchange is to heat the cold fluid, the necessary
mass flow $\dot{m}_2$ tends to $\infty$ as the targeted temperature tends to
$u_2(L)$, and this is independent of the performance of the heat exchanger
itself, represented by the coefficient $h$. Here is the extended model using
the flow rate ratio to adjust the temperature profiles:

{{< highlight julia>}}
import DifferentialEquations
const DiffEq = DifferentialEquations

function ratio_exchanger(du,u,p,x)
    h = p[1] # heat exchange coefficient
    r = p[2] # ratio of mass flow rate 2 / mass flow rate 1
    Q = h * (u[1]-u[2])
    du[1] = -Q
    du[2] = Q / r
end

function ratio_solution(u₀, L, p)
    problem = DiffEq.ODEProblem(
      ratio_exchanger, # function describing the dynamics of the system
      u₀,              # initial conditions u0
      (0., L),         # region overwhich the solution is built, x ∈ [0,L]
      p,               # parameters, here the aggregated transfer constant h
    )
    return DiffEq.solve(problem, DiffEq.Tsit5())
end

for (idx,r) in enumerate((1.0, 5.0, 10.0, 500.0))
    plot(ratio_solution([0.0,100.0], 50.0, (0.05, r)))
    xlabel!("x (m)")
    ylabel!("T °C")
    title!("Parallel flow with ratio $r")
    savefig("parallel_ratio_$(idx).pdf")
end
{{< /highlight >}}

<img src="/img/posts/heatex/parallel_ratio_1.svg">
<img src="/img/posts/heatex/parallel_ratio_2.svg">
<img src="/img/posts/heatex/parallel_ratio_3.svg">
<img src="/img/posts/heatex/parallel_ratio_4.svg">

This model has an analytical closed-form solution given by:
$$ T\_{eq} = \frac{100\cdot \dot{m}_2}{\dot{m}_1 + \dot{m}_2} = 100\cdot\frac{r}{1+r} $$
$$ u_1(x) = T\_{eq} \cdot (1 - e^{-h\cdot x}) $$
$$ u_2(x) = (100 - T\_{eq}) \cdot e^{-h\cdot x \cdot r} + T\_{eq} $$

## Opposite flow model

This model is trickier because we don't consider the dynamics of the system
along one dimension anymore. The two fluids flowing in opposite directions
are two interdependent systems. We won't go through the analytical solution
but use a similar discretization as in article [1].

This model takes $n$ discrete cells, each considered at a given temperature.
Two cells of the cold and hot flows are considered to have exchanged heat
after crossing.

<img src="/img/posts/heatex/counterflow.png">
[3]

Applying the energy conservation principle, the gain of internal energy
between cell $k$ and $k+1$ for the cold flow is equal to the loss of
internal energy of the hot flow from cell $k+1$ to cell $k$. These differences
come from heat exchanged, expressed as:

$$\dot{Q}_k = h \cdot \Delta x \cdot (u\_{2,k+1} - u\_{1,k}) $$
$$\dot{Q}_k = \dot{m}_1 \cdot c_1 \cdot (u\_{1,k+1} - u\_{1,k}) $$
$$\dot{Q}_k = \dot{m}_2 \cdot c_2 \cdot (u\_{2,k+1} - u\_{2,k}) $$

Watch out the sense of the last equation since the heat exchange is
a loss for the hot flow. Again we use the simplifying assumption of
equality of the quantities:
$$ \dot{m}_i \cdot c_i $$

Our model only depends on the number of discretization steps $n$
and transfer coefficient $h$.
{{< highlight julia>}}
function discrete_crossing(n, h; itermax = 50000)
    u1 = Matrix{Float64}(undef, itermax, n)
    u2 = Matrix{Float64}(undef, itermax, n)
    u1[:,1] .= 0.0
    u1[1,:] .= 0.0
    u2[:,n] .= 100.0
    u2[1,:] .= 100.0
    for iter in 2:itermax
        for k in 1:n-1
            δq = h * (u2[iter-1, k+1] - u1[iter-1, k]) * (50.0/n)
            u2[iter, k]   = u2[iter-1, k+1] - δq
            u1[iter, k+1] = u1[iter-1, k]   + δq
        end
    end
    (u1,u2)
end
{{< /highlight >}}

{{< highlight julia>}}
const (a1, a2) = discrete_crossing(500, 0.1)
const x0 = range(0.0, length = 500, stop = L)

p = plot(x0, a1[end,:], label = "u1 final", legend = :topleft)
plot!(p, x0, a2[end,:], label = "u2 final")
for iter in (100, 500, 100)
    global p
    plot!(p, x0, a1[iter,:], label = "u1 $(iter)")
    plot!(p, x0, a2[iter,:], label = "u2 $(iter)")
end
xlabel!("x (m)")
{{< /highlight >}}

We can observe the convergence of the solution at different iterations:
<img src="/img/posts/heatex/cross.svg">

After convergence, we observe a parallel temperature profiles along the
exchanger, the difference between the two flows at any point being reduced
to $\epsilon$ mentioned in article [1]. The two differences between our model
and theirs are:

* The discretization grid is slightly different since we consider the exchange
to happen between cell $k$ and cell $k+1$ at the node between them, while they
consider an exchange between $k-1$ and $k+1$ at cell $k$.
* They consider two flow unit which just crossed reach the same temperature,
while we consider a heat exchange limited by the temperature difference
(the two flows do not reach identical temperatures but tend towards it).

Finally we can change the ratio:
$$\frac{\dot{m}_1\cdot c_1}{\dot{m}_2\cdot c_2}$$ for the counterflow model
as we did in the parallel case.

{{< highlight julia>}}
function discrete_crossing(n, h, ratio; itermax = 50000)
    u1 = Matrix{Float64}(undef, itermax, n)
    u2 = Matrix{Float64}(undef, itermax, n)
    u1[:,1] .= 0.0
    u1[1,:] .= 0.0
    u2[:,n] .= 100.0
    u2[1,:] .= 100.0
    for iter in 2:itermax
        for k in 1:n-1
            δq = h * (u2[iter-1, k+1] - u1[iter-1, k]) * 50.0 / n
            u2[iter, k]   = u2[iter-1, k+1] - δq * ratio
            u1[iter, k+1] = u1[iter-1, k]   + δq
        end
    end
    (u1,u2)
end
{{< /highlight >}}

*Julia tip*: note that we do not define a new function for this but
create a **method** for the function `discrete_crossing` defined above
with a new signature `(n, h, ratio)`.

We can plot the result:
{{< highlight julia>}}
const x0 = range(0.0, length = 500, stop = L)
p = plot(x0, a1[end,:], label = "u1 ratio 1.0", legend = :bottomright)
plot!(p, x0, a2[end,:], label = "u2 ratio 1.0")
for ratio in (0.1,0.5)
    global p
    (r1, r2) = discrete_crossing(500, 0.1, ratio)
    plot!(p, x0, r1[end,:], label = "u1 ratio $(ratio)")
    plot!(p, x0, r2[end,:], label = "u2 ratio $(ratio)")
end
xlabel!("x (m)")
{{< /highlight >}}

<img src="/img/posts/heatex/ratio_variation.svg">

## Conclusion

To keep this post short, we will not show the influence of all parameters.
Some key effects to consider:

* Increasing $h$ increases the gap between the flow temperatures
* Increasing the number of steps does not change the result for a step size
small enough
* Increasing the exchanger length reduces the gap
* A ratio of 1 minimizes the temperature difference at every point
(and thus minimizes the entropy). This very low entropy creation is a positive
sign for engineers from a thermodynamics point of view: we are not "degrading"
the "quality" of available energy to perform this heat exchange or in other
terms, we are not destroying [exergy](https://en.wikipedia.org/wiki/Exergy).

Feel free to reach out on [Twitter](https://twitter.com/matbesancon)
or via email if you have comments or questions, I'd be glad to take both.

--------

*Note on process engineering*
The term is gaining more traction in English, and should replace
chemical engineering in higher education to acknowledge the diversity of
application fields, greater than the chemical industry alone.
The German equivalent *Verfahrenstechnik* has been used for decades and
*Génie des Procédés* is now considered a norm in most French-speaking
universities and [consortia](https://en.wikipedia.org/wiki/Soci%C3%A9t%C3%A9_Fran%C3%A7aise_de_G%C3%A9nie_des_Proc%C3%A9d%C3%A9s).


--------

Edit: thanks BYP for the sharp-as-ever proofreading

--------

Sources:

[1] Levi M. A Near-perfect Heat Exchange. SIAM news. 2018 Dec;51(10):4.

[2] Borel L, Favrat D. Thermodynamique et énergétique. PPUR presses polytechniques; 2nd edition, 2011.

--------

Image sources:
[3] Geogebra
