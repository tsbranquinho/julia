# This file is a part of Julia. License is MIT: https://julialang.org/license

import .Base: setindex!, getindex, unsafe_convert
import .Base.Sys: ARCH, WORD_SIZE

export
    Atomic,
    atomic_cas!,
    atomic_xchg!,
    atomic_add!, atomic_sub!,
    atomic_and!, atomic_nand!, atomic_or!, atomic_xor!,
    atomic_max!, atomic_min!,
    atomic_fence

"""
    Threads.Atomic{T}

Holds a reference to an object of type `T`, ensuring that it is only
accessed atomically, i.e. in a thread-safe manner.

New atomic objects can be created from a non-atomic values; if none is
specified, the atomic object is initialized with zero.

Atomic objects can be accessed using the `[]` notation:

# Examples
```jldoctest
julia> x = Threads.Atomic{Int}(3)
Base.Threads.Atomic{Int64}(3)

julia> x[] = 1
1

julia> x[]
1
```

Atomic operations use an `atomic_` prefix, such as [`atomic_add!`](@ref),
[`atomic_xchg!`](@ref), etc.
"""
mutable struct Atomic{T}
    @atomic value::T
    Atomic{T}() where {T} = new(zero(T))
    Atomic{T}(value) where {T} = new(value)
end


Atomic() = Atomic{Int}()

const LOCK_PROFILING = Atomic{Int}(0)
lock_profiling(state::Bool) = state ? atomic_add!(LOCK_PROFILING, 1) : atomic_sub!(LOCK_PROFILING, 1)
lock_profiling() = LOCK_PROFILING[] > 0

const LOCK_CONFLICT_COUNT = Atomic{Int}(0);
inc_lock_conflict_count() = atomic_add!(LOCK_CONFLICT_COUNT, 1)

"""
    Threads.atomic_cas!(x::Atomic{T}, cmp::T, newval::T) where T

Atomically compare-and-set `x`

Atomically compares the value in `x` with `cmp`. If equal, write
`newval` to `x`. Otherwise, leaves `x` unmodified. Returns the old
value in `x`. By comparing the returned value to `cmp` (via `===`) one
knows whether `x` was modified and now holds the new value `newval`.

For further details, see LLVM's `cmpxchg` instruction.

This function can be used to implement transactional semantics. Before
the transaction, one records the value in `x`. After the transaction,
the new value is stored only if `x` has not been modified in the mean
time.

# Examples
```jldoctest
julia> x = Threads.Atomic{Int}(3)
Base.Threads.Atomic{Int64}(3)

julia> Threads.atomic_cas!(x, 4, 2);

julia> x
Base.Threads.Atomic{Int64}(3)

julia> Threads.atomic_cas!(x, 3, 2);

julia> x
Base.Threads.Atomic{Int64}(2)
```
"""
function atomic_cas! end

"""
    Threads.atomic_xchg!(x::Atomic{T}, newval::T) where T

Atomically exchange the value in `x`

Atomically exchanges the value in `x` with `newval`. Returns the **old**
value.

For further details, see LLVM's `atomicrmw xchg` instruction.

# Examples
```jldoctest
julia> x = Threads.Atomic{Int}(3)
Base.Threads.Atomic{Int64}(3)

julia> Threads.atomic_xchg!(x, 2)
3

julia> x[]
2
```
"""
function atomic_xchg! end

"""
    Threads.atomic_add!(x::Atomic{T}, val::T) where T <: ArithmeticTypes

Atomically add `val` to `x`

Performs `x[] += val` atomically. Returns the **old** value. Not defined for
`Atomic{Bool}`.

For further details, see LLVM's `atomicrmw add` instruction.

# Examples
```jldoctest
julia> x = Threads.Atomic{Int}(3)
Base.Threads.Atomic{Int64}(3)

julia> Threads.atomic_add!(x, 2)
3

julia> x[]
5
```
"""
function atomic_add! end

