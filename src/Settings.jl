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

proj_yr = filter(row ->row."Option" == "Projection Year", general_settings_df)[1, "Value"]
proj_len = proj_yr * 12

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

# User Defined Formula

user_defined_formula_df = DataFrame(XLSX.readtable("$(input_file_path)settings.xlsx", "user_defined_formula"))

# Populate udt_Dict with UDF and formula variables - terminate if not all formula variables found in UDT

udt_Dict = Dict(
    # Product Feature => [UDT, UDF, List of variables in UDF]
    "Premium" => ["PREM02UDT", :(), []],
    "Commission" => ["COMM02UDT", :(), []],
    "Death_Benefit" => ["DB02UDT", :(), []],
    "Survival_Benefit" => ["SV02UDT", :(), []]
)

function get_formula_variables(formula::Expr, formula_variable, prodfeature)
    if length(formula.args) > 0
        for item in formula.args
            if typeof(item) == Expr
                get_formula_variables(item, formula_variable, prodfeature)
            elseif typeof(item) == Symbol 
                if !(item in [:+, :-, :*, :/, :^, :%, :min, :max, :.+, :.-, :.*, :./, :.^, :.%])
                    push!(formula_variable, item)
                end
            end
        end
    end
    return formula_variable
end

for (key, value) in udt_Dict
    prodfeature = key
    udt_name = value[1]
    formula_text = filter(row -> row."Product Feature" == prodfeature, user_defined_formula_df)[1, "User Defined Formula"]
    if formula_text === missing || isempty(formula_text)
        value[2], value[3] = nothing, []
    else
        formula = Meta.parse(formula_text)
        formula_variables = get_formula_variables(formula, [], prodfeature)
        fields_in_user_defined_table = names(DataFrame(XLSX.readtable("$(input_file_path)Tables.xlsx", udt_name)))
        validate_variables = all(item -> item in fields_in_user_defined_table, string.(formula_variables))    
        if validate_variables
            value[2], value[3] = formula, formula_variables    
        else 
            error("Variables validation failed for $prodfeature. Please check that the user defined table contains all the variables used in the user defined formula.")
        end
    end
end