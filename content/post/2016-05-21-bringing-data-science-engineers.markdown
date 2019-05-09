+++
date = 2016-05-21
draft = false
tags = ["data-science", "engineering"]
title = "Bringing data science to engineers"
summary = """
Thoughts as an engineer-by-training evolving towards data skills in a
manufacturing context.
"""
math = false
+++

The goal of this article is to present couple challenges waiting the industrial
data scientist or industrial data science teams, the deep reasons I believe are
the root of this inertia, based on my experience (in both data science and
engineering projects) and exchanges with engineers and data scientists. The
last part introduces some suggestions to make the collaboration richer for
both sides.

## Why isn't data science already everywhere in engineering?

It is surprising that this transition hasn't been so spontaneous. Indeed, one
could think that engineers, belonging to the "STEM family" (people studying or
working in fields related to Science, Technology, Engineering and Mathematics)
would easily embrace the concepts and methods of data science and moreover be
able to identify the potential gains, savings and improvements to carry out
complex projects in a more effective manner.

### Silo thinking in STEM

That's not the case, most engineers I've been discussing and working with never
considered these techniques as relevant to their current tasks. So why so
little enthusiasm? A recurrent problem I noticed is the silo thinking of
disciplines created by strong and early specializations, along with natural
distaste and reduction of unknown fields.

### We're not Google, deal with it

