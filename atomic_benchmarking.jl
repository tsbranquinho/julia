using Base.Threads: @threads, Atomic, atomic_add!, atomic_cas!, nthreads
using Statistics
using Printf

# Define the struct at the top level
mutable struct AtomicField
    @atomic x::Int64
end

# Workaround for broken @atomic in pre-fix version
function cas_atomic_add!(x::Atomic{T}, val::T) where T
    while true
        old = x[]
        new = old + val
        prev = atomic_cas!(x, old, new)
        if prev == old
            return new
        end
    end
end

function run_benchmarks()
    # Benchmark parameters
    n_ops = 10_000_000
    n_contended = 1_000_000
    n_trials = 10

    println("System Threads: ", nthreads())
    println("Operations per test: ", n_ops)
    println("Contended operations: ", n_contended)
    println("Trials: ", n_trials)
    println("\nBenchmarking atomic operations...")

    # 1. Uncontended built-in atomic
    uncontended_times = Float64[]
    for _ in 1:n_trials
        a = Atomic{Int}(0)
        t = @elapsed for i in 1:n_ops
            atomic_add!(a, 1)
        end
        push!(uncontended_times, t)
        @assert a[] == n_ops
    end

    # 2. Contended built-in atomic
    contended_times = Float64[]
    for _ in 1:n_trials
        a = Atomic{Int}(0)
        t = @elapsed @threads for _ in 1:nthreads()
            for i in 1:n_contended
                atomic_add!(a, 1)
            end
        end
        push!(contended_times, t)
        @assert a[] == nthreads() * n_contended
    end

    # 3. Custom struct atomic
    custom_times = Float64[]
    for _ in 1:n_trials
        af = AtomicField(0)
        t = @elapsed @threads for _ in 1:nthreads()
            for i in 1:n_contended
                @atomic af.x += 1
            end
        end
        push!(custom_times, t)
        @assert af.x == nthreads() * n_contended
    end

    # 4. CAS fallback performance
    cas_times = Float64[]
    for _ in 1:n_trials
        a = Atomic{Int}(0)
        t = @elapsed @threads for _ in 1:nthreads()
            for i in 1:n_contended
                cas_atomic_add!(a, 1)
            end
        end
        push!(cas_times, t)
        @assert a[] == nthreads() * n_contended
    end

    # Calculate results
    results = (
        uncontended = (mean(uncontended_times), std(uncontended_times)),
        contended = (mean(contended_times), std(contended_times)),
        custom = (mean(custom_times), std(custom_times)),
        cas = (mean(cas_times), std(cas_times)),
    )

    return results
end

function print_results(results, prefix)
    println("\n", prefix, " Results:")
    @printf("Uncontended: %.3f ± %.3f ms\n", results.uncontended[1]*1000, results.uncontended[2]*1000)
    @printf("Contended:   %.3f ± %.3f ms\n", results.contended[1]*1000, results.contended[2]*1000)
    @printf("Custom:      %.3f ± %.3f ms\n", results.custom[1]*1000, results.custom[2]*1000)
    @printf("CAS:         %.3f ± %.3f ms\n", results.cas[1]*1000, results.cas[2]*1000)

end

# Run benchmarks before and after
println("Running pre-fix benchmarks...")
pre_fix_results = run_benchmarks()
print_results(pre_fix_results, "Before")

println("\n====================================")
println("After applying the fix, restart Julia")
println("and run the same benchmark again")
println("====================================")
