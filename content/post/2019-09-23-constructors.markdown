+++
date = 2019-09-24
draft = false
tags = ["julia", "rust", "java"]
title = "Lessons learned on object constructors"
summary = """
"""
math = true
diagram = false

[header]
image = ""
+++

--------

Constructors are a basic building block of object-oriented programming (OOP).
They expose ways to build specific types of objects consistently,
using arbitrary rules to validate properties.
Still, constructors are odd beasts in the OOP world.
In Java, this is usually the first case of function overloading that learning
programmers meet, often without knowing the term. An overloaded constructor is
shown in the following example:

{{< highlight java>}}
class Car {
    private Motor motor;

    public Car(Motor m) {
        this.motor = m;
    }
    public Car() {
        this.motor = new Motor();
    }
}
{{< /highlight >}}

Scala and Kotlin, which are both languages on the Java Virtual Machine designed
after and learning from Java, made the design choice of imposing a
**primary constructor**, which all other constructors have to call.
Constructors are weird beasts because they act partly as a function, partly as a
method. Moreover, they expose a special use of `this` as a method call instead
of being a pointer to the current object:

{{< highlight java>}}
class Car {
    private Motor motor;

    public Car(Motor m) {
        // 'this' as an object reference
        this.motor = m;
    }
    public Car(int power) {
        Motor m = new Motor(power);
        // this as a method
        this(m);
    }
}
{{< /highlight >}}

