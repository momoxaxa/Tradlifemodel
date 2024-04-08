"""

death_benefit(exceldata::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array)
surr_benefit(exceldata::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array)
comm_rate(assumption_dict::Dict, pol_year::Array, duration::Array)

"""

# Product Features
function death_benefit(exceldata::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array)
    death_ben_ind = read_excel_ind(exceldata["prod_feature"], "death_ben_ind")
    if death_ben_ind == "Mult by Duration"
        assumptions_array = read_excel_PY(exceldata["death_ben"], "mult", pol_year, duration)
        return init_sum_assured .* assumptions_array
    end
end

function surr_benefit(exceldata::Dict, init_sum_assured::Float64, pol_year::Array, duration::Array)
    surr_ben_ind = read_excel_ind(exceldata["prod_feature"], "surr_ben_ind")
    if surr_ben_ind == "No Surrender Benefit"
        return zeros(Float64, proj_len)
    elseif surr_ben_ind == "Table by Duration"
        assumptions_array = read_excel_PY(exceldata["surr_value"], "surr_val_rate", pol_year, duration)
        return init_sum_assured ./1000 .* assumptions_array
    end
end

function comm_rate(assumption_dict::Dict, pol_year::Array, duration::Array)
    assumptions_array = read_excel_PY(assumption_dict["commission"], "comm_rate", pol_year, duration)  
    return assumptions_array
end
