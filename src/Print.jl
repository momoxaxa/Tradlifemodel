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

# Accumulate one model point's results into the preallocated product frame
function accumulate_aggregate_result!(resultbyproduct::DataFrame, ppt, svt, ift, pvcft)
    struct_name_dict = Dict("ppt" => ppt, "svt" => svt, "ift" => ift, "pvcft" => pvcft)
    for row in eachrow(print_agg_df)
        v = parent(getfield(struct_name_dict[row.Struct], Symbol(row.Variable)))
        col = resultbyproduct[!, row.Variable]
        @views col[1:length(v)] .+= v          # only touch the MP's own length; tail untouched
    end
    return resultbyproduct
end