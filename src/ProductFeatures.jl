module ProductFeatures

include("Settings.jl")
include("UserDefinedFormula.jl")
include("DataStruct.jl")
include("Utils.jl")

"""

death_benefit(input_tables_dict::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array, product_features_set::ProductFeatureSet)
surr_benefit(input_tables_dict::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array, product_features_set::ProductFeatureSet)
comm_rate(input_tables_dict::Dict, pol_year::Array, duration::Array, product_features_set::ProductFeatureSet)

"""

export death_benefit, surr_benefit, comm_rate

# Product Features
function death_benefit(input_tables_dict::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array, product_features_set::ProductFeatureSet)
    mult = product_features_set.death_ben.mult
    # if 1==1 # to update to if table type is UDT
        formula_text = filter(row -> row."Product Feature" == "Death_Benefit", user_defined_formula_df)[1, "User Defined Formula"]
        formula = Meta.parse(formula_text)
        arguments = get_formula_variables(formula, [], "Death_Benefit")
        for arg in arguments
            setproperty!(Main, arg, read_excel_PY(input_tables_dict[product_features_set.death_ben.table], "multiple", pol_year, duration))
        end
        assumptions_array = eval(formula)
    # else
    #     assumptions_array = read_excel_PY(input_tables_dict[product_features_set.death_ben.table], "mult", pol_year, duration)
    # end
    return init_sum_assured .* assumptions_array .* mult
end

function surr_benefit(input_tables_dict::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array, product_features_set::ProductFeatureSet)
    mult = product_features_set.surr_ben.mult
    assumptions_array = read_excel_PY(input_tables_dict[product_features_set.surr_ben.table], "surr_val_rate", pol_year, duration)
    return init_sum_assured ./1000 .* assumptions_array .* mult
end

function comm_rate(input_tables_dict::Dict, pol_year::Array, duration::Array, product_features_set::ProductFeatureSet)
    mult = product_features_set.commission.mult
    assumptions_array = read_excel_PY(input_tables_dict[product_features_set.commission.table], "comm_rate", pol_year, duration)  
    return assumptions_array .* mult
end

end