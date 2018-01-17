+++
# Date this page was created.
date = "2018-01-10"

# Project title.
title = "JuliaGraphs contributions"

# Project summary to display on homepage.
summary = "A graph modeling and analysis ecosystem for Julia"

# Optional image to display on homepage (relative to `static/img/` folder).
image_preview = "projects/juliagraphs.png"

# Tags: can be used for filtering projects.
tags = ["open-source", "graphs", "julia-package"]

# Optional external URL for project (replaces project detail page).
# external_link = "https://juliagraphs.github.io/"

# Does the project detail page use math formatting?
math = false

# Optional featured image (relative to `static/img/` folder).

+++

Starting from a weird Kaggle [side-project](https://www.kaggle.com/c/santa-gift-matching)
during the Chrismas holidays, I gradually got involved in the [JuliaGraphs](https://juliagraphs.github.io/)
ecosystem. After some discussion on the Julia Slack *#graphs* channel,
I went from reporting a simple feature I needed to helping with the
re-organization by splitting out two packages:

* [LightGraphsMatching.jl](https://github.com/JuliaGraphs/LightGraphsMatching.jl)
* [LightGraphsFlows.jl](https://github.com/JuliaGraphs/LightGraphsFlows.jl)

I also implemented the
[min-cost flow problem](https://github.com/JuliaGraphs/LightGraphsFlows.jl/blob/master/src/mincost.jl)
formulated as a linear optimization problem formulated using MathProgBase.jl,
using any user-provided solver.

Many thanks to the whole JuliaGraphs team for their trust, support and advice.
