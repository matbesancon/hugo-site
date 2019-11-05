+++
date = 2019-11-04
draft = false
tags = ["julia"]
title = "Working with binary libraries for optimization in Julia"
summary = """
When going native is the only option, at least do it once and well.
"""
math = true
diagram = false

[header]
image = ""
+++

Unlike other ecosystems in the scientific programming world, scientists
and engineers working with Julia usually prefer a whole stack in Julia for many
reasons. The compiler is doing way better when able to infer what
is going on in a piece of code; when an error is thrown, the stack trace looks
much nicer when only pure Julia code is involved, functions and types can be
defined as generic as wanted without hard-coded container or number types for instance.  

Sometimes however, inter-operability with native code is needed to use some
external native libraries. By that I mean natively built libraries
(`*.so` files on Linux systems, `*.dylib` on OSX, `*.dll` on Windows).
In this post, we will explore some tools to work with native libraries in Julia.
In the last couple weeks, I tinkered a bit with the [HiGHS](https://www.highs.dev)
solver developed at the University of Edinburgh, which I will use as an example
throughout this post. It is still work in progress, but has nice promises as the
next-generation linear optimization solver in the COIN-OR suite.

# What does a native lib look like?

Looking at the [repository](https://github.com/ERGO-Code/HiGHS/tree/a3160249c405f01b57bf27f3ff676058023122c6),
it is a pretty standard CMake-based C++ project producing both an executable and
library which can be called through a C interface.
The two initial components are:

1. The source code producing the library, this can be written in any language producing native code (C, C++, Rust)
2. The header file defining the C API to call the library from other programs.


This interface is defined in a single header file `src/interfaces/highs_c_api.h`,
header files may define a bunch of types (structs, unions, enums) but most
importantly they define function **prototypes** looking like:

```c
int preprocess_variables(int* values, double offset, float coefficient);
```

When using the function from Julia, the call to the native library looks like
the following:  

```julia
ccall(
  (my_library_name, :preprocess_variables),
  CInt, # return type
  (Ptr{Cint}, Cdouble, Cfloat), # tuple of argument types
  (pointer(my_array), 3.5, 4.5f) # tuple of arguments
)
```

Let us dive in.

# Solution 1: build and link

For this approach, the first step is to build the HiGHS library and have the
library available. Following the documentation, the instructions are:

```bash
cd HiGHS # where HiGHS is installed
mkdir build
cd build
cmake .. # generate makefiles
make # build everything here in the build directory
```

Like often with native packages, some dependencies might be implicitly assumed,
here is a Dockerfile building the project on an alpine machine, you should be
able to reproduce this with Docker installed.

```dockerfile
FROM alpine:3.7

RUN apk add git cmake g++ gcc clang make
WORKDIR /optpreprocess_variables
RUN git clone https://github.com/ERGO-Code/HiGHS.git
RUN mkdir -p HiGHS/build
WORKDIR /opt/HiGHS/build
RUN cmake .. && make
RUN make test
RUN make install # optional
```

Now back to the Julia side, say we assume the library is available at a given
path, one can write the Julia functions corresponding to the interface. It is
preferable not to expose error-prone C calls to the user. In the example of
the `preprocess_variables` function defined above, a Julia wrapper would look
like:

```julia
function preprocess_variables(my_array::Vector{Cint}, offset::Cdouble, coefficient::Cfloat)
    result = ccall(
        (:preprocess_variables, my_library_name),
        Cint, (Ptr{Cint}, Cdouble, Cfloat),
        (pointer(my_array), 3.5, 4.5f)
    )
    return result
end
```

Once these wrapper functions are defined, users can convert their values to the
corresponding expected argument types and call them. The last thing needed is `my_library_name`,
which must be the path to the library object. Hard-coding or assuming paths
should be avoided, it makes software harder to install on some systems.
One thing that can be done is asking the user to pass the library path as an
environment variable:

```julia
ENV["HIGHS_DIR"] # should contain the path to the HIGHS directory
joinpath(ENV["HIGHS_DIR"], "build", "lib", "libhighs.so")
```

Doing this every time is however not convenient. Since library paths are not
changing at every call, one can check for this path at the installation of the
package. For this purpose, a file `deps/build.jl` can be added in every package
and will be run at the installation of the package or when the `Pkg.build`
command is called. A `build.jl` for our purpose could look like:

```julia
const highs_location = ENV["HIGHS_DIR"]
const libhighs = joinpath(highs_location, "build", "lib", "libhighs.so")
const depsfile = joinpath(@__DIR__, "deps.jl")
open(depsfile, "w") do f
    print(f, "const libhighs = ")
    print(f, libhighs)
    println(f)
end
```

The snippet above looks for the *libhighs.so* library, using the environment
variable as location of the base directory of HiGHS. Placed in `build.jl`,
the script will create a `deps.jl` file in the `deps` folder of the Julia
package, and write `const libhighs = "/my/path/to/highs/lib/libhighs.so"`.
This is more or less what happens with the
[SCIP.jl wrapper](https://github.com/SCIP-Interfaces/SCIP.jl) v0.9.
Once the build step succeeds, one can add in the main module in `/src`:

```julia
module HiGHS

const deps_file = joinpath(dirname(@__FILE__),"..","deps","deps.jl")
if isfile(deps_file)
    include(deps_file)
else
    error("HiGHS not properly installed. Please run import Pkg; Pkg.build(\"HiGHS\")")
end

# other things

end # module
```

The global constant `libhighs` can then be used for *ccall*.
We now have a functional package wrapping a native library downloaded and
built separately. Summing up what we have, the Julia wrapper package looks as
follows:

```bash
$ tree
.
├── Project.toml
├── README.md
├── deps
│   ├── build.jl
│   ├── build.log
│   ├── deps.jl
├── src
│   └── HiGHS.jl
└── test
    └── runtests.jl
```

`deps/build.log` and `deps/deps.jl` are not committed in the repository but
generated when installing and/or building the Julia package.

# Lifting maintainers' burden: generating wrapper functions with Clang.jl

One time-consuming task in the previous steps is going from the C header file
describing the API to Julia functions wrapping the *ccall*. The task is mostly
repetitive and can be automated using [Clang.jl](https://github.com/JuliaInterop/Clang.jl/).
This package will generate the appropriate functions from a header file,
a reduced example looks like:

```julia
import Clang

# HIGHS_DIR = "path/to/highs/dir"
const header_file = joinpath(HIGHS_DIR, "include", "interfaces", "highs_c_api.h")
const LIB_HEADERS = [header_file]

const ctx = Clang.DefaultContext()

Clang.parse_headers!(ctx, LIB_HEADERS,
    includes=[Clang.CLANG_INCLUDE],
)

ctx.libname = "libhighs"
ctx.options["is_function_strictly_typed"] = true
ctx.options["is_struct_mutable"] = false

const api_file = joinpath(@__DIR__, "../src/wrapper", "$(ctx.libname)_api.jl")

open(api_file, "w") do f
    # write each generated function
    # ...
end
```

This snippet can be placed in a `/gen` folder of the Julia wrapper package and
writes to `src/wrapper` all the functions wrapping C calls.
It is less error-prone compared to manually writing the Julia interface and can
save a great deal of time when managing updates of the native library.
Again, the *SCIP.jl* wrapper uses this method and can be used as example.
Since the wrapper generation has different requirements than the package itself,
we can provide it a Project.toml.
Our package structure now looks like this:

```bash
$ tree
.
├── Project.toml
├── README.md
├── deps
│   ├── build.jl
│   ├── build.log
│   ├── deps.jl
├── gen
│   ├── Project.toml
│   └── gen.jl
├── src
│   ├── HiGHS.jl
│   └── wrapper
│       ├── libhighs_api.jl
│       └── libhighs_common.jl
└── test
    └── runtests.jl
```

# Lifting the user's burden: BinaryBuilder & BinaryProvider

For non-open-source software, what we did up to here this is the best you can get:
let users download and install the library, pass the path once at build time and
partly generate the Julia wrapper for *ccall* through Clang.jl.
For open-source libraries however, could we go a step further and do everything
for the user when they install the Julia package?  

That's where [BinaryBuilder](https://github.com/JuliaPackaging/BinaryBuilder.jl)
and [BinaryProvider](https://github.com/JuliaPackaging/BinaryProvider.jl) come in.
See the Docker file above, BinaryBuilder uses the same technology and arcane
tricks to cross-compile the binary artifacts (executables and libraries) natively.
It does so by letting you install the library as you would on your own machine,
using cmake, make, make install, etc. The result of running BinaryBuilder is a
single Julia script `build_tarballs.jl` describing the commands run to produce
the artifacts.
This is placed in a repository with Continuous Integration support, which creates
releases for all specified architectures, OS, compilers.
You can see examples for the Clp solver [here](https://github.com/JuliaOpt/ClpBuilder)
and for HiGHS [there](https://github.com/matbesancon/HiGHSBuilder/).  

Back to the Julia package, we can now modify the `deps/build.jl` script to use
BinaryProvider, fetching the binaries corresponding to the current system.
Without knowing anything about what's going under the hood and how the library
is built, users can simply perform `Pkg.add("ThePackage")` which will build
automatically and explicitly specify when a given OS or architecture is not
supported. Take a look at the modified
[build file](https://github.com/matbesancon/HiGHS.jl/blob/569ca888e4feea83d00326c044ec0475fee008c5/deps/build.jl) using BinaryProvider.

They don't need to guarantee that they have the same compiler, *make* and *cmake*
version to have a repeatable & smooth installation of the package.  

# Wrapping up

The process from 0 to a fully ready Julia package built on top of a binary
library is still not straightforward. Special appreciation goes to the
BinaryBuilder developers and contributors who helped me figure out some tricky
bits. But the key take-away of this is that once the pipeline is built, updating
the binary version or Julia wrapper is the same workflow one is used to with
standard Julia packages. Keep building pure Julia software for all its benefits,
but these tools I presented make it as great as possible to work with binaries.
