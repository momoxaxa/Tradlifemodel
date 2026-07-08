#=
ZerobasedIndex(array::Array)
read_table_ind(table_data::DataFrame, rowlabel::Union{String, Nothing}=nothing, columnheader::String="Value")   
read_table_PY(table_data::DataFrame, columnheader::String, pol_year, duration, pol_proj_len, distributionoption::String="None")
read_table_PRJY_CY(table_data::DataFrame, table_header::String, year, pol_proj_len)
read_table_AA(table_data::DataFrame, table_header::String, att_age, pol_proj_len)
read_table_EA(table_data::DataFrame, table_header::String, issue_age::Integer, pol_proj_len::Integer)
rev_cumsum_disc(cf, disc_rate, cf_timing="EOP")
eval_udf_node(node, var_dict::Dict{Symbol, Any})
eval_udf(expr::Expr, var_dict::Dict{Symbol, Any})
=#

using OffsetArrays, DataFrames
using OffsetArrays: Origin

# Convert Array from 1-based index to 0-based index
function ZerobasedIndex(array)
    return OffsetArray(array, Origin(0))
end

# Read assumptions from table - Indicators
function read_table_ind(table_data::DataFrame, rowlabel::Union{String, Nothing}=nothing, columnheader::String="Value")   
    if rowlabel === nothing
        table_data[1, columnheader][1]
    else
        filter(row -> row[1] == rowlabel, table_data)[1, columnheader] |> ZerobasedIndex
    end
end

# Read assumptions from table - Policy Year
function read_table_PY(table_data::DataFrame, columnheader::String, pol_year, duration, pol_proj_len, distributionoption::String="None")
    assumptions_array = OffsetArray([],Origin(0))
    index = 1
    if distributionoption in ("None", "EvenlySpreadOut")
        for t in 0:pol_proj_len
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
        for t in 0:pol_proj_len
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
    return ZerobasedIndex(assumptions_array)
end

# Read assumptions from table - Projection Year and Calendar Year
function read_table_PRJY_CY(table_data::DataFrame, table_header::String, year, pol_proj_len)
    assumptions_array = OffsetArray([], Origin(0))
    for t in 0:pol_proj_len
        index = findfirst(table_data[:, 1] .== year[t])
        if index !== nothing
            append!(assumptions_array, table_data[index, table_header])
        else
            append!(assumptions_array, 0.0) 
        end  
    end
    return ZerobasedIndex(assumptions_array)
end

# Read assumptions from table - Attained Age
function read_table_AA(table_data::DataFrame, table_header::String, att_age, pol_proj_len)
    assumptions_array = OffsetArray([], Origin(0))
    index = 1
    for t in 0:pol_proj_len
        index = findfirst(table_data[:, 1] .== att_age[t])   ####
        if index !== nothing
            append!(assumptions_array, table_data[index, table_header])
        else
            append!(assumptions_array, 0.0)
        end  
    end
    return ZerobasedIndex(assumptions_array)
end

# Read assumptions from table - Entry Age
function read_table_EA(table_data::DataFrame, table_header::String, issue_age::Integer, pol_proj_len::Integer)
    index = findfirst(table_data[:, 1] .== issue_age)
    if index !== nothing
        return table_data[index, table_header] .* ZerobasedIndex(ones(Float64, pol_proj_len+1))
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

# Evaluate a node in a UDF expression tree
function eval_udf_node(node, var_dict::Dict{Symbol, Any})
    if node isa Symbol
        return var_dict[node]
    elseif node isa Number
        return node
    elseif node isa Expr
        return eval_udf(node, var_dict)
    else
        error("UDF: unsupported node type $(typeof(node))")
    end
end

# Evaluate a UDF Expr by walking the AST — thread-safe, no global scope pollution.
# Supports operators: + - * / ^ % min max (all broadcast over OffsetArrays)
function eval_udf(expr::Expr, var_dict::Dict{Symbol, Any})
    if expr.head == :call
        op   = expr.args[1]
        args = [eval_udf_node(arg, var_dict) for arg in expr.args[2:end]]
        if     op == :+ || op == :.+   return reduce((a, b) -> a .+ b, args)
        elseif op == :- || op == :.-   return reduce((a, b) -> a .- b, args)
        elseif op == :* || op == :.*   return reduce((a, b) -> a .* b, args)
        elseif op == :/ || op == :./   return reduce((a, b) -> a ./ b, args)
        elseif op == :^ || op == :.^   return reduce((a, b) -> a .^ b, args)
        elseif op == :% || op == :.%   return reduce((a, b) -> a .% b, args)
        elseif op == :min              return reduce((a, b) -> min.(a, b), args)
        elseif op == :max              return reduce((a, b) -> max.(a, b), args)
        else
            error("UDF: unsupported operator $op")
        end
    else
        error("UDF: unsupported expression head $(expr.head)")
    end
end