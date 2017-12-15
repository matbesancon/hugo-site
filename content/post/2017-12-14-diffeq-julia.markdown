+++
date = 2017-12-14
draft = true
tags = ["julia", "modeling", "numerical-techniques", "applied-math"]
title = "Getting started with DifferentialEquations.jl"
summary = """
Playing around with the differential equation solver turned simulation engine
"""
math = true

[header]
image = "posts/"
+++

[DifferentialEquations.jl](https://github.com/JuliaDiffEq/DifferentialEquations.jl)
came to be a key component of Julia's scientific ecosystem. After checking the
JuliaCon talk of its creator, I couldn't wait to start building stuff with it,
so I created and developed a simple example detailed in this blog post.
Starting from a basic ordinary differential equation (ODE), we add noise,
making it stochastic, and finally turn it into a discrete version.  

> Before running the code below, two imports will be used:

{{< highlight julia >}}
import DifferentialEquations;
DiffEq = DifferentialEquations;
import Plots
{{< /highlight >}}

I tend to prefer explicit imports in my Julia code, it helps see which function
comes from which part. As `DifferentialEquations` is longuish to write, we use
an alias in the rest of the code.

## The model

We use a simple 3-element state in a differential equation. Depending on your
background, pick the interpretation you prefer:

1. An SIR model, standing for susceptible, infected, and recovered, directly
inspired by the talk and by the [Gillespie.jl](https://github.com/sdwfrost/Gillespie.jl)
package. We have a total population with healthy people, infected people
(after they catch the disease) and recovered (after they heal from the disease).

2. A chemical system with three components, A, B and R.
$$A + B → 2B$$  $$B → R$$  

After searching my memory for chemical engineering courses and the
[universal source of knowledge](https://en.wikipedia.org/wiki/Autocatalysis),
I could confirm the first reaction is an autocatalysis, while the second is
a simple reaction. An autocatalysis means that B molecules turn A molecules
into B, without being consumed.  

The first example is easier to represent as a discrete problem: finite
populations make more sense when talking about people. However, it can be seen
as getting closer to a continuous differential equation as the number of people
get higher. The second model makes more sense in a continuous version as we are
dealing with concentrations of chemical components.

## A first continuous model

Following the tutorials from the
[official package website](http://docs.juliadiffeq.org/latest/tutorials/ode_example.html#Example-2:-Solving-Systems-of-Equations-1),
we can build our system from:  

- A system of differential equations: how does the system behave (dynamically)
- Initial conditions: where does the system start
- A time span: how long do we want to observe the system

The system state can be written as:
$$u(t) =
\begin{bmatrix}
u₁(t) \    
u₂(t) \    
u₃(t)   
\end{bmatrix}^T
$$

With the behavior described as:
$$
\dot{u}(t) = f(u,t)
$$
And the initial conditions $u(0) = u₀$.

In Julia, this becomes:
{{< highlight julia >}}
α = 0.8
β = 3.0
diffeq = function(t, u, du)
    du[1] = - α * u[1] * u[2]
    du[2] = α * u[1] * u[2] - β * u[2]
    du[3] = β * u[2]
end
u₀ = [49.0;1.0;0.0]
tspan = (0.0, 1.0)
{{< /highlight >}}

`diffeq` models the dynamic behavior, `u₀` the starting conditions
and `tspan` the time range over which we observe the system
evolution.  

We know that our equation is smooth, so we'll let
`DifferentialEquations.jl` figure out the solver. The general API
of the package is built around two steps:  
1. Building a problem/model from behavior and initial conditions
2. Solving the problem using a solver of our choice and providing additional
information on how to solve it, yielding a solution.

{{< highlight julia >}}
prob = DiffEq.ODEProblem(diffeq, u₀, tspan)
sol = DiffEq.solve(prob);
{{< /highlight >}}

One very nice property of solutions produced by the package is that they
contain a direct way to produce plots.

{{< highlight julia >}}
Plots.plot(sol)
{{< /highlight >}}

![Solution to the ODE](/img/posts/DiffEq/smooth.png)

If we use the disease propagation example, $u₁(t)$ is the number of
healthy people who haven't been infected. It starts high, which makes the rate
of infection by the diseased population moderate. As the number of sick people
increases, the rate of infection increases: there are more and more possible
contacts between healthy and sick people.   

As the number of sick people increases, the recovery rate also increases,
absorbing more sick people. So the "physics" behind the problem makes sense
with what we observe on the curve.


## Adding randomness: first attempt with simple SDE

## Adding randomness: second attempt with non-diagonal noise

-----
<font size="0.7">
 [1]
</font>
