+++
date = 2023-12-17
draft = false
tags = ["optimization", "scip", "integer-optimization"]
title = "Branch-And-Bound Models and Strong Branching"
summary = """
An informal recap of our recent paper.
"""
math = true
diagram = false
[header]
+++

This is an informal post summarizing our recent paper [*Probabilistic Lookahead Strong Branching via a Stochastic Abstract Branching Model*](https://arxiv.org/abs/2312.07041) together with Gioni Mexi from the Zuse Institute Berlin and Somayeh Shamsi and Pierre Le Bodic from Monash University.  
**EDIT**: the paper got the best student paper award at [CPAIOR24](https://sites.google.com/view/cpaior2024), congratulations to Somayeh and Gioni!

I'll try to remain approachable but will assume that the reader is slightly familiar with Branch-and-Bound, and in general with Computational Mixed-Integer Optimization.

{{< toc >}}

# Abstract Models for Branch-and-Bound Trees

One characteristic of modern frameworks for mixed-integer optimization is their complexity, in the sense of the number of moving parts in the solvers.
Many algorithms run with different purposes and are influenced by each other's result.
The algorithms are exact, but their convergence to an optimal solution and proof of optimality can vary wildly from one instance to the next, and is very far from the worst-case analysis. This may seem obvious but is far from the case in many fields. In smooth convex optimization, it is more often the case that the theoretical rates are also those observed in practice.

Because of this gap between theoretical and observed performance, it can be hard to reason on what branch-and-cut-based solvers are doing, how different decisions in the sub-algorithms influence them.

Some papers proposed simplified models of branch-and-bound algorithms to enable researchers to establish and compare theoretical properties, and study the influence on these simplified models of certain algorithmic decisions. Sounds vague? We will see concrete examples.

- *[An abstract model for branching and its application to mixed integer programming](https://link.springer.com/article/10.1007/s10107-016-1101-8)*, P. Le Bodic, G. Nemhauser (2017): defines the problem of building a branch-and-bound tree from variables defined from fixed dual gains. The model is then used to define a scoring criterion from dual gains.

- *[An abstract model for branch and cut](https://link.springer.com/article/10.1007/s10107-023-01991-z)*, P. le Bodic & A. Kazachkov (2023), extends this paper to branch-and-cut, modelling the relaxation with a set of cuts as the unique child of the previous relaxation.

- *[Branch-and-Bound versus Lift-and-Project relaxations in combinatorial optimization](https://arxiv.org/abs/2311.00185)*, G. Cornuéjols, Y. Dubey (2023) compares the relaxation obtained from Branch-and-Bound against the one obtained from a lift-and-project hierarchy (lift-and-project cuts applied recursively).

In many cases, the goal of the article is to establish properties of the constructed simplified model, for instance to show some trends and compare them to the behaviour of real instances / solvers.
In few cases, these models are used to extract key take-aways that can be exploited for actually solving hard problems.
The abstract model for branching paper for instance derives from the abstract branch-and-bound trees some rules to score variables based on their left and right dual gains.
Our paper sets the same goal: can we build an abstract model from which to draw actionable insight for algorithm design?

# Strong Branching and Lookahead Stopping

At any node of a branch-and-bound tree, the algorithm *branches* on one variable that has a fractional value and should take an integer one (we will spare ourselves constraint branching and keep it simple for now).
This partitions the space into two disjoint polytopes for which we continue solving the linear relaxations, branching, etc.
Any choice of fractional variable at all nodes will make the algorithm terminate in finite time with the optimal solution, but this random choice typically produces an extremely large tree.

On the other side of the spectrum, one could produce the best tree by... searching for the best variable. This would be akin to a clairvoyant branching rule that solves the tree in order to solve the tree.
Instead of fully expanding the branch-and-bound tree in this idealized branching, we could only explore the children of the nodes and use the obtained *dual bound improvement* as a metric to evaluate branching candidates, and this is how we obtain **Strong Branching** (SB). Strong branching is a limited idealized oracle, which uses a depth-one lookup in the branch-and-bound tree. Despite being "only" depth one, it is still:
1. **expensive**, because it requires solving two linear problems per candidate. This is much more expensive than many other branching rules, which only require a constant or linear amount of computations (in terms of problem size) per candidate.
2. **powerful** in terms of predictive power. SB empirically produces very small trees, and has been shown to produce theoretically small trees in Cite Dey paper.

Because of these two characteristics, SB is typically used a lot at the beginning of the tree, where branching decisions matter a lot, and then controlled with working limits on the budget of simplex iterations used for SB, on the maximum number of branching candidates evaluated by SB, etc.

In particular, the algorithm muse determine the number of candidates to evaluate via strong branching.
Evaluating all candidates leads to full strong branching, which is typically too costly.
Strong branching can be viewed as containing an [optimal stopping problem](https://en.wikipedia.org/wiki/Optimal_stopping):
branching candidates are "discovered" when they are evaluated with strong branching, revealing their left and right dual gains,
we can then evaluate further candidates or stop and branch on the current best found so far.
In particular, this stopping problem allows us to choose any candidate we have sampled so far, and incurs a cost for every candidate we sample, with a final reward which we can approximate with the dual gains obained.

Instead, the branching algorithm in SCIP includes a strategy coined *lookahead*: we start evaluating candidates and record the best one found so far.
If the best candidate has not changed for $L$ candidates, meaning we sampled $L$ consecutive unsuccessful candidates, we stop the search and use that candidate.

It turns out, this rule is fairly robust, and trying to tweak the current value of $L$ or other parameters cannot lead to substantial improvements alone.
We will need to rethink the algorithm execution to improve upon this baseline we will refer to as *static lookahead*.

# Pandora's Multi-Variable Branching: An Abstract Branching Tree with Strong Branching

One contribution of the paper is building an abstract model of the branching tree in order to guide strong branching.
The abstract model has the following properties:
- each variable has a hidden dual gain, which is identical for the left and right child,
- these gains are unknown at the start and need to be discovered by *sampling* the variable, paying the cost of solving the two LPs,
- these gains are fixed for a given variable throughout the tree.

We coined this abstract model **Pandora's Multi-Variable Branching** or **PVB** in reference to Pandora's box problem [^1], one of the most well-known online decision problems.

# Probabilistic Lookahead

We solve PVB with a so-called probabilistic lookahead algorithm.
We compute the expected number of LPs to solve $N_{\text{LP}}$ if we decide to sample one more variable as:
$$
\mathbb{E}[{N_{\text{LP}}}] = 2 + p_{\text{fail}} \cdot T_{0} + (1 - p_{\text{fail}}) \cdot \mathbb{E}[T_{\text{success}}].
$$
The fixed 2 corresponds to the additional two LPs solved by strong branching for the variable,
$p_{\text{fail}}$ is the probability that the new sampled variable has a dual gain lower than the incumbent dual gain,
$p_{\text{success}}$ is its complement, $T_0$ is the size of the branching tree with the current branching incumbent, and
$\mathbb{E}[T_{\text{success}}]$ is the expected tree size, conditioned on the new sampled variable being better than the incumbent.

The key ingredient is being able to estimate the expected tree size of the simplified model, both for $T_0$ and $T_{\text{success}}$.

# Improving Strong Branching in SCIP

One crucial question was left: we have this new criterion for strong branching.
In simulations, it fared better than the static lookahead to close the gap for a given budget of LP solves, but what about the harsh reality of actually solving MIPs?

It turns out that, with a distribution family built from observed dual gains, using the new criterion can significantly improve the way we allocate the strong branching budget.
This results on affected instances of the MIPLIB in about 5% fewer nodes, 3% less time, and 9% fewer nodes, 8% less time on hard (taking more than 1000 seconds to solve) affected instances.
As a cherry on top, this effect carries over to MINLP instances from the [MINLPlib](https://www.minlplib.org), and to other sets of instances with the same gains, showing a nice consistency in the improvement.

One thing to highlight is really that it improves *both* the time and number of nodes, meaning that the method is not just using more/fewer SB calls (which would reduce the number of nodes but increase time or vice versa),
but really allocating it only where it is needed.

The new probabilistic lookahead criterion will be integrated into SCIP for the 10.0 release.

---------

[^1]: See for example: *Recent Developments in Pandora's Box Problem: Variants and Applications*, Hedyeh Beyhaghi, Linda Cai, Proceedings of the 55th Annual ACM Symposium on Theory of Computing, [arxiv preprint](https://arxiv.org/abs/2308.12242).
