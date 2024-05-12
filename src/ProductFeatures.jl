module ProductFeatures

include("Settings.jl")
include("Utils.jl")

export premium, sum_assured, death_benefit_factor, surr_benefit_factor, comm_rate

# Premium

function premium(input_tables_dict::Dict, premium::Float64, pol_year::Array, modal_cf_indicator::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.premium.mult
    if product_features_set.premium.table_type == "User Defined Table"
        formula = product_features_set.premium.UDF_expr
        variables = product_features_set.premium.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.premium.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    else
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.premium.table], "mult", pol_year, duration) .* premium
    end

    return assumptions_array .* mult .* modal_cf_indicator
end

# Sum Assured

function sum_assured(input_tables_dict::Dict, sum_assured::Float64, pol_year::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.sum_assured.mult
    if product_features_set.sum_assured.table_type == "User Defined Table"
        formula = product_features_set.sum_assured.UDF_expr
        variables = product_features_set.sum_assured.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.sum_assured.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    else
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.sum_assured.table], "mult", pol_year, duration) .* sum_assured
    end

    return assumptions_array .* mult
end

# Death Benefit

function death_benefit_factor(input_tables_dict::Dict, pol_year::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    
    mult = product_features_set.death_ben.mult
    if product_features_set.death_ben.table_type == "User Defined Table"
        formula = product_features_set.death_ben.UDF_expr
        variables = product_features_set.death_ben.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.death_ben.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    else
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.death_ben.table], "mult", pol_year, duration)
    end

    return assumptions_array .* mult
end

# Surrender Benefit

function surr_benefit_factor(input_tables_dict::Dict, pol_year::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.surr_ben.mult
    assumptions_array = read_excel_PY(input_tables_dict[product_features_set.surr_ben.table], "surr_val_rate", pol_year, duration)
    return assumptions_array .* mult
end

# Commission

function comm_rate(input_tables_dict::Dict, pol_year::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.commission.mult
    assumptions_array = read_excel_PY(input_tables_dict[product_features_set.commission.table], "comm_rate", pol_year, duration)  
    return assumptions_array .* mult
end

end