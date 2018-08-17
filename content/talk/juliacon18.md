+++
date = "2018-08-09T00:00:00"
title = "Intro to package development in Julia"
abstract = ""
abstract_short = ""
event = "Julia Montréal Meetup"
event_url = "http://juliacon.org/2018/talks_workshops/69/"
location = "University College London, UK"

selected = false
math = false

url_pdf = ""
url_slides = "https://matbesancon.github.io/graph_interfaces_juliacon18/#/"
url_video = ""

# Optional featured image (relative to `static/img/` folder).
[header]
image = "headers/bubbles-wide.jpg"
caption = "My caption :smile:"

+++

We presented the *LightGraphs.jl* package with [James](https://twitter.com/fairbanksjp) for anyone in need of a
simple & extensible graph library in Julia, the core interface for abstract graphs and essential algorithms included.  

Anyone can come up with their own graph type, and we show it by building the simplest graph type
from an adjacency matrix, implementing the LightGraphs interface, and then re-using the whole
ecosystem on this type for free.  
