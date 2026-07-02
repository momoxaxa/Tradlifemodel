using CSV, DataFrames
using Dates, MortalityTables, OffsetArrays

include("Settings.jl")
include("Utils.jl")
include("DataStruct.jl")
include("ProductFeatures.jl")
include("Assumptions.jl")
include("Print.jl")
include("Projection.jl")

start = now()

println("Julia started with $(Threads.nthreads()) thread(s). Multithreading setting: $(use_threads ? "Yes" : "No").")

if use_threads

    # One task per (run, product) pair, dynamically scheduled across threads

    @sync for curr_run in selected_runs

        mkpath("$output_file_path$curr_run")
        runset = RunSet(run_settings_df, curr_run)

        for prod_code in selected_products
            Threads.@spawn begin
                print("[thread $(Threads.threadid()) of $(Threads.nthreads())] starting $(runset.RunNumber) $prod_code\n")
                run_product(prod_code, runset)
            end
        end

    end

else

    # Sequential: plain loops, deterministic order (easier debugging)

    for curr_run in selected_runs

        mkpath("$output_file_path$curr_run")
        runset = RunSet(run_settings_df, curr_run)

        for prod_code in selected_products
            run_product(prod_code, runset)
        end

        println("$curr_run completed at $(now())")

    end

end

# Combine and save results for all products to CSV file
for curr_run in selected_runs

    resultallproducts = DataFrame()

    for (i, prod_code) in enumerate(selected_products)
        if i == 1
            resultallproducts = CSV.read(joinpath(output_file_path, "$curr_run", "result_$prod_code.csv"), DataFrame)
        else
            resultallproducts[:, Not(:date)] .+= CSV.read(joinpath(output_file_path, "$curr_run", "result_$prod_code.csv"), DataFrame)[:, Not(:date)]
        end
    end

    CSV.write(joinpath(output_file_path, "$curr_run", "result_allproducts.csv"), resultallproducts)

end

elapsed = Dates.value(now() - start) / 1000
println("All runs completed in $(elapsed) seconds")