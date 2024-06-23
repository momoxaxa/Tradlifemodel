using XLSX, DataFrames

# File paths

input_file_path = joinpath(dirname(@__DIR__), "Input\\")
modelpoints_file_path = joinpath(dirname(@__DIR__), "MP\\")
output_file_path = joinpath(dirname(@__DIR__), "Output\\")

# Read General Setting from Excel Data

general_settings_df = DataFrame(XLSX.readtable("$(input_file_path)settings.xlsx", "general_settings"))

# Products to run

filter_products_available_to_run = startswith.(general_settings_df.Option, "Product to run")
products_available_to_run = general_settings_df[filter_products_available_to_run, :]
selected_products = filter(row ->row."Value" !== missing, products_available_to_run)[:,:Value]

# Valuation Date: Date(YYYY, MM, DD)

valn_date = filter(row ->row."Option" == "Valuation Date", general_settings_df)[1, "Value"]

# Projection Years

proj_yrs = filter(row ->row."Option" == "Projection Year", general_settings_df)[1, "Value"]
proj_len = proj_yrs * 12

# Capital Requirement Gross Up Factor

capreq_grossup_factor = filter(row ->row."Option" == "Capital Requirement Gross Up Factor", general_settings_df)[1, "Value"]

# Multiprocessing

num_workers = filter(row ->row."Option" == "Number of Workers for Multiprocessing", general_settings_df)[1, "Value"]

# Print Options

print_option_df = DataFrame(XLSX.readtable("$(input_file_path)settings.xlsx", "print_option"))
print_agg_df = filter(row -> row.Print == "Yes" && row.Variable !== "date", print_option_df)

# Run Settings

run_settings_df = DataFrame(XLSX.readtable("$(input_file_path)settings.xlsx", "run_settings"))
run_indicator_is_yes = vec(Matrix(filter(row ->row."Run Number" == "Run Indicator", run_settings_df) .== "Yes"))
selected_runs =  names(run_settings_df)[run_indicator_is_yes]

# Product Features and Assumptions Setup

assumption_set_df = DataFrame(XLSX.readtable("$(input_file_path)Settings.xlsx", "product_setup"))

# Input Tables

input_tables_dict = Dict()
xf = XLSX.readxlsx("$(input_file_path)Tables.xlsx")
for sheet in XLSX.sheetnames(xf)
    input_tables_dict[sheet] = DataFrame(XLSX.readtable("$(input_file_path)Tables.xlsx", sheet))
end