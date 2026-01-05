+++
date = 2025-12-27
draft = false
tags = ["julia"]
title = "Interfacing in Julia with extensions"
math = true
diagram = false
+++

The Julia package manager introduced in v1.9 the package extension and weak dependency mechanisms, offering more ways to use external packages without adding dependencies directly to a project when not used.
After facing some limitations, I wanted to write down the different options of the design space for one specific problem.

# Use case

Numerical linear algebra is a backbone of a wide range of computational science.
My use case came in FrankWolfe.jl, in which optimization over several sets requires computing the leading eigenvector of a matrix.
Multiple packages can perform this operation, and we do not want the package to be tied to a single implementation.
The historical default has been through the [Arpack](https://github.com/JuliaLinearAlgebra/Arpack.jl) wrapper.
For simplicity, we will look at the spectraplex linear minimization oracle (LMO), and
we will write the simplified interface as:
```julia
struct Spectraplex{O}
    options::O
end

function compute_extreme_point(lmo::Spectraplex, direction::AbstractMatrix)
    _, evec = Arpack.eigs(-direction, nev=1, which=:LR; lmo.options...)
    unit_vec = vec(evec)
    return unit_vec * unit_vec'
end
```

The function computes the minimizer of the linear function represented by the `direction` matrix over the spectraplex, the set of positive semidefinite matrices of trace one.
An optimizer is always a rank-one matrix which can be computed from the leading eigenvector of the negative direction. The `options` field contains Arpack-specific algorithmic options.

Arpack does the job in most cases but it only supports standard `Float64`, standard dense matrices and runs on CPU, all of these providing ample motivation to give users several choices.

# The backend option

This is typically the choice one would make when handling dependencies is a pain or for monolithic setups.
Essentially, the FrankWolfe.jl would add a dependency on multiple packages and provide this as an option.
We will use a fake alternative `Mypack` that can compute eigenvectors.

```julia
struct ArpackBackend{O}
    options::O
end

struct MypackBackend{O}
    options::O
end

struct Spectraplex{B}
    backend::B
end

function compute_extreme_point(lmo::Spectraplex{ArpackBackend}, direction::AbstractMatrix)
    _, evec = Arpack.eigs(-direction, nev=1, which=:LR; lmo.options...)
    unit_vec = vec(evec)
    return unit_vec * unit_vec'
end

function compute_extreme_point(lmo::Spectraplex{MypackBackend}, direction::AbstractMatrix)
    _, evec = Mypack.other_eigs_function(-direction, nev=1, which=:LR; lmo.options...)
    unit_vec = vec(evec)
    return unit_vec * unit_vec'
end
```

Realistically, a lot of backend options will be implemented around the FrankWolfe.jl ecosystem.
This design choice leaves two solutions:
- A backend option is implemented in FrankWolfe.jl, and needs the additional dependency, which makes the package heavier every time
- It is implemented in a companion package, along with the `compute_extreme_point` method.
This potentially creates a lot of tiny packages for a single LMO (FrankWolfe.jl has 23 of them at the moment), making it hard to maintain, test, document and make discoverable to users in a unified way.

# Package extensions to the rescue

Package extensions were designed specifically for this kind of use case (see the [Pkg docs](https://pkgdocs.julialang.org/v1/creating-packages/#Behavior-of-extensions)).
An extension is a submodule in a package that is loaded only if another package is loaded.
Concretely, we define a module `FrankWolfeMypackBackendExt`, and declare `Mypack` as a `weakdep` in the Project.toml.
In that extension module, `Mypack` is available as a dependency, we can load it and define the second method for `compute_extreme_point`.
If `Mypack` is loaded by a user, then so is the code in the extension.

This should be it right? Our perfect solution.
Almost, the big catch is that **package extensions cannot export new names**. See [this discussion](https://discourse.julialang.org/t/accessing-non-exported-package-extension-functions/109058/2) and [thread](https://stackoverflow.com/questions/77903811/how-to-export-symbol-from-a-package-extension-in-julia).
That means we cannot define the `MypackBackend` in the extension, so users cannot construct the LMO parameterized with Mypack, although the method exists.
A very hacky workaround would consist in using `Base.get_extension` to access the new struct.
The last alternative we are left with is definding `MypackBackend` in `FrankWolfe`, and implementing the `compute_extreme_point` in the extension.

From a discoverability perspective, this solution is frustrating because there is a 'dangling' struct in `FrankWolfe` that can be used in the `compute_extreme_point` method only if `Mypack` is loaded as a dependency. Alternatively, we could manually re-write a MethodError to document what to do, which also seems highly frustrating.

# Symbol-based package extension

An interesting design choice that removes the extension-cannot-export issue is using a symbol to dispatch and a backend storage.
In the main `FrankWolfe` module, we define:

```julia
using Arpack

struct Spectraplex{LinearAlgebraBackend,BT}
    backend::BT
end

function Spectraplex{LinearAlgebraBackend}() where {LinearAlgebraBackend}
    backend = (;)
    return Spectraplex{LinearAlgebraBackend, typeof(backend)}(backend)
end

function compute_extreme_point(lmo::Spectraplex{:Arpack}, direction::AbstractMatrix)
    _, evec = Arpack.eigs(-direction, nev=1, which=:LR; lmo.backend...)
    unit_vec = vec(evec)
    return unit_vec * unit_vec'
end
```

Note the default method which just uses an empty named tuple for the options.

In the extension, we can then define the alternative method:
```julia
using Mypack

function compute_extreme_point(lmo::Spectraplex{:Mypack}, direction::AbstractMatrix)
    _, evec = Mypack.other_eigs_function(-direction, nev=1, which=:LR; lmo.backend...)
    unit_vec = vec(evec)
    return unit_vec * unit_vec'
end
```

The `backend` field can again just be a named tuple.
Importantly, the error message for invalid symbols is also explicit:
```julia
julia> compute_extreme_point(Spectraplex{:Wrongpack}(), randn(3,3))
ERROR: MethodError: no method matching compute_extreme_point(::Spectraplex{:Wrongpack, @NamedTuple{}}, ::Matrix{Float64})
The function `compute_extreme_point` exists, but no method is defined for this combination of argument types.

Closest candidates are:
  compute_extreme_point(::Spectraplex{:Mypack}, ::AbstractMatrix)
```

# Extensibility

What about someone wanting their own backend somewhere else without having to put it in an extension?
This is still an important use case to grow as an ecosystem without having to centralize everything in FrankWolfe.jl.
If someone was to implement a new method with a symbol and named tuple as option,
this would be [type piracy](https://docs.julialang.org/en/v1/manual/style-guide/#Avoid-type-piracy-1) which is a bad practice for multiple reasons.
With this design, one can define a custom `backend` field instead of a named tuple.
Let's imagine a third option `ThirdPack` used in an external module:

```julia
struct ThirdpackBackend{O}
    options::O
end

function FrankWolfe.compute_extreme_point(lmo::FrankWolfe.Spectraplex{:Thirdpack,ThirdpackBackend}, direction::AbstractMatrix)
    _, evec = Thirdpack.yet_another_eigs(-direction, nev=1, which=:LR; lmo.backend.options...)
    unit_vec = vec(evec)
    return unit_vec * unit_vec'
end
```

So that design also leaves the possibility for external packages to implement their own `Spectraplex` backend open.
It is slightly unusual because external packages dispatch on both the symbol and the backend type, but at least this offers:
- no dependency explosion for FrankWolfe.jl
- no code for the mutlieple options in the main module
- no need for external packages for each new backend

I haven't seen this design yet in the Julia ecosystem, I might have missed it but this seems like a good option to leverage extensions in a different way.

# Edits

That design does not seem to be for everyone's taste and some people prefer a dangling struct with the implementation in the extension.
Guillaume Dalle also pointed [WeakDepHelpers.jl](https://github.com/QuantumSavory/WeakDepHelpers.jl) for tooling in that direction.