"""
    Threads.atomic_sub!(x::Atomic{T}, val::T) where T <: ArithmeticTypes

Atomically subtract `val` from `x`

Performs `x[] -= val` atomically. Returns the **old** value. Not defined for
`Atomic{Bool}`.

For further details, see LLVM's `atomicrmw sub` instruction.

# Examples
```jldoctest
julia> x = Threads.Atomic{Int}(3)
Base.Threads.Atomic{Int64}(3)

julia> Threads.atomic_sub!(x, 2)
3

julia> x[]
1
```
"""
function atomic_sub! end

"""
    Threads.atomic_and!(x::Atomic{T}, val::T) where T

Atomically bitwise-and `x` with `val`

Performs `x[] &= val` atomically. Returns the **old** value.

For further details, see LLVM's `atomicrmw and` instruction.

# Examples
```jldoctest
julia> x = Threads.Atomic{Int}(3)
Base.Threads.Atomic{Int64}(3)

julia> Threads.atomic_and!(x, 2)
3

julia> x[]
2
```
"""
function atomic_and! end

"""
    Threads.atomic_nand!(x::Atomic{T}, val::T) where T

Atomically bitwise-nand (not-and) `x` with `val`

Performs `x[] = ~(x[] & val)` atomically. Returns the **old** value.

For further details, see LLVM's `atomicrmw nand` instruction.

# Examples
```jldoctest
julia> x = Threads.Atomic{Int}(3)
Base.Threads.Atomic{Int64}(3)

julia> Threads.atomic_nand!(x, 2)
3

julia> x[]
-3
```
"""
function atomic_nand! end

"""
    Threads.atomic_or!(x::Atomic{T}, val::T) where T

Atomically bitwise-or `x` with `val`

Performs `x[] |= val` atomically. Returns the **old** value.

For further details, see LLVM's `atomicrmw or` instruction.

# Examples
```jldoctest
julia> x = Threads.Atomic{Int}(5)
Base.Threads.Atomic{Int64}(5)

julia> Threads.atomic_or!(x, 7)
5

julia> x[]
7
```
"""
function atomic_or! end

"""
    Threads.atomic_xor!(x::Atomic{T}, val::T) where T

Atomically bitwise-xor (exclusive-or) `x` with `val`

Performs `x[] \$= val` atomically. Returns the **old** value.

For further details, see LLVM's `atomicrmw xor` instruction.

# Examples
```jldoctest
julia> x = Threads.Atomic{Int}(5)
Base.Threads.Atomic{Int64}(5)

julia> Threads.atomic_xor!(x, 7)
5

julia> x[]
2
```
"""
function atomic_xor! end

"""
    Threads.atomic_max!(x::Atomic{T}, val::T) where T

Atomically store the maximum of `x` and `val` in `x`

Performs `x[] = max(x[], val)` atomically. Returns the **old** value.

For further details, see LLVM's `atomicrmw max` instruction.

# Examples
```jldoctest
julia> x = Threads.Atomic{Int}(5)
Base.Threads.Atomic{Int64}(5)

julia> Threads.atomic_max!(x, 7)
5

julia> x[]
7
```
"""
function atomic_max! end

"""
    Threads.atomic_min!(x::Atomic{T}, val::T) where T

Atomically store the minimum of `x` and `val` in `x`

Performs `x[] = min(x[], val)` atomically. Returns the **old** value.

For further details, see LLVM's `atomicrmw min` instruction.

# Examples
```jldoctest
julia> x = Threads.Atomic{Int}(7)
Base.Threads.Atomic{Int64}(7)

julia> Threads.atomic_min!(x, 5)
7

julia> x[]
5
```
"""
function atomic_min! end

#const nand = (~) ∘ (&) # ComposedFunction generated very poor code quality
nand(x, y) = ~(x & y)

