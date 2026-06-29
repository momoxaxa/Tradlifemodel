#=
ZerobasedIndex!(array::Array)
read_table_ind(table_data::DataFrame, datatype::String, table_header::String="Value")  
read_table_PY(table_data::DataFrame, table_header::String, pol_year::Array, duration::Array, distributionoption::String="None")
read_table_PRJY_CY(table_data::DataFrame, table_header::String, year::Array)
read_table_PY_MI(table_data::DataFrame, index_1, index_2, table_header::String, pol_year::Array)
read_table_AA(table_data::DataFrame, table_header::String, att_age::Array)
read_table_EA(table_data::DataFrame, table_header::String, issue_age::Integer)
read_table_EA_MI(table_data::DataFrame, index_1, index_2, table_header::String, issue_age::Integer)
rev_cumsum_disc(cf, disc_rate, cf_timing="EOP")
=#

using OffsetArrays, DataFrames
using OffsetArrays: Origin

# Convert Array from 1-based index to 0-based index
function ZerobasedIndex!(array)
    return OffsetArray(array, 0:proj_len)
end

# Read assumptions from table - Indicators
function read_table_ind(table_data::DataFrame, rowlabel::Union{String, Nothing}=nothing, columnheader::String="Value")   
    if rowlabel === nothing
        table_data[1, columnheader][1]
    else
        filter(row -> row[1] == rowlabel, table_data)[1, columnheader] |> ZerobasedIndex!
    end
end

# Read assumptions from table - Policy Year
function read_table_PY(table_data::DataFrame, columnheader::String, pol_year, duration, distributionoption::String="None")
    assumptions_array = OffsetArray([],Origin(0))
    index = 1
    if distributionoption in ("None", "EvenlySpreadOut")
        for t in 0:proj_len
            index = findfirst(table_data[:, 1] .== pol_year[t])
            if index !== nothing
                append!(assumptions_array, table_data[index, columnheader])
            else
                append!(assumptions_array, 0.0) 
            end  
        end
        if distributionoption == "EvenlySpreadOut"
            assumptions_array = assumptions_array / 12
        end
    elseif distributionoption == "BOP"
        for t in 0:proj_len
            if mod(duration[t], 12) == 1
                index = findfirst(table_data[:, 1] .== pol_year[t])
                if index !== nothing
                    append!(assumptions_array, table_data[index, columnheader])
                else
                    append!(assumptions_array, 0.0)
                end
            else
                append!(assumptions_array, 0.0)
            end
        end
    end
    return ZerobasedIndex!(assumptions_array)
end

# Read assumptions from table - Projection Year and Calendar Year
function read_table_PRJY_CY(table_data::DataFrame, table_header::String, year)
    assumptions_array = OffsetArray([], Origin(0))
    for t in 0:proj_len
        index = findfirst(table_data[:, 1] .== year[t])
        if index !== nothing
            append!(assumptions_array, table_data[index, table_header])
        else
            append!(assumptions_array, 0.0) 
        end  
    end
    return ZerobasedIndex!(assumptions_array)
end

# Read assumptions from table - Policy Year - Multi-index
function read_table_PY_MI(table_data::DataFrame, index_1, index_2, table_header::String, pol_year)
    assumptions_array = OffsetArray([], Origin(0))
    data = filter(row -> row[2] == index_1 && row[3] == index_2, table_data)
    for t in 0:proj_len
        index = findfirst(data[:, 1] .== pol_year[t])       
        if index !== nothing
            append!(assumptions_array, data[index, table_header])
        else
            append!(assumptions_array, 0.0) 
        end  
    end
    return ZerobasedIndex!(assumptions_array)
end

# Read assumptions from table - Attained Age
function read_table_AA(table_data::DataFrame, table_header::String, att_age)
    assumptions_array = OffsetArray([], Origin(0))
    index = 1
    for t in 0:proj_len
        index = findfirst(table_data[:, 1] .== att_age[t])   ####
        if index !== nothing
            append!(assumptions_array, table_data[index, table_header])
        else
            append!(assumptions_array, 0.0)
        end  
    end
    return ZerobasedIndex!(assumptions_array)
end

# Read assumptions from table - Entry Age
function read_table_EA(table_data::DataFrame, table_header::String, issue_age::Integer)
    index = findfirst(table_data[:, 1] .== issue_age)
    if index !== nothing
        return table_data[index, table_header] .* ZerobasedIndex!(ones(Float64, proj_len+1))
    end
end

# Read assumptions from table - Entry Age - Multi-index
function read_table_EA_MI(table_data::DataFrame, index_1, index_2, table_header::String, issue_age::Integer)
    data = filter(row -> row[2] == index_1 && row[3] == index_2, table_data)
    index = findfirst(data[:, 1] .== issue_age)
    if index !== nothing
        return data[index, table_header] .* ZerobasedIndex!(ones(Float64, proj_len+1))
    end
end

# Create cf array with reverse cumulative sum of cf with discounting
function rev_cumsum_disc(cf, disc_rate, cf_timing="EOP")
    n = length(cf) - 1
    result = similar(cf)
    total = 0

    if cf_timing == "EOP"
        for t in n-1:-1:0
            total = (cf[t+1] .+ total) ./ (1 .+ disc_rate[t+1])
            result[t] = total
        end
    else
        for t in n-1:-1:0
            total = cf[t+1] .+ total ./ (1 .+ disc_rate[t+1])
            result[t] = total
        end
    end
    return result
end