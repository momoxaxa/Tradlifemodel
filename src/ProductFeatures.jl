# Premium

function premium(input_tables_dict::Dict, mp::ModelPoint, pol_year, modal_cf_indicator, duration, product_features_set::ProductFeatureSet)
    mult = product_features_set.premium.mult
    if product_features_set.premium.table_type == "User Defined Table"
        formula = product_features_set.premium.UDF_expr
        variables = product_features_set.premium.UDF_vars
        var_dict  = Dict{Symbol, Any}(
            var => read_table_PY(input_tables_dict[product_features_set.premium.table],
                                 string(var), pol_year, duration)
            for var in variables
        )
        assumptions_array = eval_udf(formula, var_dict)
    elseif product_features_set.premium.table_type == "Rate per 1000 SA by Age/Pol Term"
        assumptions_array = read_table_EA(input_tables_dict[product_features_set.premium.table], string(mp.pol_term), mp.issue_age) .* mp.sum_assured ./ 1000
    elseif product_features_set.premium.table_type == "Mult to MP Premium by Duration"
        assumptions_array = read_table_PY(input_tables_dict[product_features_set.premium.table], "mult", pol_year, duration) .* mp.premium
    end

    return assumptions_array .* mult .* modal_cf_indicator
end

# Death Benefit

function death_benefit(input_tables_dict::Dict, mp::ModelPoint, pol_year, duration, product_features_set::ProductFeatureSet)
    
    mult = product_features_set.death_ben.mult
    if product_features_set.death_ben.table_type == "User Defined Table"
        formula = product_features_set.death_ben.UDF_expr
        variables = product_features_set.death_ben.UDF_vars
        var_dict  = Dict{Symbol, Any}(
            var => read_table_PY(input_tables_dict[product_features_set.death_ben.table],
                                 string(var), pol_year, duration)
            for var in variables
        )
        assumptions_array = eval_udf(formula, var_dict)
    elseif product_features_set.death_ben.table_type == "Mult to MP SA by Duration"
        assumptions_array = read_table_PY(input_tables_dict[product_features_set.death_ben.table], "mult", pol_year, duration) .* mp.sum_assured
    end

    return assumptions_array .* mult
end

# Surrender Benefit

function surr_benefit(input_tables_dict::Dict, mp::ModelPoint, pol_year, duration, product_features_set::ProductFeatureSet)
    mult = product_features_set.surr_ben.mult
    if product_features_set.surr_ben.table_type == "User Defined Table"
        formula = product_features_set.surr_ben.UDF_expr
        variables = product_features_set.surr_ben.UDF_vars
        var_dict  = Dict{Symbol, Any}(
            var => read_table_PY(input_tables_dict[product_features_set.surr_ben.table],
                                 string(var), pol_year, duration)
            for var in variables
        )
        assumptions_array = eval_udf(formula, var_dict)
    elseif product_features_set.surr_ben.table_type == "Rate per 1000 SA by Year/Age"
        assumptions_array = read_table_PY(input_tables_dict[product_features_set.surr_ben.table], string(mp.issue_age), pol_year, duration) .* mp.sum_assured ./ 1000
    end
    return assumptions_array .* mult
end

# Commission

function comm_perc(input_tables_dict::Dict, mp::ModelPoint, pol_year, duration, product_features_set::ProductFeatureSet)
    mult = product_features_set.commission.mult
    if product_features_set.commission.table_type == "User Defined Table"
        formula = product_features_set.commission.UDF_expr
        variables = product_features_set.commission.UDF_vars
        var_dict  = Dict{Symbol, Any}(
            var => read_table_PY(input_tables_dict[product_features_set.commission.table],
                                 string(var), pol_year, duration)
            for var in variables
        )
        assumptions_array = eval_udf(formula, var_dict)
    elseif product_features_set.commission.table_type == "Perc by Pol Year/Pol Term"
        assumptions_array = read_table_PY(input_tables_dict[product_features_set.commission.table], string(mp.pol_term), pol_year, duration)
    end
    return assumptions_array .* mult
end