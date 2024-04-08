"""

if_months(iss_date::Date, valn_date::Date=valn_date)
get_excel_sheet(input_file_path::String, prod_code::String)::Dict{String, DataFrame}
read_excel_ind(exceldata::DataFrame, datatype::String, excelheader::String="Value")
read_excel_PY(exceldata::DataFrame, excelheader::String, pol_year::Array, duration::Array, distributionoption::String="None")
read_excel_AA(exceldata::DataFrame, sex::String, att_age::Array)
get_prem_freq(prem_mode::String)
rev_cumsum_disc(cf, disc_rate, cf_timing="EOP")

"""

# Calculate months policy has been in force
function if_months(iss_date::Date, valn_date::Date=valn_date)
    return (year(valn_date) - year(iss_date)) * 12 + month(valn_date) - month(iss_date) + 1
end

# Load assumptions into Dictionary of DataFrames
function get_excel_sheet(input_file_path::String, prod_code::String)::Dict{String, DataFrame}
    excel_data = Dict()
    xf = XLSX.readxlsx("$(input_file_path)input_$(prod_code).xlsx")
    for sheet in XLSX.sheetnames(xf)
        excel_data[sheet] = DataFrame(XLSX.readtable("$(input_file_path)input_$(prod_code).xlsx", sheet))
    end
    
    return excel_data
end

# Read assumptions from Excel - Indicators
function read_excel_ind(exceldata::DataFrame, datatype::String, excelheader::String="Value")   
    exceldata[exceldata.Type .== datatype, excelheader][1]
end

# Read assumptions from Excel - Policy Year
function read_excel_PY(exceldata::DataFrame, excelheader::String, pol_year::Array, duration::Array, distributionoption::String="None")
    assumptions_array = Float64[]
    index = 1
    if distributionoption in ("None", "EvenlySpreadOut")
        for k in 1:proj_len
            index = findfirst(exceldata.Year .== pol_year[k])
            if index !== nothing
                append!(assumptions_array, exceldata[index, excelheader])
            else
                append!(assumptions_array, 0.0) 
            end  
        end
        if distributionoption == "EvenlySpreadOut"
            assumptions_array = assumptions_array / 12
        end
    elseif distributionoption == "BOP"
        for k in 1:proj_len
            if mod(duration[k], 12) == 1
                index = findfirst(exceldata.Year .== pol_year[k])
                if index !== nothing
                    append!(assumptions_array, exceldata[index, excelheader])
                else
                    append!(assumptions_array, 0.0)
                end
            else
                append!(assumptions_array, 0.0)
            end
        end
    end
    return assumptions_array
end

# Read assumptions from Excel - Attained Age
function read_excel_AA(exceldata::DataFrame, sex::String, att_age::Array)
    assumptions_array = Float64[]
    index = 1
    for k in 1:proj_len
        index = findfirst(exceldata.Age .== att_age[k])
        if index !== nothing
            append!(assumptions_array, exceldata[index, sex])
        else
            append!(assumptions_array, 0.0)
        end  
    end
    return assumptions_array
end

# Get premium frequency for a model point
function get_prem_freq(prem_mode::String)
    if prem_mode == "A"
        prem_freq = 1
    elseif prem_mode == "S"
        prem_freq = 2
    elseif prem_mode == "Q"
        prem_freq = 4
    else
        prem_freq = 12
    end
    return prem_freq
end

# Create cf array with reverse cumulative sum of cf with discounting
function rev_cumsum_disc(cf, disc_rate, cf_timing="EOP")
    n = length(cf)
    result = similar(cf)
    total = 0

    if cf_timing == "EOP"
        for i in n:-1:1
            total = (cf[i] .+ total) ./ (1 .+ disc_rate[i])
            result[i] = total
        end
    else
        for i in n:-1:1
            total = cf[i] .+ total ./ (1 .+ disc_rate[i])
            result[i] = total
        end
    end
    return result
end

