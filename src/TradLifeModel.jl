using CSV, DataFrames
using Dates, MortalityTables, OffsetArrays

include("Settings.jl")
include("Utils.jl")
include("DataStruct.jl")
include("ProductFeatures.jl")
include("Assumptions.jl")
include("Print.jl")
include("Projection.jl")

const start = now()

println("Julia started with $(Threads.nthreads()) thread(s). Multithreading setting: $(use_threads ? "Yes" : "No").")

# Each model execution (invocation) writes into its own timestamped folder

const invocation_id = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
const invocation_path = joinpath(output_root, invocation_id)
mkpath(invocation_path)
println("Output folder: $invocation_path")

# Validate product table configuration; exclude products with missing tables

const valid_products = String[]
const exclusion_msgs = String[]
for prod_code in selected_products
    msgs = missing_tables_for_product(prod_code)
    if isempty(msgs)
        push!(valid_products, prod_code)
    else
        msg = "Product $prod_code EXCLUDED from the run(s) — missing tables:\n  " * join(msgs, "\n  ")
        push!(exclusion_msgs, msg)
        @warn msg
    end
end
isempty(valid_products) && @warn "No runnable products — all selected products were excluded (missing tables)."

# Every selected run gets its output folder; one run_log.txt at the invocation
# root records validation, per-product completions, and total time.

for curr_run in selected_runs
    mkpath(joinpath(invocation_path, curr_run))
end

const log_lines = String[
    "$(now())  Runs $(join(selected_runs, ", ")): $(length(valid_products)) of $(length(selected_products)) selected product(s) runnable.",
]
append!(log_lines, exclusion_msgs)
const run_log_path = joinpath(invocation_path, "run_log.txt")
write(run_log_path, join(log_lines, "\n") * "\n")

# Append a line to the run log. Tasks call this concurrently, so appends are
# serialized behind a lock.
const run_log_lock = ReentrantLock()
function log_line(msg::AbstractString)
    println(msg)                      # console / RunMonitor sees it live
    lock(run_log_lock) do
        open(run_log_path, "a") do io
            println(io, msg)
        end
    end
end

# Tracks which (run, product) pairs failed during run_product, so they can be
# logged and excluded from the combined results, without failing the whole
# invocation. Guarded by the same lock since tasks mutate it concurrently.
const failed_products = Dict{String, Set{String}}(curr_run => Set{String}() for curr_run in selected_runs)

function run_product_safe(prod_code::String, runset::RunSet)
    try
        run_product(prod_code, runset)
        log_line("$(runset.RunNumber) $prod_code completed at $(now())")
    catch err
        io = IOBuffer()
        showerror(io, err, catch_backtrace())
        lock(run_log_lock) do
            push!(failed_products[runset.RunNumber], prod_code)
        end
        log_line("$(runset.RunNumber) $prod_code FAILED at $(now()) — excluded from results:\n$(String(take!(io)))")
    end
end

if isempty(valid_products)

    # Nothing to do — folders and logs above already record why.

elseif use_threads

    # One task per (run, product) pair, dynamically scheduled across threads

    @sync for curr_run in selected_runs

        runset = RunSet(run_settings_df, curr_run)

        for prod_code in valid_products
            Threads.@spawn begin
                print("[thread $(Threads.threadid()) of $(Threads.nthreads())] starting $(runset.RunNumber) $prod_code\n")
                run_product_safe(prod_code, runset)
            end
        end

    end

else

    # Sequential: plain loops, deterministic order (easier debugging)

    for curr_run in selected_runs

        runset = RunSet(run_settings_df, curr_run)

        for prod_code in valid_products
            run_product_safe(prod_code, runset)
        end

        println("$curr_run completed at $(now())")

    end

end

# Combine and save results for all products to CSV file. Products that failed
# (per run_product_safe above) are excluded from the combined result.
if !isempty(valid_products)
    for curr_run in selected_runs

        run_valid_products = filter(p -> !(p in failed_products[curr_run]), valid_products)

        if isempty(run_valid_products)
            log_line("$curr_run: no successful products — result_allproducts.csv skipped")
            continue
        end

        resultallproducts = DataFrame()

        for (i, prod_code) in enumerate(run_valid_products)
            if i == 1
                resultallproducts = CSV.read(joinpath(invocation_path, "$curr_run", "result_$prod_code.csv"), DataFrame)
            else
                resultallproducts[:, Not(:date)] .+= CSV.read(joinpath(invocation_path, "$curr_run", "result_$prod_code.csv"), DataFrame)[:, Not(:date)]
            end
        end

        write_rounded_csv(joinpath(invocation_path, "$curr_run", "result_allproducts.csv"), resultallproducts)

    end
end

const elapsed = Dates.value(now() - start) / 1000
log_line("All runs completed in $(elapsed) seconds")