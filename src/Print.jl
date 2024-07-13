"""
print_single_mp(polt, asmpt, ppt, svt, ift, pvcft)
print_aggregate_result(date, ppt, svt, ift, pvcft)

"""

# Print full result for single model point
function print_single_mp(polt, asmpt, ppt, svt, ift, pvcft)
    result = DataFrame()
    struct_name_dict = Dict(
        "polt" => polt, 
        "asmpt" => asmpt,
        "ppt" => ppt,
        "svt" => svt,
        "ift" => ift,
        "pvcft" => pvcft
        )
    for row in eachrow(print_option_df)
        result[:, row.Variable] = OffsetArray(getfield(struct_name_dict[row.Struct], Symbol(row.Variable)), Origin(1))
    end
    return result
end

# Print aggregate result
function print_aggregate_result(date, ppt, svt, ift, pvcft)
    result = DataFrame()
    struct_name_dict = Dict(
        "ppt" => ppt,
        "svt" => svt,
        "ift" => ift,
        "pvcft" => pvcft
        )
    result[:, :date] = OffsetArray(date,Origin(1))
    for row in eachrow(print_agg_df)
        result[:, row.Variable] = OffsetArray(getfield(struct_name_dict[row.Struct], Symbol(row.Variable)), Origin(1))    
    end
    return result
end