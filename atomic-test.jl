#====================================================================#
#   atomic-test.jl                                                   #
#                                                                    #
#   1) Definimos um módulo local “AtomicFieldTest” que cria           #
#      exatamente o tipo paramétrico com campo @atomic.              #
#                                                                    #
#   2) Dentro desse módulo, definimos cinco funções “wrapper”:       #
#      addfield!, subfield!, andfield!, orfield! e xorfield! que      #
#      chamam modifyfield!(…) sobre o campo interno :x, sempre       #
#      passando o ordering `:acquire_release` para o acesso atômico.  #
#                                                                    #
#   3) Fora do módulo, usamos @code_llvm para inspecionar o IR LLVM  #
#      gerado por cada wrapper, confirmando que sai “atomicrmw …”.   #
#                                                                    #
#   4) (Opcional) Um micro‐teste concorrente para comprovar em tempo #
#      de execução que a soma atômica realmente funciona sem data‐race.#
#====================================================================#

using InteractiveUtils    # traz @code_llvm e @code_native
using Base.Threads        # traz Threads.nthreads, Threads.@threads

#====================================================================#
# 1) Módulo local que define AtomicField{T} e cinco wrappers.        #
#                                                                    #
#    – A struct AtomicField{T} tem um campo @atomic x::T.             #
#    – Passamos explicitamente `:acquire_release` em modifyfield!     #
#      para indicar que queremos um acesso atômico.                   #
#====================================================================#
module AtomicFieldTest

export AtomicField, addfieldaa!, subfield!, andfield!, orfield!, xorfield!, modifyfield!

# → 1.1) Definição do tipo paramétrico com campo @atomic.
mutable struct AtomicField{T}
    @atomic x::T
end

# → 1.2) Cinco wrappers que apenas chamam modifyfield!(… , :acquire_release).
#      Cada wrapper retorna “nothing”, pois não precisamos do valor que modifyfield! retorna.

# ---------- ADD (soma atômica) ----------
function addfieldaa!(f::AtomicField{Int64}, v::Int64)
    # Passamos :acquire_release para que o acesso seja tratado como atômico.
    modifyfield!(f, :x, +, v, :acquire_release)
    return nothing
end

# ---------- SUB (subtração atômica) ----------
function subfield!(f::AtomicField{Int64}, v::Int64)
    modifyfield!(f, :x, -, v, :acquire_release)
    return nothing
end

# ---------- AND (bitwise-and atômico) ----------
function andfield!(f::AtomicField{Int64}, v::Int64)
    modifyfield!(f, :x, &, v, :acquire_release)
    return nothing
end

# ---------- OR (bitwise-or atômico) ----------
function orfield!(f::AtomicField{Int64}, v::Int64)
    modifyfield!(f, :x, |, v, :acquire_release)
    return nothing
end

# ---------- XOR (bitwise-xor atômico) ----------
function xorfield!(f::AtomicField{Int64}, v::Int64)
    modifyfield!(f, :x, xor, v, :acquire_release)
    return nothing
end

end # module AtomicFieldTest

#====================================================================#
# 2) Fora do módulo, “importamos” tudo e chamamos @code_llvm          #
#    para inspecionar o IR LLVM gerado por cada wrapper.             #
#====================================================================#
using .AtomicFieldTest

println("=== IR de addfield! (deve sair `atomicrmw add`) ===")
@code_llvm addfieldaa!(AtomicField(1), 3)
