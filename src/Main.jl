using Distributed
using XLSX

include("Settings.jl")

# Multiprocessing
addprocs(num_workers)

@everywhere begin
    using CSV, DataFrames
    using XLSX, Dates

    start = now()

    include("Settings.jl")
    include("DataStruct.jl")
    include("Utils.jl")
    include("ProductFeatures.jl")
    include("Assumptions.jl")
    include("Projection.jl")
    include("Print.jl")

end

@sync @distributed for curr_run in selected_runs

    mkpath("$output_file_path$curr_run")
    runset = RunSet(run_settings_df, curr_run)

    @sync @distributed for prod_code in selected_products
        run_product(prod_code, runset)
    end

    println("$curr_run completed.")

    # Combine and save results for all products to CSV file
    for (i, prod_code) in enumerate(selected_products)
        if i == 1
            global resultallproducts = CSV.read("$output_file_path$curr_run\\result_$prod_code.csv", DataFrame)
        else
            resultallproducts[:, Not(:date)] .+= CSV.read("$output_file_path$curr_run\\result_$prod_code.csv", DataFrame)[:, Not(:date)]
        end
    end

    CSV.write("$output_file_path$curr_run\\result_allproducts.csv", resultallproducts)

end