module ProductFeatures

include("Settings.jl")
include("Utils.jl")

export premium, death_benefit, surr_benefit, comm_perc

# Premium

function premium(input_tables_dict::Dict, mp::Main.ModelPoint, pol_year::Array, modal_cf_indicator::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.premium.mult
    if product_features_set.premium.table_type == "User Defined Table"
        formula = product_features_set.premium.UDF_expr
        variables = product_features_set.premium.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.premium.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    elseif product_features_set.premium.table_type == "Rate per 1000 SA by Age/Pol Term"
        assumptions_array = read_excel_EA(input_tables_dict[product_features_set.premium.table], string(mp.pol_term), mp.issue_age) .* mp.sum_assured ./ 1000
    elseif product_features_set.premium.table_type == "Mult to MP Premium by Duration"
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.premium.table], "mult", pol_year, duration) .* mp.premium
    elseif product_features_set.premium.table_type == "Rate per 1000 SA by Issue Age/Pol Term/Prem Term"
        assumptions_array = read_excel_EA_MI(input_tables_dict[product_features_set.premium.table], mp.pol_term, mp.prem_term, "Value", mp.issue_age) .* mp.sum_assured ./ 1000
    end

    return assumptions_array .* mult .* modal_cf_indicator
end

# Death Benefit

function death_benefit(input_tables_dict::Dict, mp::Main.ModelPoint, pol_year::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    
    mult = product_features_set.death_ben.mult
    if product_features_set.death_ben.table_type == "User Defined Table"
        formula = product_features_set.death_ben.UDF_expr
        variables = product_features_set.death_ben.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.death_ben.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    elseif product_features_set.death_ben.table_type == "Mult to MP SA by Duration"
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.death_ben.table], "mult", pol_year, duration) .* mp.sum_assured
    end

    return assumptions_array .* mult
end

# Surrender Benefit

function surr_benefit(input_tables_dict::Dict, mp::Main.ModelPoint, pol_year::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.surr_ben.mult
    if product_features_set.surr_ben.table_type == "User Defined Table"
        formula = product_features_set.surr_ben.UDF_expr
        variables = product_features_set.surr_ben.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.surr_ben.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    elseif product_features_set.surr_ben.table_type == "Rate per 1000 SA by Year/Age"
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.surr_ben.table], string(mp.issue_age), pol_year, duration) .* mp.sum_assured ./ 1000
    elseif product_features_set.surr_ben.table_type == "Rate per 1000 SA by Pol Year/Issue Age/Prem Term"
        assumptions_array = read_excel_PY_MI(input_tables_dict[product_features_set.surr_ben.table], mp.issue_age, mp.prem_term, "Value", pol_year) .* mp.sum_assured ./ 1000
    end
    return assumptions_array .* mult
end

# Commission

function comm_perc(input_tables_dict::Dict, mp::Main.ModelPoint, pol_year::Array, duration::Array, product_features_set::Main.ProductFeatureSet)
    mult = product_features_set.commission.mult
    if product_features_set.commission.table_type == "User Defined Table"
        formula = product_features_set.commission.UDF_expr
        variables = product_features_set.commission.UDF_vars
        for var in variables
            setproperty!(ProductFeatures, var, read_excel_PY(input_tables_dict[product_features_set.commission.table], string(var), pol_year, duration))
        end
        assumptions_array = eval(formula)
    elseif product_features_set.commission.table_type == "Perc by Pol Year/Pol Term"
        assumptions_array = read_excel_PY(input_tables_dict[product_features_set.commission.table], string(mp.pol_term), pol_year, duration)
    elseif product_features_set.commission.table_type == "Perc by Pol Year/Pol Term/Prem Term"
        assumptions_array = read_excel_PY_MI(input_tables_dict[product_features_set.commission.table], mp.pol_term, mp.prem_term, "Value", pol_year)
    end
    return assumptions_array .* mult
end

end