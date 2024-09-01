using JSON3, DataFrames, CSV, Dates

# Model Points and Output file paths

modelpoints_file_path = joinpath(dirname(@__DIR__),"MP/")
output_file_path = joinpath(dirname(@__DIR__),"Output/")

# General Settings

general_settings_file = joinpath(dirname(@__DIR__),"input/general_settings.json")
general_settings_dict = JSON3.read(general_settings_file, Dict)

# General Settings - Products to run

selected_products = general_settings_dict["Products to run"]

# General Settings - Valuation Date: Date(YYYY, MM, DD)

valn_date = Date(general_settings_dict["Valuation Date"])

# General Settings - Projection Years

proj_yrs = general_settings_dict["Projection Year"]
proj_len = proj_yrs * 12

# General Settings - Capital Requirement Gross Up Factor

capreq_grossup_factor = general_settings_dict["Capital Requirement Gross Up Factor"]

# General Settings - Multiprocessing

num_workers = general_settings_dict["Number of Workers for Multiprocessing"]

# Run Settings

run_settings_file = joinpath(dirname(@__DIR__),"input/run_settings.json")
run_settings_arr = JSON3.read(run_settings_file, Vector{Dict})

run_settings_df = DataFrame(run_settings_arr)
selected_runs = filter(row -> row."Run Indicator" == "Yes", run_settings_df)[:,"Run Number"]
# Product Setup Files

prod_setup_file_path = joinpath(dirname(@__DIR__),"input/Products/")
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

# Input file for Table Listings

table_listing_file = joinpath(dirname(@__DIR__),"input/table_listings.json")
table_listing_dict = JSON3.read(table_listing_file, Dict)

# Input Tables

input_tables_dict = Dict()
for (table_name, fields) in table_listing_dict
    input_tables_dict[table_name] = CSV.read(joinpath(dirname(@__DIR__),"input/tables/", fields["Table Filename"]), DataFrame)
end

# Print Options

print_option_file = joinpath(dirname(@__DIR__),"input/print_option.json")
print_option_dict = JSON3.read(print_option_file, Vector{Dict})

print_option_df = DataFrame(print_option_dict)
print_agg_df = filter(row -> row.Print == "Yes" && row.Variable !== "date", print_option_df)