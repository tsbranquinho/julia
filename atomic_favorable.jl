using BenchmarkTools
using Base.Threads

function atomic_add_bench(; total_ops=10^7)
    println("\nBenchmarking add: x += 1")

    base_atomic = Threads.Atomic{Int}(0)
    threads = nthreads()

    # Atomic add
    print("atomic_add!:        ")
    @btime begin
        @threads for i in 1:$threads
            for j in 1:$(div(total_ops, threads))
                Threads.atomic_add!($base_atomic, 1)
            end
        end
    end

    println("\nFinal values:")
    println("atomic_add!: ", base_atomic[])
end

println("System threads: ", nthreads())
atomic_add_bench()