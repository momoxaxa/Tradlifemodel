using JSON3, DataFrames, CSV, Dates

# Model Points and Output file paths

const modelpoints_file_path = joinpath(dirname(@__DIR__),"MP/")

# Root of all model output. Each execution writes into its own timestamped
# invocation folder underneath (const invocation_path, set in TradLifeModel.jl).
const output_root = joinpath(dirname(@__DIR__), "Output")

# General Settings

const general_settings_file = joinpath(dirname(@__DIR__),"Input/general_settings.json")
const general_settings_dict = JSON3.read(general_settings_file, Dict)

# General Settings - Products to run

const selected_products = general_settings_dict["Products to run"]

# General Settings - Valuation Date: Date(YYYY, MM, DD)

const valn_date = Date(general_settings_dict["Valuation Date"])

# General Settings - Projection Years

const proj_yrs = 120 # no longer reading from general_settings_dict["Projection Year"]
const proj_len = proj_yrs * 12

# General Settings - Capital Requirement Gross Up Factor

const capreq_grossup_factor = general_settings_dict["Capital Requirement Gross Up Factor"]

# General Settings - Multithreading ("Yes"/"No"): run (run, product) tasks in parallel
# threads, or sequentially in a plain loop. Thread count itself is set at Julia startup
# via `julia -t N` / JULIA_NUM_THREADS.

const use_threads = get(general_settings_dict, "Multithreading", "Yes") == "Yes"

# Run Settings

const run_settings_file = joinpath(dirname(@__DIR__),"Input/run_settings.json")
const run_settings_arr = JSON3.read(run_settings_file, Vector{Dict})

const run_settings_df = DataFrame(run_settings_arr)
const selected_runs = filter(row -> row."Run Indicator" == "Yes", run_settings_df)[:,"Run Number"]

# Product Setup Files

const prod_setup_file_path = joinpath(dirname(@__DIR__),"Input/Products/")
const prod_setup_arr = [
    let
        content = JSON3.read(joinpath(prod_setup_file_path, file), Dict)
        prod_name = replace(file, ".json" => "")
        content["Product Name"] = prod_name
        content
    end
    for file in readdir(prod_setup_file_path) if isfile(joinpath(prod_setup_file_path, file))
]

# Product Features and Assumptions Setup

const assumption_set_df = DataFrame(prod_setup_arr)

# Table Listings (Scan from tables folder, with validation against table_type_defn.json)

include("TableMeta.jl")

const table_type_defn_file = joinpath(dirname(@__DIR__), "Input/table_type_defn.json")
const table_type_defn = JSON3.read(table_type_defn_file, Dict{String,Any})

const tables_file_path = joinpath(dirname(@__DIR__), "Input/Tables/")
const table_listing_dict = scan_table_listings(tables_file_path; valid_defn=table_type_defn)

# Input Tables (comment="#" skips the metadata header lines)

const input_tables_dict = Dict()
for table_name in keys(table_listing_dict)
    input_tables_dict[table_name] = CSV.read(table_filepath(tables_file_path, table_name), DataFrame; comment="#")
end

# Print Options

const print_option_file = joinpath(dirname(@__DIR__),"Input/print_option.json")
const print_option_dict = JSON3.read(print_option_file, Vector{Dict})

const print_option_df = DataFrame(print_option_dict)
const print_agg_df = filter(row -> row.Print == "Yes" && row.Variable !== "date", print_option_df)
