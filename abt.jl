module ABTs
export Operator, Variable, newvar,
  View, V, Abs, App, ABT, into, out,
  expr_to_abt

using MLStyle

struct Operator
  name::Symbol
  arity::Vector{Int}
end

Base.show(io::IO, ::MIME"text/plain", o::Operator) = print(io,string(o.name))

struct Variable
  name::Symbol
  seed::Int
end

newvar(v) = Variable(v, rand(1:typemax(Int)))

Base.show(io,::MIME"text/plain", v::Variable) = print(io, string(v.name))

@data View{T} begin
  V(Variable)
  Abs(Variable, T)
  App(Operator, Vector{T})
end

@data ABT begin
  FV(Variable)
  BV(Int)
  ABS(ABT)
  OPER(Operator, Vector{ABT})
end

function Base.:(==)(x::ABT,y::ABT)
  @match (x,y) begin
    (FV(v),FV(w)) => v == w
    (BV(i),BV(j)) => i == j
    (ABS(x_), ABS(y_)) => x_ == y_
    (OPER(ox,xs), OPER(oy,ys)) => ox == oy && xs == ys
    _ => false
  end
end

function Base.show(io::IO, m::MIME"text/plain", x::ABT)
  @match x begin
    FV(v) => begin
      print(io,"φ[")
      print(io, string(v.name))
      print(io,"]")
    end
    BV(i) => begin
      print(io,"β[")
      print(io,i)
      print(io,"]")
    end
    ABS(y) => begin
      print(io, "π[")
      show(io,m,y)
      print(io,"]")
    end
    OPER(o,ys) => begin
      show(io,m,o)
      print(io,"(")
      for y in ys[1:end-1]
        show(io,m,y)
        print(io,", ")
      end
      show(io,m,ys[end])
      print(io,")")
    end
  end
end

function bind(v::Variable, x::ABT)
  function bindlevel(i::Int, y::ABT)
    @match y begin
      FV(w) => w == v ? BV(i) : FV(w)
      BV(j) => BV(j)
      ABS(z) => ABS(bindlevel(i+1,z))
      OPER(o, xs) => OPER(o, bindlevel.(i,xs))
    end
  end

  ABS(bindlevel(0,x))
end

function substitute(x::ABT, y::ABT, level::Int=0)
  @match x begin
    FV(w) => FV(w)
    BV(j) => j == level ? y : BV(j)
    ABS(z) => ABS(substitute(z,y,level+1))
    OPER(o,xs) => OPER(o, substitute.(xs,y,i))
  end
end

function unbind(x::ABT)
  v = newvar(:v)
  (v,substitute(x,FV(v)))
end

function hasbinders(x::ABT, n::Int)
  if n == 0
    true
  else
    @match x begin
      ABS(y) => hasbinders(y, n-1)
      _ => false
    end
  end
end
  
function check(o::Operator, xs::Vector{ABT})
  length(o.arity) == length(xs) && all(hasbinders(x, i) for (x,i) in zip(xs, o.arity))
end

function into(x::View{ABT})
  @match x begin
    V(x) => FV(x)
    Abs(v, x) => bind(v,x)
    App(o, xs) => if check(o, xs)
      OPER(o,xs)
    else
      throw(DomainError("operator does not match binding patterns"))
    end
  end
end

function out(x::ABT)
  @match x begin
    FV(v) => V{ABT}(v)
    BV(j) => throw(DomainError("Cannot unwrap a naked bound variable"))
    ABS(y) => Abs{ABT}(unbind(y)...)
    OPER(o, xs) => App{ABT}(o, xs)
  end
end

function strip_blocks(e)
  @match e begin
    Expr(:block, lines...) => begin
      lines = filter(l -> !isa(l, LineNumberNode), lines)
      if length(lines) == 1
        strip_blocks(lines[1])
      else
        throw(DomainError("Blocks with multiple lines not supported"))
      end
    end
    Expr(head, body...) => Expr(head, strip_blocks.(body)...)
    s::Symbol => s
  end
end

function expr_to_abt(e::Union{Symbol,Expr}, ops::Dict{Symbol,Operator})
  function helper(expr)
    @match expr begin
      v::Symbol => FV(Variable(v,0))
      Expr(:call, f::Symbol, xs...) => into(App{ABT}(ops[f], helper.(xs)))
      Expr(:->, v::Symbol, x) => into(Abs{ABT}(Variable(v,0),helper(x)))
      _ => throw(DomainError("unsupported syntax"))
    end
  end
  helper(strip_blocks(e))
end

end
