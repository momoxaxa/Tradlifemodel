module ProductFeatures

include("Settings.jl")
include("Utils.jl")

export premium, death_benefit, surr_benefit, comm_rate

# Premium

function premium(input_tables_dict::Dict, mp_premium::Float64, pol_year::Array, issue_age::Integer, sum_assured::Float64, modal_cf_indicator::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.premium.mult
    if product_features_set.premium.table_type == "User Defined Table"
        formula = product_features_set.premium.UDF_expr
        variables = product_features_set.premium.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.premium.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    elseif product_features_set.premium.table_type == "Premium Rate Table"
        assumptions_array = read_excel_EA(input_tables_dict[product_features_set.premium.table], "Rate per 1000 SA", issue_age) .* sum_assured ./ 1000
    else
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.premium.table], "mult", pol_year, duration) .* mp_premium
    end

    return assumptions_array .* mult .* modal_cf_indicator
end

# Death Benefit

function death_benefit(input_tables_dict::Dict, pol_year::Array, sum_assured::Float64, duration::Array, product_features_set::Main.ProductFeatureSet)
    
    mult = product_features_set.death_ben.mult
    if product_features_set.death_ben.table_type == "User Defined Table"
        formula = product_features_set.death_ben.UDF_expr
        variables = product_features_set.death_ben.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.death_ben.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    else
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.death_ben.table], "mult", pol_year, duration) .* sum_assured
    end

    return assumptions_array .* mult
end

# Surrender Benefit

function surr_benefit(input_tables_dict::Dict, pol_year::Array, sum_assured::Float64, issue_age::Integer, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.surr_ben.mult
    if product_features_set.surr_ben.table_type == "User Defined Table"
        formula = product_features_set.surr_ben.UDF_expr
        variables = product_features_set.surr_ben.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.surr_ben.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    else
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.surr_ben.table], string(issue_age), pol_year, duration) .* sum_assured ./ 1000
    end
    return assumptions_array .* mult
end

# Commission

function comm_rate(input_tables_dict::Dict, pol_year::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.commission.mult
    if product_features_set.commission.table_type == "User Defined Table"
        formula = product_features_set.commission.UDF_expr
        variables = product_features_set.commission.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.commission.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    else
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.commission.table], "comm_rate", pol_year, duration)
    end
    return assumptions_array .* mult
end

end