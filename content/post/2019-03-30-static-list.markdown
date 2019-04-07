+++
date = 2019-03-30
draft = false
tags = ["julia"]
title = "Static lists in Julia"
summary = """
Pushing the type system for more compile-time information
"""
math = false

[header]
image = "posts/staticlist/chain.jpg"
+++

--------

This post explores the possibility to build static lists in Julia, meaning
lists for which the size is known at compile-time. This is inspired by
a [post](https://aerodatablog.wordpress.com/2019/03/03/a-typedlist-in-scala/#joe_barnes_talk)
on a Scala equivalent but will take different roads to see more than a plain port.
Of course, this implementation is not that handy nor efficient but
is mostly meant to push the limits of the type system,
especially a trick of using recursive types as values
(replacing a dependent type system).
Some other references:

- The list operations are inspired by the implementation in [*DataStructures.jl*](https://github.com/JuliaCollections/DataStructures.jl)
- [*StaticArrays.jl*](https://github.com/JuliaArrays/StaticArrays.jl) is a good inspiration for static data structures in Julia

{{% toc %}}

# First thoughts: value type parameter

Julia allows developers to define type parameters.
In the case of a list, the most obvious one may be the
type of data it contains:
{{< highlight julia>}}
abstract type MyList{T} end
{{< /highlight >}}

Some types are however parametrized on other things, if we look at the
definition of `AbstractArray` for example:

>		AbstractArray{T,N}
>	Supertype for N-dimensional arrays (or array-like types) with elements of type T.

The two type parameters are another type `T` and integer `N` for the
dimensionality (tensor rank). The only constraint for a value to be
an acceptable type parameter is to be composed of plain bits, complying
with `isbitstype`.  

This looks great, we could define our StaticList
directly using integers.

{{< highlight julia>}}
"""
A static list of type `T` and length `L`
"""
abstract type StaticList{T,L} end

struct Nil{T} <: StaticList{T,0} end

StaticList{T}() where T = Nil{T}()
StaticList(v::T) where T = Cons(v, Nil{T}())

struct Cons{T,L} <: StaticList{T,L+1}
    h::T
    t::StaticList{T,L}
    function Cons(v::T, t::StaticList{T,L}) where {T,L}
        new{T,L}(v,t)
    end
end

# Usage:
# Cons(3, Nil{Int}()) is of type StaticList{Int,1}
# Cons(4, Cons(3, Nil{Int}())) is of type StaticList{Int,2}
{{< /highlight >}}

If you try to evaluate this code, you will get an error:
{{< highlight julia>}}
ERROR: MethodError: no method matching +(::TypeVar, ::Int64)
{{< /highlight >}}

Pretty explicit, you cannot perform any computation on values used as type
parameters. With more complex operations, this could make the compiler hang,
crash or at least perform poorly (we would be forcing the compiler to execute
this code at compile-time).  

One way there might be around this is macros or replacing sub-typing with
another mechanism. For the macro-based approach,
[ComputedFieldTypes.jl](https://github.com/vtjnash/ComputedFieldTypes.jl)
does exactly that. More discussion on computed type parameters in
[1] and [2].  

**Edit**: using integer type parameters can be achieved using *ComputedFieldTypes.jl* as such:

{{< highlight julia>}}
julia> using ComputedFieldTypes

julia> abstract type StaticList{T,L} end

julia> struct Nil{T} <: StaticList{T,0} end

julia> @computed struct Cons{T,L} <: StaticList{T,L}
           h::T
           t::StaticList{T,L-1}
           function Cons(v::T, t::StaticList{T,L0}) where {T,L0}
               L = L0+1
               new{T,L}(v,t)
           end
       end

julia> Cons(3, Nil{Int}())
Cons{Int64,1,0}(3, Nil{Int64}())

julia> Cons(4, Cons(3, Nil{Int}()))
Cons{Int64,2,1}(4, Cons{Int64,1,0}(3, Nil{Int64}()))
{{< /highlight >}}

This might be the neatest option for building the `StaticList`.


# Recursive natural numbers

We can use the same technique as in the Scala post, representing natural
number using recursive types.

- `ZeroLength` is a special singleton type
- `Next{L}` represents the number following the one represented by `L`

We can modify our previous example:
{{< highlight julia>}}
"""
A type parameter for List length, the numerical length can be retrieved
using `length(l::Length)`
"""
abstract type Length end
struct ZeroLength <: Length end
struct Next{L<:Length} <: Length end

"""
A linked list of size known at compile-time
"""
abstract type StaticList{T,L<:Length} end

struct Nil{T} <: StaticList{T,ZeroLength} end

StaticList{T}() where T = Nil{T}()
StaticList(v::T) where T = Cons(v, Nil{T}())

struct Cons{T,L<:Length} <: StaticList{T,Next{L}}
    h::T
    t::StaticList{T,L}
    function Cons(v::T, t::StaticList{T,L}) where {T,L<:Length}
        new{T,L}(v,t)
    end
end

"""
By default, the type of the Nil is ignored if different
from the type of first value
"""
Cons(v::T,::Type{Nil{T1}}) where {T,T1} = Cons(v, Nil{T}())

{{< /highlight >}}

We can then define basic information for a list, its length:

{{< highlight julia>}}
Base.length(::Type{ZeroLength}) = 0
Base.length(::Type{Next{L}}) where {L} = 1 + length(L)

Base.eltype(::StaticList{T,L}) where {T,L} = T
Base.length(l::StaticList{T,L}) where {T,L} = length(L)
{{< /highlight >}}

One thing should catch your attention in this block,
we use a recursive definition of `length` for the `Length` type,
which means we can blow our compiler. However, both of the definitions
are static, in the sense that they don't use type information, so
the final call should reduce to spitting out the length cached at compile-time.
You can confirm this is the case by checking the produced assembly instructions with `@code_native`.
We respected our contract of a list with size known at compile-time.

# Implementing a list-y behaviour

This part is heavily inspired by the *DataStructures.jl* list implementation,
as such we will not re-define methods with semantically similar but
implement them for our list type. Doing so for your own package
allows user to switch implementation for the same generic code.  

The first operation is being able to join a head with an existing list:

{{< highlight julia>}}
DataStructures.cons(v::T,l::StaticList{T,L}) where {T,L} = Cons(v,l)

"""
Allows for `cons(v,Nil)`. Note that the `Nil` type is ignored.
"""
DataStructures.cons(v::T,::Type{Nil}) where {T} = StaticList(v)

(::Colon)(v::T,l::StaticList{T,L}) where {T,L} = DataStructures.cons(v, l)
(::Colon)(v::T,::Type{Nil}) where {T,L} = DataStructures.cons(v, Nil{T})
{{< /highlight >}}

Implementing the odd `::Colon` methods allows for a very neat syntax:

{{< highlight julia>}}
l0 = StaticList{Int}()
l1 = 1:l0
l2 = 2:l1
{{< /highlight >}}

Unlike the Scala post, we are not using the `::` operator which
is reserved for typing expressions in Julia.
We can add a basic head and tail methods, which allow querying
list elements without touching the inner structure. This
will be useful later on.

{{< highlight julia>}}
DataStructures.head(l::Cons{T,L}) where {T,L} = l.h
DataStructures.tail(l::Cons{T,L}) where {T,L} = l.t
{{< /highlight >}}

Testing list equality can be done recursively, dispatching on the three
possible cases:

{{< highlight julia>}}
==(l1::StaticList, l2::StaticList) = false

function ==(l1::L1,l2::L2) where {T1,L,T2,L1<:Cons{T1,L},L2<:Cons{T2,L}}
    l1.h == l2.h && l1.t == l2.t
end

"""
Two `Nil` are always considered equal, no matter the type
"""
==(::Nil,::Nil) = true
{{< /highlight >}}

We can now define basic higher-order functions, such as `zip` below,
and implement the iteration interface.

{{< highlight julia>}}
function Base.zip(l1::Nil{T1},l2::StaticList{T2,L2}) where {T1,T2,L2}
    Nil{Tuple{T1,T2}}
end

function Base.zip(l1::Cons{T1,L1},l2::Cons{T2,L2}) where {T1,L1,T2,L2}
    v = (l1.h, l2.h)
    Cons(v,zip(l1.t,l2.t))
end

Base.iterate(l::StaticList, ::Nil) = nothing
function Base.iterate(l::StaticList, state::Cons = l)
    (state.h, state.t)
end
{{< /highlight >}}

Iterating over our lists is fairly straight-forward, and will be more efficient than
the recursive implementations of the higher-order functions, we still kept it for
equality checking, more a matter of keeping a functional style in line with the Scala post.  

The case of list reversal is fairly straightforward: iterate and accumulate
the list in a new one.

{{< highlight julia>}}
function Base.reverse(l::StaticList{T,L}) where {T,L}
    l2 = Nil{T}
    for h in l
        l2 = Cons(h, l2)
    end
    l2
end
{{< /highlight >}}

We define the cat operation between multiple lists.

{{< highlight julia>}}
function Base.cat(l1::StaticList{T,L},l2::StaticList{T,L}) where {T,L}
    l = l2
    for e in reverse(l1)
        l = Cons(e, l)
    end
    l
end
{{< /highlight >}}

The reverse is necessary to keep the order of the two lists.
 
# Special-valued lists

Now that we have a basic static list implementation, we can spice things up.
`StaticList` is just an abstract type in our case, not an algebraic data type
as in common functional implementations, meaning we can define other sub-types.  

Imagine a numeric list, with a series of zeros or ones somewhere.
Instead of storing all of them, we can find a smart way of representing them.
Let us define a static list of ones:

{{< highlight julia>}}
struct OnesStaticList{T<:Number,L<:Length} end

Base.iterate(l::OnesStaticList, ::Type{ZeroLength}) = nothing
function Base.iterate(l::OnesStaticList{T,L}, state::Type{Next{L1}} = L) where $
    (one(T), L1)
end
{{< /highlight >}}

This list corresponds to the 1 value of type `T`, repeated for all elements.
In a similar fashion, one can define a ZeroList:

{{< highlight julia>}}
struct ZerosStaticList{T<:Number,L<:Length} end

Base.iterate(l::ZerosStaticList, ::Type{ZeroLength}) = nothing
function Base.iterate(l::ZerosStaticList{T,L}, state::Type{Next{L1}} = L) where$
    (zero(T), L1)
end
{{< /highlight >}}

One thing to note is that these lists are terminal, in the sense that they cannot
be part of a greater list. To fix this, we can add a tail to these as follows:
{{< highlight julia>}}
struct ZerosStaticList{T<:Number,L<:Length,TL<:StaticList{T,<:Length}}
	t::TL
end

Base.iterate(l::ZerosStaticList, ::Type{ZeroLength}) = l.t
function Base.iterate(l::ZerosStaticList{T,L}, state::Type{Next{L1}} = L) where$
    (zero(T), L1)
end
{{< /highlight >}}

The `t` field of the list contains the tail after the series of zeros,
we can thus build a much simpler representation in case of long constant series.
In a similar fashion, one could define a constant list of `N` elements, storing
the value just once.

# Multi-typed lists

There is one last extension we can think of with this data structure.
Since we have a recursive length parameter, why not add it a type at each new node?

{{< highlight julia>}}
abstract type TLength end
struct TZeroLength <: TLength end
struct TNext{T,L<:TLength} <: TLength end

abstract type TStaticList{L<:TLength} end

struct TNil <: TStaticList{TZeroLength} end

struct TCons{T, L<:TLength} <: TStaticList{TNext{T,L}}
    h::T
    t::TStaticList{L}
    function TCons(v::T, t::TStaticList{L}) where {T,L<:TLength}
        new{T,L}(v,t)
    end
end

{{< /highlight >}}
 
With such construct, all nodes can be of a different type `T`, without
removing the type information from the compiler.

{{< highlight julia>}}
julia> TCons(3,TNil())
TCons{Int64,TZeroLength}(3, TNil())

julia> TCons("ha", TCons(3,TNil()))
TCons{String,TNext{Int64,TZeroLength}}("ha", TCons{Int64,TZeroLength}(3, TNil()))
{{< /highlight >}}

One interesting thing to note here is that the type takes the same
structure as the list itself:

**Type**: either a `T` and a `TLength` containing the rest of the type, or `TNil`  
**Data**: either a value of a given type and the rest of the list, or empty list

# Conclusion

The Julia type system and compiler allow for sophisticated specifications
when designing data structures, which gives it a feel of compiled languages.
This however should not be abused, in our little toy example, the type parameter
grows in complexity as the list does, which means the compiler has to carry out
some computation.  

If you want some further compile-time tricks, [Andy Ferris's](https://www.youtube.com/watch?v=SeqAQHKLNj4)
workshop at JuliaCon 2018 details how to perform compile-time computations
between bits and then bytes.  

If you have any idea how to implement `StaticList` using integer parameters instead
of custom struct I would be glad to exchange. Porting this to
use [ComputedFieldTypes.jl](https://github.com/vtjnash/ComputedFieldTypes.jl) might be a fun
experiment.  

Feel free to reach out any way you prefer, [Twitter](https://twitter.com/matbesancon),
[email](/#contact) to exchange or discuss this post.

--------

# Sources

Header image source: https://pxhere.com/en/photo/742575

[1] A proposal on Julia "Defer calculation of field types until type parameters are known", [julia/issues/18466](https://github.com/JuliaLang/julia/issues/18466)    
[2] Discussion on compile-time computations on [Discourse](https://discourse.julialang.org/t/compile-time-arithmetic-for-parameterized-types/13991)