getindex(x::Atomic) = @atomic :acquire x.value
setindex!(x::Atomic, v) = (@atomic :release x.value = v; x)
atomic_cas!(x::Atomic, cmp, new) = (@atomicreplace :acquire_release :acquire x.value cmp => new).old
atomic_add!(x::Atomic, v) = (@atomic :acquire_release x.value + v).first
atomic_sub!(x::Atomic, v) = (@atomic :acquire_release x.value - v).first
atomic_and!(x::Atomic, v) = (@atomic :acquire_release x.value & v).first
atomic_or!(x::Atomic, v) = (@atomic :acquire_release x.value | v).first
atomic_xor!(x::Atomic, v) = (@atomic :acquire_release x.value ⊻ v).first
atomic_nand!(x::Atomic, v) = (@atomic :acquire_release x.value nand v).first
atomic_xchg!(x::Atomic, v) = (@atomicswap :acquire_release x.value = v)
atomic_min!(x::Atomic, v) = (@atomic :acquire_release x.value min v).first
atomic_max!(x::Atomic, v) = (@atomic :acquire_release x.value max v).first

"""
    Threads.atomic_fence()

Insert a sequential-consistency memory fence

Inserts a memory fence with sequentially-consistent ordering
semantics. There are algorithms where this is needed, i.e. where an
acquire/release ordering is insufficient.

This is likely a very expensive operation. Given that all other atomic
operations in Julia already have acquire/release semantics, explicit
fences should not be necessary in most cases.

For further details, see LLVM's `fence` instruction.
"""
atomic_fence() = Core.Intrinsics.atomic_fence(:sequentially_consistent)


# Corrected NEW CODE section
# This section optimizes atomic field operations by replacing CAS loops
# with direct atomic instructions for common operations (+, -, &, |, xor)

# Override the default modifyfield! to handle common operations efficiently
@inline function modifyfield!(x, fld::Symbol, op::F, val, order::Symbol) where F
    # Check for specific operations we can optimize
    if op === (+)
        # Use direct atomic addition instead of CAS loop
        return atomic_addfield!(x, fld, val)
    elseif op === (-)
        # Use direct atomic subtraction instead of CAS loop
        return atomic_subfield!(x, fld, val)
    elseif op === (&)
        # Use direct atomic bitwise AND instead of CAS loop
        return atomic_andfield!(x, fld, val)
    elseif op === (|)
        # Use direct atomic bitwise OR instead of CAS loop
        return atomic_orfield!(x, fld, val)
    elseif op === (⊻)
        # Use direct atomic bitwise XOR instead of CAS loop
        return atomic_xorfield!(x, fld, val)
    end
    
    # Fallback to CAS loop for operations we don't optimize
    # This is the original implementation that uses compare-and-swap
    while true
        # Read current value with specified memory ordering
        old = getfield(x, fld, order)
        # Compute new value using the operation
        new = op(old, val)
        # Attempt to swap the value
        ret = swapfield!(x, fld, new, order, old)
        # If swap succeeded, return old value
        ret === old && return old
    end
end

# Optimized atomic addition for field
@inline function atomic_addfield!(x, fld::Symbol, val)
    # Get pointer to the field
    ptr = getfieldptr(x, fld)
    # Get type of the field
    T = getfieldtype(x, fld)
    # Convert value to field type (for type safety)
    val_conv = convert(T, val)
    # Call low-level atomic add
    return atomic_add!(ptr, val_conv)
end

# Optimized atomic subtraction for field (same pattern as addition)
@inline function atomic_subfield!(x, fld::Symbol, val)
    ptr = getfieldptr(x, fld)
    T = getfieldtype(x, fld)
    val_conv = convert(T, val)
    return atomic_sub!(ptr, val_conv)
end

# Optimized atomic bitwise AND for field
@inline function atomic_andfield!(x, fld::Symbol, val)
    ptr = getfieldptr(x, fld)
    T = getfieldtype(x, fld)
    val_conv = convert(T, val)
    return atomic_and!(ptr, val_conv)
end

