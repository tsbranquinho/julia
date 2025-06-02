using BenchmarkTools
using Base.Threads
using Statistics
using Printf

# Define atomic struct with cache line alignment
mutable struct AtomicField{T}
    @atomic x::T
    _pad1::UInt64
    _pad2::UInt64
    _pad3::UInt64
    _pad4::UInt64
    _pad5::UInt64
    _pad6::UInt64
    _pad7::UInt64
end

AtomicField{T}(x::T) where T = AtomicField{T}(x, 0,0,0,0,0,0,0)
AtomicField(x::T) where T = AtomicField{T}(x, 0,0,0,0,0,0,0)

# Hardware atomic operations
hardware_atomic_add!(x::Threads.Atomic{Int}, val::Int) = Threads.atomic_add!(x, val)
hardware_atomic_sub!(x::Threads.Atomic{Int}, val::Int) = Threads.atomic_sub!(x, val)
hardware_atomic_and!(x::Threads.Atomic{Int}, val::Int) = Threads.atomic_and!(x, val)
hardware_atomic_or!(x::Threads.Atomic{Int}, val::Int) = Threads.atomic_or!(x, val)

# AtomicField direct operations
field_atomic_add!(x::AtomicField{Int}, val::Int) = modifyfield!(x, :x, +, val, :acquire_release)
field_atomic_sub!(x::AtomicField{Int}, val::Int) = modifyfield!(x, :x, -, val, :acquire_release)
field_atomic_and!(x::AtomicField{Int}, val::Int) = modifyfield!(x, :x, &, val, :acquire_release)
field_atomic_or!(x::AtomicField{Int}, val::Int) = modifyfield!(x, :x, |, val, :acquire_release)

# CAS loop implementations
function cas_atomic_add!(x::Threads.Atomic{Int}, val::Int)
    while true
        old = x[]
        new = old + val
        if Threads.atomic_cas!(x, old, new) == old
            break
        end
    end
end

function cas_atomic_sub!(x::Threads.Atomic{Int}, val::Int)
    while true
        old = x[]
        new = old - val
        if Threads.atomic_cas!(x, old, new) == old
            break
        end
    end
end

# Complex operations
function complex_atomic_cas!(x::AtomicField{Int}, a::Int, b::Int)
    while true
        old = getfield(x, :x)
        new = old * a + b
        result = replacefield!(x, :x, old, new, :acquire_release)
        result.success && break
    end
end

function complex_cas!(x::Threads.Atomic{Int}, a::Int, b::Int)
    while true
        old = x[]
        new = old * a + b
        if Threads.atomic_cas!(x, old, new) == old
            break
        end
    end
end

# Thread-safe benchmark functions with explicit thread assignment
function bench_simple_high_contention!(f, atomic, val, nthreads, total_ops)
    ops_per_thread = div(total_ops, nthreads)
    @threads for i in 1:nthreads
        for j in 1:ops_per_thread
            f(atomic, val)
        end
    end
end

function bench_simple_low_contention!(f, atomic_array, val, nthreads, total_ops)
    ops_per_thread = div(total_ops, nthreads)
    
    # Pre-assign work to threads to avoid race conditions
    tasks = Task[]
    
    for i in 1:nthreads
        task = Threads.@spawn begin
            for j in 1:ops_per_thread
                f(atomic_array[i], val)
            end
        end
        push!(tasks, task)
    end
    
    # Wait for all tasks to complete
    for task in tasks
        wait(task)
    end
end

function bench_complex_high_contention!(f, atomic, a, b, nthreads, total_ops)
    ops_per_thread = div(total_ops, nthreads)
    @threads for i in 1:nthreads
        for j in 1:ops_per_thread
            f(atomic, a, b)
        end
    end
end

function bench_complex_low_contention!(f, atomic_array, a, b, nthreads, total_ops)
    ops_per_thread = div(total_ops, nthreads)
    
    # Pre-assign work to threads to avoid race conditions
    tasks = Task[]
    
    for i in 1:nthreads
        task = Threads.@spawn begin
            for j in 1:ops_per_thread
                f(atomic_array[i], a, b)
            end
        end
        push!(tasks, task)
    end
    
    # Wait for all tasks to complete
    for task in tasks
        wait(task)
    end
end

