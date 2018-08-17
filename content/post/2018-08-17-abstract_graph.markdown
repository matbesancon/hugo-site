+++
date = 2018-08-17
draft = true
tags = ["julia", "graph", "package", "interface"]
title = "Building our own graph type in Julia"
summary = """
Who needs libraries when from scratch looks so good
"""
math = true

[header]
image = "posts/cutting_stock/sushi_cuts.jpg"
+++

--------

This is an adapted post on the talk we gave with James at JuliaCon 2018 in London.
You can see the [original slides](https://matbesancon.github.io/graph_interfaces_juliacon18),
the video still requires a bit of post-processing.  

Last week [JuliaCon](http://juliacon.org) in London was a great and intensive
experience. The two talks on [LightGraphs.jl](https://github.com/JuliaGraphs/LightGraphs.jl)
received a lot of positive feedback and more than that, we saw
how people are using the library for a variety of use cases which is a great
signal for the work on the JuliaGraphs ecosystem.  

I wanted to re-build the same graph for people who prefer a post version to
my clumsy live explanations on a laptop not handling dual-screen well
(those who prefer are invited to see the video).

## Why abstraction

The LightGraphs library is built to contain as few elements as possible to get
anyone going with graphs. This includes:
* The interface a graph type has to comply with to be used
* Essential algorithms implemented by any graph respecting that interface
* A simple, battery-included implementation based on adjacency lists

The thing is, if you design an abstraction which in fact has just one implementation,
you're doing abstraction wrong. This talks was also a reality-check for
LightGraphs, are we as composable, extensible as we promised?



--------
Image source:
