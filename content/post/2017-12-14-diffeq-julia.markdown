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


-----
<font size="0.7">
 [1] 
</font>
