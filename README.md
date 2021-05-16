# Abstract Binding Trees for Julia

Usage:

`Operator` takes in a name and an arity, which is a list that gives the number of binders needed for each argument

```julia
> Pkg.activate(".")
> include("abt.jl")
> using .ABTs
> ops = Dict(:λ => Operator(:λ, [1]), :+ => Operator(:+, [0,0]))
```

`expr_to_abt` converts a Julia expression to a ABT.
Anonymous functions are converted to binders with deBruin indices, and function calls are converted into applications of operators (which are looked up in ops)

```julia
> expr_to_abt(:(λ(x -> x + y)), ops)
λ(π[+(β[0], φ[y])])
```

Because of the indexing, α-equivalent syntax trees are simply equal.
``` julia
> expr_to_abt(:(λ(x -> x + y)), ops) == expr_to_abt(:(λ(z -> z + y)), ops)
true
```

The abstract binding tree is printed out in a compact representation. Free variables are denoted by `φ[name]`, bound variables are denoted by `β[deBruin index]`, binders are denoted by `π[expr]`, and operator application is denoted by `op(args...)`.
