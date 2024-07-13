#=
ZerobasedIndex!(array::Array)
read_excel_ind(exceldata::DataFrame, datatype::String, excelheader::String="Value")  
read_excel_PY(exceldata::DataFrame, excelheader::String, pol_year::Array, duration::Array, distributionoption::String="None")
read_excel_PRJY_CY(exceldata::DataFrame, excelheader::String, year::Array)
read_excel_PY_MI(exceldata::DataFrame, index_1, index_2, excelheader::String, pol_year::Array)
read_excel_AA(exceldata::DataFrame, excelheader::String, att_age::Array)
read_excel_EA(exceldata::DataFrame, excelheader::String, issue_age::Integer)
read_excel_EA_MI(exceldata::DataFrame, index_1, index_2, excelheader::String, issue_age::Integer)
rev_cumsum_disc(cf, disc_rate, cf_timing="EOP")
=#

using OffsetArrays
using OffsetArrays: Origin

# Convert Array from 1-based index to 0-based index
function ZerobasedIndex!(array)
    return OffsetArray(array, 0:proj_len)
end

# Read assumptions from Excel - Indicators
function read_excel_ind(exceldata::DataFrame, rowlabel::Union{String, Nothing}=nothing, columnheader::String="Value")   
    if rowlabel === nothing
        exceldata[1, columnheader][1]
    else
        filter(row -> row[1] == rowlabel, exceldata)[1, columnheader] |> ZerobasedIndex!
    end
end

# Read assumptions from Excel - Policy Year
function read_excel_PY(exceldata::DataFrame, columnheader::String, pol_year, duration, distributionoption::String="None")
    assumptions_array = OffsetArray([],Origin(0))
    index = 1
    if distributionoption in ("None", "EvenlySpreadOut")
        for t in 0:proj_len
            index = findfirst(exceldata[:, 1] .== pol_year[t])
            if index !== nothing
                append!(assumptions_array, exceldata[index, columnheader])
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
                index = findfirst(exceldata[:, 1] .== pol_year[t])
                if index !== nothing
                    append!(assumptions_array, exceldata[index, columnheader])
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

# Read assumptions from Excel - Projection Year and Calendar Year
function read_excel_PRJY_CY(exceldata::DataFrame, excelheader::String, year)
    assumptions_array = OffsetArray([], Origin(0))
    for t in 0:proj_len
        index = findfirst(exceldata[:, 1] .== year[t])
        if index !== nothing
            append!(assumptions_array, exceldata[index, excelheader])
        else
            append!(assumptions_array, 0.0) 
        end  
    end
    return ZerobasedIndex!(assumptions_array)
end

# Read assumptions from Excel - Policy Year - Multi-index
function read_excel_PY_MI(exceldata::DataFrame, index_1, index_2, excelheader::String, pol_year)
    assumptions_array = OffsetArray([], Origin(0))
    data = filter(row -> row[2] == index_1 && row[3] == index_2, exceldata)
    for t in 0:proj_len
        index = findfirst(data[:, 1] .== pol_year[t])       
        if index !== nothing
            append!(assumptions_array, data[index, excelheader])
        else
            append!(assumptions_array, 0.0) 
        end  
    end
    return ZerobasedIndex!(assumptions_array)
end

# Read assumptions from Excel - Attained Age
function read_excel_AA(exceldata::DataFrame, excelheader::String, att_age)
    assumptions_array = OffsetArray([], Origin(0))
    index = 1
    for t in 0:proj_len
        index = findfirst(exceldata[:, 1] .== att_age[t])   ####
        if index !== nothing
            append!(assumptions_array, exceldata[index, excelheader])
        else
            append!(assumptions_array, 0.0)
        end  
    end
    return ZerobasedIndex!(assumptions_array)
end

# Read assumptions from Excel - Entry Age
function read_excel_EA(exceldata::DataFrame, excelheader::String, issue_age::Integer)
    index = findfirst(exceldata[:, 1] .== issue_age)
    if index !== nothing
        return exceldata[index, excelheader] .* ZerobasedIndex!(ones(Float64, proj_len+1))
    end
end

# Read assumptions from Excel - Entry Age - Multi-index
function read_excel_EA_MI(exceldata::DataFrame, index_1, index_2, excelheader::String, issue_age::Integer)
    data = filter(row -> row[2] == index_1 && row[3] == index_2, exceldata)
    index = findfirst(data[:, 1] .== issue_age)
    if index !== nothing
        return data[index, excelheader] .* ZerobasedIndex!(ones(Float64, proj_len+1))
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