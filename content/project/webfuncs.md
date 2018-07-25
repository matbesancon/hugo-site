+++
# Date this page was created.
date = "2018-01-10"

# Project title.
title = "WebFuncs"

# Project summary to display on homepage.
summary = "Serve Julia functions with HTTP"

# Optional image to display on homepage (relative to `static/img/` folder).

# Tags: can be used for filtering projects.
tags = ["open-source", "julia-package"]

# Optional external URL for project (replaces project detail page).
# external_link = "https://github.com/matbesancon/WebFuncs.jl"

# Does the project detail page use math formatting?
math = false

# Optional featured image (relative to `static/img/` folder).

+++

[WebFuncs.jl](https://github.com/matbesancon/WebFuncs.jl) is a Julia project testing the language out of its natural
scope. Having built quite a bit with Go and Python, I wanted to see if
the Julia ecosystem had tools for HTTP handling.

The inspiration of a simple-to-use function server came from the
[fx project](https://github.com/metrue/fx). Define your function, the
package throws it as a server for you.

The package has been accepted on Julia package repository and can be fetched
using `Pkg.add("WebFuncs")`.