So when someone will first pitch machine learning to an engineer, I would often
observe reactions of "it's not relevant to my field/work/issues" because they
don't consider being in a "tech" industry. This is the same reaction type
observed in companies facing digital disruption (see the excellent article of
Nicolas Colin
[here](http://www.thefamily.co/hot-news/the-five-stages-of-denial)).

As a personal example, as I was talking to a production manager about the
impact advanced predictive analytics could have on machine reliability and
availability, she advanced the "non-tech" argument, to which I answered with
examples of traditional manufacturing companies already using these techniques,
including General Electric for turbine monitoring (what they refer to as the
Industrial Internet). His last point was "Well sure but... we're not GE", which
I understood as "I'm not able to learn from nor to work in that field totally
out of my comfort zone". Although, her discomfort with the methods involved is
easily understandable since it requires key concepts in mathematics, statistics
and algorithm thinking which would often be considered as theory unusable in
their "real life".

### My subject is so complex

The other reaction one would observe is linked to an interesting thinking
process: People always tend to reduce the breadth of subjects they don't know,
and to emphasize (not to say oversize) the width and complexity of their own
domain. I recently read a "conversation hack" to make a conversation pleasant
to someone, in three steps:

1. Ask them what they do for a living
2. Ask them some more details about how they manage things
3. Look impressed, add "Wow, that sounds very complex"

People don't feel at ease with the introduction of quantitative, rational
methods and analytics for decision-making in their daily work because this
implies that a rather "simple" model can generate better decisions than them.
It revives this old phobia of losing their job to a machine.

### But still... why particularly engineers?

We didn't address this question yet, and it still sounds counter-intuitive,
given our first statements. From my personal experience studying and working
with both junior and senior engineers, and relatively to business or social
science background, there is a stronger will to "master the model" and
understand most key aspects of the system they work on.

Bank managers, marketing leaders or finance analysts totally feel comfortable
with the use of data base systems and business intelligence tools, even
statistical analyses or predictive modeling tools they can perfectly leverage,
but not often understand on the technical parts. They would just need to be
able to read, use and trust the results. Engineers, on the other hand don't
feel legitimate when using tools they don't master they feel the need of
understanding and controlling what's going on under the hood.

There is a common vision of the engineers in several cultures, they are the
handy people, able to answer most of your questions, master all techniques from
nuclear power generation to bio-technologies. They are all supposed to be Tony
Stark (or Elon Musk in a more realistic way). So their secret fear is not about
being afraid of getting their job "automated" but more about a situation where
they cannot handle their system anymore because a part of the decisions taken
is not under their control anymore.

## What to do about it?

### What data science can bring to their organization

Proving the utility of data science is the easy part, the process is actually
almost identical to bringing data science to any other industry. The potential
users should be shown what pain points this new field would address in their
business, how similar businesses have already applied machine learning to
their issues, and how the processes should be adapted to these projects.

### How it actually works

Empowering the engineers through explanations of the key concepts might be
seemingly pointless and time-consuming, but helps them accepting the
techniques involved as a part of the "internal model" secretly hidden in each
engineer's mind and used to think about their system and make decisions upon
it.

Most engineers are usually used to (at least) basic algorithm structures. So
using it to make them understand the thinking pattern behind machine learning
may help them to understand the mechanisms and feel at ease with reapplying
it. Once you've covered the fundamentals, a modeling skill should be
developed. Indeed, being able to model a problem as a data science project
will give a pretty straightforward beginning (especially on variable
selections or feature engineering).

Basic linear regression (and in general other curve fitting methods) have
already been seen for experimental purposes in most engineering fields. If one
has only time to explain key concepts, I would give the following order:

1. Classification principles, example of classification trees.
2. Regression techniques (if not already known). Simple and multivariate linear regression, polynomial regression.
3. Unsupervised learning, example of k-means clustering.
4. Overfitting, cross-validation concept and techniques.
5. Ensemble learning, example of random forests.

With clear but complete explanations of regression, classification and
unsupervised learning, along with a previous knowledge of regression
techniques, most engineers will be able to identify opportunities to get
deeper insights into the phenomena they investigate or to build robust
predictions through machine learning, which is the basic goal to break the
barriers we discussed. The 4th and 5th topics are a bonus allowing them to
understand what techniques data scientists would use, they would not need them
for opportunity identification but to extend their "internal model", which can
only be beneficial.

### Key examples

These examples are taken from diverse projects, challenges and data sets
including some personal ones. Each case study is addressed to specific targets.

* Process, Energy and Chemical Engineers

I studied once the Combined Cycle Power Plant dataset which can be found on
the UCI dataset repository here. Using machine learning allowed the research
group not to work on the basis of restrictive hypotheses on the thermodynamic
behavior of the gas or steam, nor on the heat exchange and fluid mechanics
phenomena involved (e.g. pressure drop in the pipes due to phase change). The
predictions based on data are a totally new way to combine formal model-based
approaches (including process optimization) and operational realities (the
good old "gut feeling" experienced staff will tell you about).

* Biomedical Engineers

This also includes all high-level medical professions. Well-known applications
were found in several fields, including pattern recognition from medical
images and data, disease risk estimations from patient background
information.

Predictive modeling systems will be a decisive disruption in physicist work,
they replace the human decision-making process, based on few variables and on
a biased and relative experience with the risk-based optimal decision backed
by millions of data points.

* Industrial, Manufacturing and Quality Engineers

Those case studies are inspired by my personal experience and the solutions
offered by several software development companies.

The first one is the application of classification trees to replace rules
defining the quality of a product (first, second class or discarded for
instance). Using proper data mining tools allows the production manager to
define the relative "cost" of false positives (good products declared as not
salable, which induces all the manufacturing costs without the revenue) and
false negatives (non-conform products sent to be sold, which induces a risk of
complaint, on operation product default, image issues or recall campaigns).

The second example is combining time-series analysis and multi-variable
regression techniques to give risk estimations on the process stability and
trends. I observed several software solution providers to whom the transition
from statistics to predictive modeling was a simple and obvious evolution.

Bringing machine learning to engineers is a challenge and must be considered
as a promising step for both data science and engineering. Formal modeling
approaches and experimental considerations will eventually be able to be
conciliated. Data science will gain a significant support and become an
accelerator for the development of new techniques.

You're an engineer, a data scientist? Have you ever experienced collaborating
with engineers on data science applications? Did you encounter some
difficulties specific to working with engineers? Please get in touch for
further discussion on these topics.

Now that we have discussed what data science could bring to engineers, a
second article may come to explain how to build a predictive model from
scratch in an industrial context.

Special thanks to Robert, Benoit and Florian for their feedback on the article.
