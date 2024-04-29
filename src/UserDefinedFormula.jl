"""
get_formula_variables(formula::Expr, formula_variable, prodfeature)
user_defined_table_header(UDTableName::String)
"""

using XLSX, DataFrames

function get_formula_variables(formula::Expr, formula_variable, prodfeature)
    if length(formula.args) > 0
        for item in formula.args
            if typeof(item) == Expr
                get_formula_variables(item, formula_variable, prodfeature)
            elseif typeof(item) == Symbol 
                if !(item in [:+, :-, :*, :/, :^, :%, :.+, :.-, :.*, :./, :.^, :.%])
                    push!(formula_variable, item)
                end
            end
        end
    end
    return formula_variable
end

function user_defined_table_header(UDTableName::String) ## to revise
    return names(DataFrame(XLSX.readtable("$(input_file_path)Tables.xlsx", UDTableName)))
end

for prodfeature in ["Premium", "Commission", "Death_Benefit", "Survival_Benefit"]
    formula_text = filter(row -> row."Product Feature" == prodfeature, user_defined_formula_df)[1, "User Defined Formula"]
    if formula_text !== missing
        formula = Meta.parse(formula_text)
        arguments = get_formula_variables(formula, [], prodfeature)
        fields_in_user_defined_table = user_defined_table_header("DB02UDT") ## to replace hardcoded example
        variables_validation = all(item -> item in fields_in_user_defined_table, string.(arguments))
        # generated_function = Meta.parse("$(Expr(:call, Symbol("$(prodfeature)_UDF"), arguments...)) = $formula")
        if !variables_validation
            error("Variables validation failed for $prodfeature. Please check that the user defined table contains all the variables used in the user defined formula.")
        end
    end
end