# Benchmark runner
function run_benchmark(;total_ops=1_000_000, 
                       thread_counts=[1, 2, 4, 8, 16],
                       contention_levels=[:low, :high])
    
    results = []
    
    for nthreads in thread_counts
        # Set number of threads for this benchmark run
        if nthreads > Threads.nthreads()
            println("Skipping $nthreads threads (system has only $(Threads.nthreads()))")
            continue
        end
        
        println("\n" * "="^60)
        println(" BENCHMARKING WITH $nthreads THREADS")
        println("="^60)
        
        for contention in contention_levels
            println("\n> Contention: $contention")
            
            # Create atomic objects
            base_hardware = Threads.Atomic{Int}(0)
            base_cas = Threads.Atomic{Int}(0)
            field_atomic = AtomicField(0)
            
            # Create local accumulators for low contention
            local_base = [Threads.Atomic{Int}(0) for _ in 1:nthreads]
            local_field = [AtomicField(0) for _ in 1:nthreads]
            
            # Reset function
            function reset_all()
                base_hardware[] = 0
                base_cas[] = 0
                setfield!(field_atomic, :x, 0, :monotonic)
                for i in 1:nthreads
                    local_base[i][] = 0
                    setfield!(local_field[i], :x, 0, :monotonic)
                end
            end
            
            # Benchmark simple operations
            println("\nSimple increment (x += 1):")
            
            if contention == :high
                reset_all()
                t_hw = @belapsed bench_simple_high_contention!($hardware_atomic_add!, $base_hardware, 1, $nthreads, $total_ops) evals=1 samples=5
                reset_all()
                t_field = @belapsed bench_simple_high_contention!($field_atomic_add!, $field_atomic, 1, $nthreads, $total_ops) evals=1 samples=5
                reset_all()
                t_cas = @belapsed bench_simple_high_contention!($cas_atomic_add!, $base_cas, 1, $nthreads, $total_ops) evals=1 samples=5
            else
                reset_all()
                t_hw = @belapsed bench_simple_low_contention!($hardware_atomic_add!, $local_base, 1, $nthreads, $total_ops) evals=1 samples=5
                reset_all()
                t_field = @belapsed bench_simple_low_contention!($field_atomic_add!, $local_field, 1, $nthreads, $total_ops) evals=1 samples=5
                reset_all()
                t_cas = @belapsed bench_simple_low_contention!($cas_atomic_add!, $local_base, 1, $nthreads, $total_ops) evals=1 samples=5
            end
            
            @printf("Hardware atomic: %8.3f ms | Speed: %.1f ns/op\n", t_hw*1000, t_hw/total_ops*1e9)
            @printf("AtomicField:     %8.3f ms | Speed: %.1f ns/op | %.1f%% of hw\n", 
                    t_field*1000, t_field/total_ops*1e9, t_field/t_hw*100)
            @printf("CAS loop:        %8.3f ms | Speed: %.1f ns/op | %.1f%% of hw\n", 
                    t_cas*1000, t_cas/total_ops*1e9, t_cas/t_hw*100)
            
            push!(results, (threads=nthreads, contention=contention, operation="x+=1",
                            hw=t_hw, field=t_field, cas=t_cas))
            
            # Benchmark complex operation
            println("\nComplex operation (x = x*2 + 3):")
            
            if contention == :high
                reset_all()
                t_field_complex = @belapsed bench_complex_high_contention!($complex_atomic_cas!, $field_atomic, 2, 3, $nthreads, $total_ops) evals=1 samples=5
                reset_all()
                t_cas_complex = @belapsed bench_complex_high_contention!($complex_cas!, $base_cas, 2, 3, $nthreads, $total_ops) evals=1 samples=5
            else
                reset_all()
                t_field_complex = @belapsed bench_complex_low_contention!($complex_atomic_cas!, $local_field, 2, 3, $nthreads, $total_ops) evals=1 samples=5
                reset_all()
                t_cas_complex = @belapsed bench_complex_low_contention!($complex_cas!, $local_base, 2, 3, $nthreads, $total_ops) evals=1 samples=5
            end
            
            @printf("AtomicField:     %8.3f ms | Speed: %.1f ns/op\n", t_field_complex*1000, t_field_complex/total_ops*1e9)
            @printf("CAS loop:        %8.3f ms | Speed: %.1f ns/op | %.1f%% of field\n", 
                    t_cas_complex*1000, t_cas_complex/total_ops*1e9, t_cas_complex/t_field_complex*100)
            
            push!(results, (threads=nthreads, contention=contention, operation="x=x*2+3",
                            hw=NaN, field=t_field_complex, cas=t_cas_complex))
            
            # Verify results
            if contention == :high
                @assert base_hardware[] == total_ops "Hardware atomic failed: got $(base_hardware[]), expected $total_ops"
                @assert base_cas[] == total_ops "CAS loop failed: got $(base_cas[]), expected $total_ops"
                @assert getfield(field_atomic, :x) == total_ops "AtomicField failed: got $(getfield(field_atomic, :x)), expected $total_ops"
            else
                # For low contention, each array element should have ops_per_thread operations
                expected_per_thread = div(total_ops, nthreads)
                
                println("Debug - Low contention verification:")
                println("  Expected per thread: $expected_per_thread")
                
                for i in 1:nthreads
                    actual_base = local_base[i][]
                    actual_field = getfield(local_field[i], :x)
                    
                    println("  Array[$i]: base=$actual_base, field=$actual_field")
                    
                    @assert actual_base == expected_per_thread "Local base[$i] failed: got $actual_base, expected $expected_per_thread"
                    @assert actual_field == expected_per_thread "Local field[$i] failed: got $actual_field, expected $expected_per_thread"
                end
            end
        end
    end
    
    # Print summary table
    println("\n\n" * "="^60)
    println(" SUMMARY OF RESULTS")
    println("="^60)
    println("Threads | Contention | Operation    | Hardware | AtomicField | CAS Loop   | Field/HW | CAS/Field")
    
    for res in results
        field_hw_ratio = !isnan(res.hw) ? res.field/res.hw : NaN
        cas_field_ratio = res.cas/res.field
        
        @printf("%7d | %-10s | %-12s | %8.3f | %10.3f | %10.3f | %8.1f%% | %8.1f%%\n",
                res.threads, res.contention, res.operation,
                res.hw*1000, res.field*1000, res.cas*1000,
                field_hw_ratio*100, cas_field_ratio*100)
    end
    
    return results
end

# Run benchmarks
println("System threads: ", Threads.nthreads())
println("Starting comprehensive atomic operations benchmark...")
results = run_benchmark(total_ops=1_000_000, thread_counts=[1, 2, 4, 8])