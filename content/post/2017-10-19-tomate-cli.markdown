+++
date = 2017-10-19
draft = false
tags = ["golang", "phd", "productivity"]
title = "Switching my work flow to Pomodoro for grad studies - part I: motivation  "
summary = """
Switching from data scientist to graduate student is not
only a variation in tasks, but also in success criteria and work flow
"""
math = false

[header]
image = "posts/tomate/tomates.jpg"
+++

The start of my journey as a PhD student last September was a big step, but
also an opportunity to review and improve my working habits. My day time
had to be used properly, both for results' sake and to be able to keep
a balanced life.  

I had been introduced to the [Pomodoro technique](https://en.wikipedia.org/wiki/Pomodoro_Technique)
at Equisense (thanks [Camille](https://twitter.com/CamilleSaute)!) but
remained skeptical as for its potential value within my work
flow at the time.  

To make it short, the technique consists in the following steps:

- Decide what task should be worked on.  
- Allocate a given time to work (around 25 minutes)  
- Set a timer and get to work  
- When the time is up, make a short pause (~5 minutes), then repeat  
- After 4 work sprints, take a longer break (~15-30 minutes)  


## What was wrong with that?  

The development, test and operation phases were generally self-determining
and lead to sprints from 20 to 120 minutes (that length isn't surprising
for some tasks and when highly focused). These were also often
interrupted by team interactions (required concertation with members
of the tech and product team, backend-specific collaborative
problem-solving, ...). The main point was that
**there are enough spontaneous interruptions of the work flow, no need to introduce an additional artificial one**.
As I look back, I still think this was a valid reason
not to use this technique.

## What has changed?

Time management as a grad student has to be un- and re-learned:
rules are different, criteria for success change and so on.

![](/img/posts/tomate/phd_time.gif)  

> Time management seen by PhD comics [2]

### Problem structure: programming at a startup vs. applied math

In my case, the major part of the workload switched from an
implementation-heavy to a modeling-heavy context. As such,
the work phases tend to be longer and with an heavier
cognitive load. I am not saying that programming is
easier, but I'm pretty sure mathematics almost always
requires to keep more information in mind while working
on a problem. Another opinion is that the part of
instinct to find a path towards a solution is higher
in mathematics.  

While programming, there are some key techniques that
reduce the number of possible sources to a problem:  

- Getting information on the state of the program at a given point (logging, debugging, printing to `stdout`)  
- Testing the behavior of an isolated piece of the program with given input  

These techniques also work for scientific computing of course, but are
harder to apply to both modeling and symbolic calculus, the different
pieces of the problem have to be combined to find special structures
which allow for a resolution. More solutions also tend to come
while NOT looking at mathematical problem than for programming
problems, where solutions come either in front of the code or when
voluntarily thinking of the problem.

### Team-dependent work vs. figure it out for yourself

Most startups obviously value team work, it is one of the
group skills that differentiate companies building great
things from the ones stuck in an eternal early stage.
This was even more true at Equisense where collaboration
and product development were both very synchronous by
modern standards. It had cons but ease two things:

* **Speed of product development**. Lots of team under-estimate post-development coordination, the last meters of the sprint to have a feature ready
* **Programming by constraints**. Because of fast interactions between the people responsible for the different components, constraints from each one is quickly communicated and the modeling process is defined accounting for them right away.

Now in research, especially in applied mathematics, the work is
mostly independent, synchronization happens when working
on a joined project for instance. This means that all the
interruptions that were happening throughout the day are
now gone!
**Nothing would stop you from working day and night without a break**.

## Conclusion

Two key results of this change of work style are:

* Work sprints are not naturally bound anymore, obviously with decreasing efficiency
* Few to no interactions interrupt the sprints either

My conclusion was the necessity of a time management technique
and associated tools, with a low cognitive overhead and bringing
as little distraction as possible.  

From these criteria, I rejected a mobile app,
smartphones are great to bring different sources
of information and communication channels together,
not for remaining focused for hours,
**mobile apps are designed to catch and retain attention**,
that's simply part of their business model. I also rejected
web-based solutions for the constraint of firing up
a browser, amongst the heaviest pieces of software on our
modern desktops, just to start a working session.  

So desktop GUI or CLI it is. Even though there is the
[gnomepomodoro project](http://gnomepomodoro.org/), it did not seem compatible with all
Linux desktops. At that point, I realized the amount of
work to build a Pomodoro was low, the requirements and
constraints well known, I throw ideas
together and start coding.

I'll explain the initial development and iterations of
the app in Go in a second article, if you liked this one,
let me know!

-------

Sources and images:  
[1](https://pixabay.com/en/tomatoes-vegetables-red-delicious-73913)  
[2](http://substance-en.etsmtl.ca/wp-content/uploads/2014/09/2.gif)
