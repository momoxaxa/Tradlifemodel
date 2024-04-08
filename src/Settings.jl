using Dates, XLSX, DataFrames

# File paths

settings_file_path = joinpath(dirname(@__DIR__), "Settings\\")
input_file_path = joinpath(dirname(@__DIR__), "Input\\")
modelpoints_file_path = joinpath(dirname(@__DIR__), "MP\\")
output_file_path = joinpath(dirname(@__DIR__), "Output\\")

# Products for the Runs

selected_products = ["prod01", "prod02"]

# Valuation Date: Date(YYYY, MM, DD)

valn_date = Date(2023, 12, 31)

# Projection Years

proj_yr = 120
proj_len = proj_yr * 12

capreq_grossup_factor = 0.3

# Print Options

print_option_df = DataFrame(XLSX.readtable("$(settings_file_path)settings.xlsx", "print_option"))
print_agg_df = filter(row -> row.Print == "Yes" && row.Variable !== "date", print_option_df)

# Run Settings

run_settings_df = DataFrame(XLSX.readtable("$(settings_file_path)settings.xlsx", "run_settings"))
run_indicator_yes = vec(Matrix(filter(row ->row."Run Number" == "Run Indicator", run_settings_df) .== "Yes"))
selected_runs =  names(run_settings_df)[run_indicator_yes]