This has been in my experience confusing and harder to teach on my side because
it forces the learner to get a grasp of many specific tricks at the same time.
Another hard-to-grasp point is `this(motor)`, which has never been defined has
such. The definition it corresponds to is `Car(Motor m)`, the required mental
load here is just unnecessary.
This is why I appreciate Kotlin and Scala having made constructors more
restrictive, removing the need for hand-wavy explanations for bad design.
This great [blog post](https://matklad.github.io/2019/07/16/perils-of-constructors.html)
gives an overview of constructors in different mainstream languages and compare
them with the trait-based system of Rust.

# Constructors outside class-based OOP

I will focus here on [composite types](https://docs.julialang.org/en/v1/manual/types/#Composite-Types-1)
or `struct`. There is a whole section of the [Julia docs](https://docs.julialang.org/en/v1/manual/constructors/)
on constructors, but I would summarize things as:

1. There is a primary constructor which must provide values for all fields.
2. All other constructors are just functions, no magic is involved, and constructors are just multiple methods in the context of multiple dispatch.

This way of building objects as simple structures holding data in different
fields is not new, Kotlin and Scala have a similar pattern as we mentioned above.
Languages like Rust and Go take a different path by having structures being
plain structures, initialized by providing all fields directly:
{{< highlight rust>}}
// rust example

struct Motor {
    pub power: u8,
}

struct Car {
    pub motor : Motor
}
// let m = Motor{power : 33};
{{< /highlight >}}

{{< highlight go>}}
// go example

type Motor struct {
	Power uint
}
// m := Motor{33}
{{< /highlight >}}

Both languages have conventions for calling a standard constructing function,
namely `fn new(args) -> T` and `func NewT(args)` for Rust and Go respectively,
but those are not special and remain a simple convention without additional
language complexity.

# Two lessons learned

Two interesting Pull Requests are about to be merged in
[Distributions.jl](https://github.com/JuliaStats/Distributions.jl),
which is the main package for working with probability distributions in Julia.
Both revolve around a revision of the work of constructors.
I will use them to make a point which I believe generalizes well to other systems.
No probability theory should be needed here, it is merely a motivating example.

## Lesson 1: product distributions and constructor promises

Given multiple random variables: $ X_{i}, i = 1..n $ we define a
**product distribution** as the vector random variable built by stacking the
different $ X_i $:

$$ X = \[ X_i | i \in 1..n \] $$

They arrived in Distributions.jl in [this PR](https://github.com/JuliaStats/Distributions.jl/pull/722)
if you are curious.
One thing to be careful about is that the term "product distribution" does not
correspond with the eponymous Wikipedia entry. What we refer to here is the
[product type](https://en.wikipedia.org/wiki/Product_type) in the sense of tuple
construction and not the arithmetic product. One important property is that the
entries of the product type are independent distributions, which helps a great
deal deducing properties of the product distribution.

An example product type could be the product of two univariate Gaussian
distributions:

$$ X_1 \sim \mathcal{N}(0, 1)$$
$$ X_2 \sim \mathcal{N}(0, 2)$$
$$ X = [X_1, X_2]$$

The implementation of the `Product` type stores the vector of univariate
distributions, sampling and computing the PDF/CDF is done on a per-entry basis.
The corresponding code would look like this:
{{< highlight julia>}}
using Distributions: Normal, Product, pdf

Xs = [Normal(0, 1), Normal(0, 2)]
p = Product(Xs)

# sample from p
rand(p)

# compute PDF at (x1 = 0, x2 = 1)
pdf(p, [0.0, 1.0])
{{< /highlight >}}

One problem we have here is that we know some specialized, faster techniques
can be used in specific cases. Our product here for example, is nothing more
than a multivariate Gaussian distribution with independent components:
$$ X \sim \mathcal{N}([0, 0], diag([1, 2]))$$
with $diag(\cdot)$ constructing a diagonal matrix from a vector.

Sampling and computing quantities of interest for such multivariate would be
much faster by using a multivariate directly.
Our new design can leverage multiple dispatch, and would look as follows:

{{< highlight julia>}}
function Product(distributions::Vector{<:Gaussian})
	# construct multivariate gaussian
end

function Product(distributions::Vector{<:Uniform})
	# construct multivariate uniform
end

function Product(distributions::Vector{<:UnivariateDistribution})
	# construct generic Product
end
{{< /highlight >}}

It is all fine and type-stable; if you don't know what it means, just think
sound from a type perspective. One issue here though is that we break the
promise of a constructor.
A constructor of `Product` is supposed to return a `Product` and exactly this.
If you work in a language that uses algebraic data types for possible failures
and absence as `Maybe/Either/Result/Option`, the constructor should return the
type and not one of these.

{{< highlight julia>}}
struct T
	# type fields
end

"""
T constructor
"""
T(args) = # ...

value = T(args)

# the following should always be true
typeof(value) <: T
{{< /highlight >}}

In our cases, a more efficient implementation cannot be returned from a
constructor. This means the construction of our type must be left to another
method which could return it or something else.
In the case of product distributions, it was done in [this PR](https://github.com/JuliaStats/Distributions.jl/pull/975),
adding the function `product_distribution` in Distributions.jl, which can have
various methods returning a `Product` or something else.
With this design, it is left possible for a distribution to define a special
product type, while the default `Product` will work reasonably well.

The lesson learned here is to be wary of exposing constructors when many paths
are possible, and a dispatch system might be preferable. Constructors
should always return the same type and are not ideal for a specialization system.

## Lesson 2: main constructors should remain lean

Many constructors for probability distributions include a verification of the
parameters. When constructing a uniform distribution $\mathcal{U}(a, b)$, one
would want to verify that $a \leq b$. For a Gaussian distribution, one would
verify that the standard deviation is positive. These checks are fine, but have
a runtime cost and may interrupt the construction of the object.
There are many cases in which the parameters are guaranteed to be valid, two of
them being:

1. Constructing an object by copy.
2. Constructing an object with default parameters.

{{< highlight julia>}}
struct T
	# fields
end

function T()
	# default parameters are valid
end

function T(t::T)
	# t is already constructed, and is therefore valid
end
{{< /highlight >}}

Throwing errors in a constructor is ill-advised, because again,
the promise of a constructor is to construct the object.
In languages where throwing is not advised, it means the constructor would
return a `Maybe{T} / Either{_, T}`, which again breaks the promise.
The problem is that if checking is not the default, users are less likely to
call the checking function. The solution found here is to use a keyword in
all constructors:

{{< highlight julia>}}
struct D{T <: Real} <: Distribution
	param::T
	D{T}(param) where {T} = new{T}(param)
end

function D(p::T; check_arg = true) where {T}
	if check_arg
		verify(param)
	end
	return D{T}(param)
end
{{< /highlight >}}

The default is still to check the validity of parameters, but objects of type
`D` can now be constructed with opt-out checking. Another way to do it is
with multiple dispatch:

{{< highlight julia>}}
struct NoArgCheck end

struct D{T <: Real} <: Distribution
	param::T
	D{T}(param) where {T} = new{T}(param)
end

function D(p::T, ::NoArgCheck) where {T}
	return D{T}(param)
end
{{< /highlight >}}

In either cases, users can now take the responsibility of checking parameters
themselves. One general rule to highlight here for scientific programming work
is that the constructor is a fixed cost imposed on all users, treat additional
checks and operations carefully.
