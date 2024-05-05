module ProductFeatures

"""

death_benefit(input_tables_dict::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array, product_features_set::ProductFeatureSet)
surr_benefit(input_tables_dict::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array, product_features_set::ProductFeatureSet)
comm_rate(input_tables_dict::Dict, pol_year::Array, duration::Array, product_features_set::ProductFeatureSet)

"""

include("Settings.jl")
include("Utils.jl")

export death_benefit, surr_benefit, comm_rate

# Death Benefit

function death_benefit(input_tables_dict::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    
    mult = product_features_set.death_ben.mult
    if product_features_set.death_ben.table_type == "User Defined Table"
        formula = product_features_set.death_ben.UDF_expr
        variables = product_features_set.death_ben.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.death_ben.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    else
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.death_ben.table], "mult", pol_year, duration) .* init_sum_assured
    end

    return assumptions_array .* mult
end

# Surrender Benefit

function surr_benefit(input_tables_dict::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.surr_ben.mult
    assumptions_array = read_excel_PY(input_tables_dict[product_features_set.surr_ben.table], "surr_val_rate", pol_year, duration)
    return init_sum_assured ./1000 .* assumptions_array .* mult
end

# Commission

function comm_rate(input_tables_dict::Dict, pol_year::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.commission.mult
    assumptions_array = read_excel_PY(input_tables_dict[product_features_set.commission.table], "comm_rate", pol_year, duration)  
    return assumptions_array .* mult
end

end