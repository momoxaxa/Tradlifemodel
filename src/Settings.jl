using JSON, DataFrames, CSV, Dates

# Model Points and Output file paths

modelpoints_file_path = "MP/"
output_file_path = "Output/"

# General Settings

general_settings_file = "input/general_settings.json"
general_settings_dict = JSON.parsefile(general_settings_file; dicttype=Dict)

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

run_settings_file = "input/run_settings.json"
run_settings_arr = JSON.parsefile(run_settings_file; dicttype=Dict)

run_settings_df = DataFrame(run_settings_arr)
selected_runs = filter(row -> row."Run Indicator" == "Yes", run_settings_df)[:,"Run Number"]

# Product Setup Files

prod_setup_file_path = "input/Products/"
prod_setup_arr = [
    let
        content = JSON.parsefile(joinpath(prod_setup_file_path, file), dicttype=Dict)
        prod_name = replace(file, ".json" => "")
        content["Product Name"] = prod_name
        content
    end
    for file in readdir(prod_setup_file_path) if isfile(joinpath(prod_setup_file_path, file))
]

# Product Features and Assumptions Setup

assumption_set_df = DataFrame(prod_setup_arr)

# Input file for Table Listings

table_listing_file = "input/table_listings.json"
table_listing_dict = JSON.parsefile(table_listing_file, dicttype=Dict)

# Input Tables

input_tables_dict = Dict()
for (table_name, fields) in table_listing_dict
    input_tables_dict[table_name] = CSV.read(joinpath("input/tables/", fields["Table Filename"]), DataFrame)
end

# Print Options

print_option_file = "input/print_option.json"
print_option_dict = JSON.parsefile(print_option_file; dicttype=Dict)

print_option_df = DataFrame(print_option_dict)
print_agg_df = filter(row -> row.Print == "Yes" && row.Variable !== "date", print_option_df)