# Optimized atomic bitwise OR for field
@inline function atomic_orfield!(x, fld::Symbol, val)
    ptr = getfieldptr(x, fld)
    T = getfieldtype(x, fld)
    val_conv = convert(T, val)
    return atomic_or!(ptr, val_conv)
end

# Optimized atomic bitwise XOR for field
@inline function atomic_xorfield!(x, fld::Symbol, val)
    ptr = getfieldptr(x, fld)
    T = getfieldtype(x, fld)
    val_conv = convert(T, val)
    return atomic_xor!(ptr, val_conv)
end

# Low-level atomic add implementation using LLVM intrinsics
@noinline function atomic_add!(ptr::Ptr{T}, val::T) where T <: Union{Int32,Int64,UInt32,UInt64}
    # Determine bit width of the type (32 or 64 bits)
    bits = 8 * sizeof(T)
    
    # LLVM assembly template for atomicrmw add instruction:
    # 1. Convert integer pointer to actual pointer
    # 2. Perform atomic addition with acquire-release ordering
    # 3. Return the original value
    asm = """
        %ptr = inttoptr i64 %0 to ptr
        %res = atomicrmw add ptr %ptr, i$bits %1 acq_rel
        ret i$bits %res
    """
    
    # Call LLVM with our assembly template
    # Parameters: 
    #   asm - the assembly template
    #   T - return type
    #   Argument types: (pointer, value)
    Base.llvmcall((asm, T), T, Tuple{Ptr{T}, T}, ptr, val)
end

@noinline function atomic_sub!(ptr::Ptr{T}, val::T) where T <: Union{Int32,Int64,UInt32,UInt64}
    # Same pattern as atomic_add!
    bits = 8 * sizeof(T)
    asm = """
        %ptr = inttoptr i64 %0 to ptr
        %res = atomicrmw sub ptr %ptr, i$bits %1 acq_rel
        ret i$bits %res
    """
    Base.llvmcall((asm, T), T, Tuple{Ptr{T}, T}, ptr, val)
end

@noinline function atomic_and!(ptr::Ptr{T}, val::T) where T <: Union{Int32,Int64,UInt32,UInt64}
    bits = 8 * sizeof(T)
    asm = """
        %ptr = inttoptr i64 %0 to ptr
        %res = atomicrmw and ptr %ptr, i$bits %1 acq_rel
        ret i$bits %res
    """
    Base.llvmcall((asm, T), T, Tuple{Ptr{T}, T}, ptr, val)
end

@noinline function atomic_or!(ptr::Ptr{T}, val::T) where T <: Union{Int32,Int64,UInt32,UInt64}
    bits = 8 * sizeof(T)
    asm = """
        %ptr = inttoptr i64 %0 to ptr
        %res = atomicrmw or ptr %ptr, i$bits %1 acq_rel
        ret i$bits %res
    """
    Base.llvmcall((asm, T), T, Tuple{Ptr{T}, T}, ptr, val)
end

@noinline function atomic_xor!(ptr::Ptr{T}, val::T) where T <: Union{Int32,Int64,UInt32,UInt64}
    bits = 8 * sizeof(T)
    asm = """
        %ptr = inttoptr i64 %0 to ptr
        %res = atomicrmw xor ptr %ptr, i$bits %1 acq_rel
        ret i$bits %res
    """
    Base.llvmcall((asm, T), T, Tuple{Ptr{T}, T}, ptr, val)
end

# Helper: Get pointer to a field in an object
function getfieldptr(x, fld::Symbol)
    # 1. Get pointer to the object itself
    obj_ptr = pointer_from_objref(x)
    # 2. Get type of the object
    T = typeof(x)
    # 3. Find index of the field
    idx = fieldindex(T, fld)
    # 4. Get byte offset of the field
    offset = fieldoffset(T, idx)
    # 5. Return pointer to the field (object address + offset)
    return obj_ptr + offset
end

# Helper: Get type of a field
getfieldtype(x, fld::Symbol) = fieldtype(typeof(x), fld)
#END OF NEW CODE