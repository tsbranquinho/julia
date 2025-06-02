using InteractiveUtils
using Base.Threads

mutable struct AtomicField{T}
    @atomic x::T
end

add!(x::AtomicField{T}, val::T) where {T} = (modifyfield!(x, :x, +, val, :acquire_release); nothing)
add!(x::Threads.Atomic{T}, val::T) where {T} = (Threads.atomic_add!(x, val); nothing)

base_atomic = Threads.Atomic{Int}(1)
field_atm = AtomicField(1)

println("=== Caso 3: atomic_add! com função simples (não gera atomicrmw) ===")
println("LLVM do add!:")
println("--------------------------------------------------")
@code_llvm add!(base_atomic, 1)
println("--------------------------------------------------\n\n")

println("LLVM do add!:")
println("--------------------------------------------------")
@code_llvm add!(field_atm, 1)
println("--------------------------------------------------\n\n")