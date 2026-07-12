using JSON3, DataFrames, CSV, Dates

# Model Points and Output file paths

modelpoints_file_path = joinpath(dirname(@__DIR__),"MP/")

# Root of all model output. Each execution writes into its own timestamped
# invocation folder underneath (const invocation_path, set in TradLifeModel.jl).
const output_root = joinpath(dirname(@__DIR__), "Output")

# General Settings

general_settings_file = joinpath(dirname(@__DIR__),"Input/general_settings.json")
general_settings_dict = JSON3.read(general_settings_file, Dict)

# General Settings - Products to run

selected_products = general_settings_dict["Products to run"]

# General Settings - Valuation Date: Date(YYYY, MM, DD)

valn_date = Date(general_settings_dict["Valuation Date"])

# General Settings - Projection Years

proj_yrs = 120 # no longer reading from general_settings_dict["Projection Year"]
proj_len = proj_yrs * 12

# General Settings - Capital Requirement Gross Up Factor

capreq_grossup_factor = general_settings_dict["Capital Requirement Gross Up Factor"]

# General Settings - Multithreading ("Yes"/"No"): run (run, product) tasks in parallel
# threads, or sequentially in a plain loop. Thread count itself is set at Julia startup
# via `julia -t N` / JULIA_NUM_THREADS.

use_threads = get(general_settings_dict, "Multithreading", "Yes") == "Yes"

# Run Settings

run_settings_file = joinpath(dirname(@__DIR__),"Input/run_settings.json")
run_settings_arr = JSON3.read(run_settings_file, Vector{Dict})

run_settings_df = DataFrame(run_settings_arr)
selected_runs = filter(row -> row."Run Indicator" == "Yes", run_settings_df)[:,"Run Number"]

# Product Setup Files

prod_setup_file_path = joinpath(dirname(@__DIR__),"Input/Products/")
prod_setup_arr = [
    let
        content = JSON3.read(joinpath(prod_setup_file_path, file), Dict)
        prod_name = replace(file, ".json" => "")
        content["Product Name"] = prod_name
        content
    end
    for file in readdir(prod_setup_file_path) if isfile(joinpath(prod_setup_file_path, file))
]

# Product Features and Assumptions Setup

assumption_set_df = DataFrame(prod_setup_arr)

# Table Listings (Scan from tables folder, with validation against table_type_defn.json)

include("TableMeta.jl")

table_type_defn_file = joinpath(dirname(@__DIR__), "Input/table_type_defn.json")
table_type_defn = JSON3.read(table_type_defn_file, Dict{String,Any})

tables_file_path = joinpath(dirname(@__DIR__), "Input/Tables/")
table_listing_dict = scan_table_listings(tables_file_path; valid_defn=table_type_defn)

# Input Tables (comment="#" skips the metadata header lines)

input_tables_dict = Dict()
for table_name in keys(table_listing_dict)
    input_tables_dict[table_name] = CSV.read(table_filepath(tables_file_path, table_name), DataFrame; comment="#")
end

# Print Options

print_option_file = joinpath(dirname(@__DIR__),"Input/print_option.json")
print_option_dict = JSON3.read(print_option_file, Vector{Dict})

print_option_df = DataFrame(print_option_dict)
print_agg_df = filter(row -> row.Print == "Yes" && row.Variable !== "date", print_option_df)