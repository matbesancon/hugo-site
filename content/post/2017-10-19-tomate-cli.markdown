+++
date = 2017-10-19
draft = true
tags = ["golang", "phd", "productivity"]
title = "Building a Pomodoro command line tool in Go - part I: motivation  "
summary = """
Switching from data scientist to graduate student is not
only a variation in tasks, but also in success criteria and workflow
"""
math = false

[header]
image = "posts/tomate/tomates.jpg"
+++

The start of my journey as a PhD student last September was a big step, but
also an opportunity to review and improve my working habits. My whole working
time had to be used properly, both for results' sake and to be able to keep
a balanced life.  

I had been introduced to the [Pomodoro technique](https://en.wikipedia.org/wiki/Pomodoro_Technique)
at Equisense but remained skeptical as its usefulness in my work flow at the time.

To make it short, the technique consists in the following steps:
  
- Decide what task should be worked on.  
- Allocate a given time to work (around 25 minutes)  
- Set a timer and get to work  
- When the time is up, make a short pause (~5 minutes), then repeat  
- After 4 work sprints, take a longer break (~15-30 minutes)  

  
## What was wrong with that?  

The development, test and operation phases were generally self-determining
and lead to sprints from 20 to 120 minutes (not that long for some tasks and
when highly focused). These were also often interrupted by team interactions
(required concertation with members of the tech and product team,
backend-specific collaborative problem-solving). The main point was that
**there are enough spontaneous interruptions of the work flow, no need to
introduce an additional artificial one**. As I look back, I still think this
was a valid reason not to apply this technique.

## What has changed?

Time management as a grad student has to be un- and re-learned: 
rules are different, work quality criteria change and so on.

![](/img/posts/tomate/phd_time.gif)  
  
> Time management seen by PhD comics [2]
  
### Problem structure: programming at a startup vs. applied math

In my case, the major part of the workload switched from an 
implementation-heavy to a modeling-heavy context. As such,
the work phases tend to be longer and with a cognitive 
load much heavier. I am not saying that programming is 
easier, but I'm pretty sure mathematics almost always
require to keep more information in mind while working
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

Two key results of this change of workstyle are:

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
browser-based solutions for the constraint of opening a
browser just to start a working session.


-------

Sources and images:  
[1](https://pixabay.com/en/tomatoes-vegetables-red-delicious-73913)  
[2](http://substance-en.etsmtl.ca/wp-content/uploads/2014/09/2.gif)
