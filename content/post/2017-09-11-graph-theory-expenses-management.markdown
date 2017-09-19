+++
date = 2017-09-11
draft = true
tags = ["graph", "math", "julia"]
title = "Solving the group expenses headache with graphs"
summary = """
Graph theory and Julia to solve the boring side of traveling
"""
math = true

[header]
image = ""
+++

{{% toc %}}

Three weeks ago, we were enjoying deserved vacations before getting back
to work/school/Switzerland with friends. A trip always means some expenses
which must be fairly split to enjoy the trip and not keep bothering
one another.

> *Les bons comptes font les bons amis.*
> French wisdom


The [Tricount](https://tricount.com/) application became famous precisely by
solving this problem for you: just enter the expenses one by one, with who
owes whom and you'll get the simplest transactions to balance the amounts at
the end.

In this post, we'll model the expense balancing problem from a graph
perspective and see how to come up with a solution.

{{% alert note %}}
We will use the awesome GraphCoin as a currency in this post, noted GPC to
be sure no one feels hurt.
{{% /alert %}}

# The expenses model

Say that we have a vector $u$ of $n$ users involved in the expenses. An expense
$\delta$ is defined by an amount spent $\sigma$, the user who paid the
expense $p$ and a non-empty set of users picked in $u$ who are accountable for
this expense $a$.

> $\delta = (\sigma, p, a)$

The total of all expenses $\Sigma$ can be though of as: for any two users $u_i$ and $u_j$,
the total amount that $u_i$ spent for $u_j$. So the expenses are a vector of
triplets *(paid by, paid for, amount)*.

As an example, if I went out for
pizza with Joe and paid 8GPC for the two of us, the expense is modeled as:

> $\delta = (\sigma: 8GPC, p: Mathieu, a: [Mathieu, Joe])$.

Now considering I don't keep track of money I owe myself, the sum of all expenses
is the vector composed of one triplet:

> $\Sigma = [(Mathieu, Joe, \frac{8}{2} = 4)]$

What we are dealing with here is a weighted directed graph. Users are vertices
and amounts are edges. As any graph, the expenses can be expressed as a vector
of triplets or as a matrix, both representations contain the same information.
The list is useful when the graph is very sparse (not many edges compared to
the number of vertices). In our case we would expect most users to have paid for
some expenses or to owe other for those, so we will adopt the matrix
representation. Let's write a simple Julia function that takes a list of expenses
and returns the expense matrix.

```julia
ins = 1+1
```

# Reducing expenses

Now that we have a full representation of the expenses at the end of the trip,
the purpose of balancing is to find a vector of transactions which cancels out
the expenses. A naive approach would be to use the transposed expense matrix
as a transaction matrix. If $u_i$ paid $\Sigma \left [ ij \right]$ for $u_j$,
then $u_j$ paying back that exact amount to $u_i$ will solve the problem.
So we need in the worst case as many transactions after the trip as
$|u| \cdot (|u| - 1)$. For 5 users, that's already 20 transactions,
how can we improve it?

## Breaking strongly connected components

Suppose that I paid the pizza slice to Joe for 4GPC, but he bought me an ice
cream for 2GPC the day after. In the naive models, we would have two
transactions after the trip: he give me 4GPC and I would give him 2GPC. That
does not make any sense, he should simply pay the difference between what he
owes me and what I owe him. For any pair of users, there should only be
at most one transaction from the most in debt to the other, this result in the
worst case of $\frac{|u| \cdot (|u| - 1)}{2}$ transactions, so 10 transactions
for 5 people.

Now imagine I still paid 4GPC for Joe, who paid 2GPC for Marie, who paid 4GPC
for me. In graph terminology, this is called a
*[strongly connected component](https://en.wikipedia.org/wiki/Strongly_connected_component)*.
The point here is that transactions will flow from one user to the next one,
and back to the first.

If there is a cycle, we can find the minimal due sum within it. In our 3-people
case, it is 2GPC. That's the amount which is just moving from hand to hand and
back at the origin: it can be forgotten. This yields a new net debt:
I paid 2GPC for Joe, Marie paid 2GPC for me. We reduced the number of
transactions and the amount due thanks to this cycle reduction.

## Per-user summation and chain-breaking

Connected component elimination is great, but it means we have to find and
reduce all of them in the graph, which can be costly. Furthermore, there are
situations with useless transactions that are not contained in connected
components. Take this situation of who-owes-who after the trip:
![](/img/posts/expense/simple_chain.png)
*b* receives money from *a*, just to give it back with a bit more to *c*.
What would make more sense is the following:
![](/img/posts/expense/corrected_graph.png)
Both *a* and *b* were owing money to some other user, so none of them had a
reason to receive any transaction. This information is quantified by the
per-user summation of due cash: how much net GPCs does the group owe one user
(or how much he owes the group). For the previous graph, the summation is:
`s = {a: -20, b: -10, c: 30}`. We use the convention that money a user owes is
counted as negative and the money he is owed is positive. That way, we have a
way of limiting outgoing flows for any node *x* (*s[x]* means the summation for
the node *x*):

* If $s\[x\] \geq 0$, all edges flowing out of *x* are deleted.
* Otherwise, for any node *y* which *x* is connected to:
  - If $s\[y\] \geq 0$, *y* is creditor to the group, the arc *(x,y)* remains.
  - If $s\[y\] \leq 0$, *y* owes the group some money. We can then redirect the
sum *x* owes *y* to the nodes following *y* until we find users whom the
group owes.
