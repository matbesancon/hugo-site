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

Following the tutorials from the [official package website](http://docs.juliadiffeq.org/latest/tutorials/ode_example.html#Example-2:-Solving-Systems-of-Equations-1), we can build our system from:
- A system of differential equations: how does the system behave (dynamically)
- Initial conditions: where does the system start
- A time span: how long do we want to observe the system

## Adding randomness: first attempt with simple SDE

## Adding randomness: second attempt with non-diagonal noise

-----
<font size="0.7">
 [1]
</font>
