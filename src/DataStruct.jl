#=
if_months(iss_date::Date, valn_date::Date=valn_date)::Integer
get_prem_freq(prem_mode::String)
get_formula_variables(formula::Expr, formula_variable)
validate_formula_variables(product_features_set::ProductFeatureSet; update_prodfeatset::Bool=false, failed_prodfeatures::Union{Array, Nothing}=nothing)
=#

using Dates

# Calculate months policy has been in force
function if_months(iss_date::Date, valn_date::Date=valn_date)::Integer
    return (year(valn_date) - year(iss_date)) * 12 + month(valn_date) - month(iss_date) + 1
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

# Define struct for model points

struct ModelPoint
    pol_id::Integer
    prod_id::String
    issue_date::Date
    issue_age::Integer
    sex::String
    smoker::String
    pol_term::Integer
    prem_term::Integer
    sum_assured::Float64
    premium::Float64
    prem_mode::String
    dur_valdate::Integer
    curr_pol_yr::Integer
    pol_proj_len::Integer

    function ModelPoint(df::DataFrame, k::Integer)
        dur_valdate = if_months(df[k, "issue_date"], valn_date)
        curr_pol_yr = ceil((dur_valdate+1)/12) ##
        pol_proj_len = df[k, "pol_term"] * 12 - dur_valdate
        new(
            df[k,"pol_id"],
            df[k,"prod_id"],
            df[k, "issue_date"],
            df[k,"issue_age"], 
            df[k,"sex"], 
            df[k,"smoker"], 
            df[k,"pol_term"], 
            df[k, "prem_term"],
            df[k,"sum_assured"],
            df[k,"premium"],
            df[k,"premium_mode"],
            dur_valdate,
            curr_pol_yr,
            pol_proj_len
            )
    end
end

# Define struct for Input Fields

mutable struct InputFields
    mult::Union{Float64, Missing}
    table_type::Union{String, Missing}
    table::Union{String, Missing}
    table_column::Union{String, Missing}
    UDF::Union{String, Missing}
    UDF_expr::Expr
    UDF_vars::Array
    PAD::Union{Float64, Missing}

    function InputFields(
        mult::Union{Float64, Missing},
        table_type::Union{String, Missing},
        table::Union{String, Missing},
        table_column::Union{String, Missing}, 
        UDF::Union{String, Missing},
        UDF_expr::Expr,
        UDF_vars::Array,
        PAD::Union{Float64, Missing}
        )

        new(mult, table_type, table, table_column, UDF, UDF_expr, UDF_vars, PAD)

    end
end

# Define struct for Product Feature Sets

mutable struct ProductFeatureSet
    premium::InputFields
    sum_assured::InputFields
    death_ben::InputFields
    surr_ben::InputFields
    commission::InputFields

    function ProductFeatureSet(df::DataFrame, projtype::String, prodcode::String)
        df_prodfeatures = filter("Projection Type" => x -> x == projtype, df)[:, Cols(Between("Projection Type", "Data Type"), Symbol(prodcode))]

        prodfeatures = Dict(
            "premium" => InputFields(1.0, "", "", "", "", :(), [], 0.0),
            "sum_assured" => InputFields(1.0, "", "", "", "", :(), [], 0.0),
            "death_ben" => InputFields(1.0, "", "", "", "", :(), [], 0.0),
            "surr_ben" => InputFields(1.0, "", "", "", "", :(), [], 0.0),
            "commission" => InputFields(1.0, "", "", "", "", :(), [], 0.0)
        )

        fields_default = Dict(
            "Mult" => 1.0,
            "Table Type" => "",
            "Table" => "",
            "Table Column" => "",
            "UDF" => "",
            "UDF_expr" => :(),
            "UDF_vars" => [],
            "PAD" => 0.0
        )
        
        for prodfeature in collect(unique(df_prodfeatures[:,"Projection Variable"]))
            df_prodfeatures_2 = filter("Projection Variable" => x -> x == prodfeature, df_prodfeatures)
            fields = copy(fields_default)
            for field in collect(df_prodfeatures_2[:,"Data Type"])
                fields[field] = filter(row -> row."Data Type" == field, df_prodfeatures_2)[1,4]
            end
            prodfeatures[prodfeature] = InputFields(fields["Mult"], fields["Table Type"], fields["Table"], fields["Table Column"], fields["UDF"], fields["UDF_expr"], fields["UDF_vars"], fields["PAD"])
        end

        new(
            prodfeatures["premium"],
            prodfeatures["sum_assured"],
            prodfeatures["death_ben"],
            prodfeatures["surr_ben"],
            prodfeatures["commission"]
        )
    end
end

# Get variables from User Defined Formula
function get_formula_variables(formula::Expr, formula_variable)
    if length(formula.args) > 0
        for item in formula.args
            if typeof(item) == Expr
                get_formula_variables(item, formula_variable)
            elseif typeof(item) == Symbol 
                if !(item in [:+, :-, :*, :/, :^, :%, :min, :max, :.+, :.-, :.*, :./, :.^, :.%])
                    push!(formula_variable, item)
                end
            end
        end
    end
    return formula_variable
end

# Validate user defined tables contains all the variables used in user defined formula
# Option to update ProdFeatureSet and option to generate a list of failed product features
function validate_formula_variables(product_features_set::ProductFeatureSet; update_prodfeatset::Bool=false, failed_prodfeatures::Union{Array, Nothing}=nothing)

    for prodfeature in fieldnames(ProductFeatureSet)
        udt_name = getfield(product_features_set, Symbol(prodfeature)).table
        formula_str = getfield(product_features_set, Symbol(prodfeature)).UDF
        if !(formula_str === missing) && !isempty(formula_str)
            formula = Meta.parse(formula_str)
            formula_variables = get_formula_variables(formula, [])
            fields_in_user_defined_table = names(DataFrame(XLSX.readtable("$(input_file_path)Tables.xlsx", udt_name)))
            validate_variables = all(item -> item in fields_in_user_defined_table, string.(formula_variables))    
            if validate_variables 
                if update_prodfeatset
                    getfield(product_features_set, Symbol(prodfeature)).UDF_expr = formula
                    getfield(product_features_set, Symbol(prodfeature)).UDF_vars = formula_variables
                end
            else 
                if failed_prodfeatures !== nothing
                    push!(failed_prodfeatures, String(prodfeature))
                end
            end
        end
    end
end

# Define struct Assumption Sets

mutable struct AssumptionSet
    mortality::InputFields
    lapse::InputFields
    expense::InputFields
    disc_rate::InputFields
    invt_return::InputFields
    prem_tax::InputFields
    tax::InputFields
    projtype::String

    function AssumptionSet(df::DataFrame, projtype::String, prodcode::String)
        df_asmp = filter("Projection Type" => x -> x == projtype, df)[:, Cols(Between("Projection Type", "Data Type"), Symbol(prodcode))]
        assumptions = Dict(
            "mortality" => InputFields(1.0, "", "", "", "", :(), [], 0.0),
            "lapse" => InputFields(1.0, "", "", "", "", :(), [], 0.0),
            "expense" => InputFields(1.0, "", "", "", "", :(), [], 0.0),
            "disc_rate" => InputFields(1.0, "", "", "", "", :(), [], 0.0),
            "invt_return" => InputFields(1.0, "", "", "", "", :(), [], 0.0),
            "prem_tax" => InputFields(1.0, "", "", "", "", :(), [], 0.0),
            "tax" => InputFields(1.0, "", "", "", "", :(), [], 0.0)
        )

        fields_default = Dict(
            "Mult" => 1.0,
            "Table Type" => "",
            "Table" => "",
            "Table Column" => "",
            "UDF" => "",
            "UDF_expr" => :(),
            "UDF_vars" => [],
            "PAD" => 0.0
        )

        for assumption in collect(unique(df_asmp[:,"Projection Variable"]))
            df_asmp_2 = filter("Projection Variable" => x -> x == assumption, df_asmp)
            fields = copy(fields_default)
            for field in collect(df_asmp_2[:,"Data Type"])
                fields[field] = filter(row -> row."Data Type" == field, df_asmp_2)[1,4]
            end
            assumptions[assumption] = InputFields(fields["Mult"], fields["Table Type"], fields["Table"], fields["Table Column"], fields["UDF"], fields["UDF_expr"], fields["UDF_vars"], fields["PAD"])
        end
        
        new(
            assumptions["mortality"],
            assumptions["lapse"],
            assumptions["expense"],
            assumptions["disc_rate"],
            assumptions["invt_return"],
            assumptions["prem_tax"],
            assumptions["tax"],
            projtype
        )
    end
end

# Define struct for run set

mutable struct RunSet
    RunNumber::String
    BaseProjMort::Float64
    BaseProjLapse::Float64
    BaseProjExpense::Float64
    BaseProjDiscRate::Float64
    BaseProjInvtRet::Float64
    ValnMort::Float64
    ValnLapse::Float64
    ValnExpense::Float64
    ValnDiscRate::Float64
    CapReqMort::Float64
    CapReqLapse::Float64
    CapReqExpense::Float64
    CapReqDiscRate::Float64

    function RunSet(df::DataFrame, run_number::String)
        df_run = filter("Run Number" => x -> x !== "Run Indicator" && x !== "Run Description", df)
        dict_run = Dict()
        
        for row in eachrow(df_run)
            dict_run[row."Run Number"] = row[Symbol(run_number)]
        end

        new(
            run_number,
            dict_run["Base Projection - Mortality"],
            dict_run["Base Projection - Lapse"],
            dict_run["Base Projection - Expense"],
            dict_run["Base Projection - Discount Rate"],
            dict_run["Base Projection - Investment Return"],
            dict_run["Valuation - Mortality"],
            dict_run["Valuation - Lapse"],
            dict_run["Valuation - Expense"],
            dict_run["Valuation - Discount Rate"],
            dict_run["Capital Requirement - Mortality"],
            dict_run["Capital Requirement - Lapse"],
            dict_run["Capital Requirement - Expense"],
            dict_run["Capital Requirement - Discount Rate"]
        )
    end

end

# Define struct for projection

abstract type Projection end

mutable struct PolicyInfoTable <: Projection
    date::OffsetArray{Date}
    duration::OffsetArray{}
    proj_year::OffsetArray{}
    pol_year::OffsetArray{}
    att_age::OffsetArray{}
    modal_cf_indicator::OffsetArray{}
    
    function PolicyInfoTable(dur_valdate::Integer, issue_age::Integer, prem_mode::String)
        date = ZerobasedIndex!([valn_date + Dates.Month(t) for t in 0:proj_len])
        duration =  ZerobasedIndex!(collect(dur_valdate:proj_len+dur_valdate))
        proj_year = ZerobasedIndex!([0; repeat(collect(1:proj_yrs),inner=12)])
        pol_year = ceil.(duration/12)
        att_age = issue_age .+ pol_year .- 1
        prem_freq = get_prem_freq(prem_mode)
        modal_cf_indicator = Int.(mod.(duration .- 1, 12/prem_freq) .== 0)

        new(
            date,  # date
            duration,  # duration
            proj_year, # proj_year
            pol_year,  # pol_year
            att_age,  # att_age
            modal_cf_indicator  # modal_cf_indicator          
        )
    end   
end

mutable struct AssumptionsTable <: Projection 
    mort_rate_ann::OffsetArray{}
    mort_rate_mth::OffsetArray{}
    lapse_rate_ann::OffsetArray{}
    lapse_rate_mth::OffsetArray{}
    acq_exp_per_pol::OffsetArray{}
    acq_exp_perc_prem::OffsetArray{}
    maint_exp_per_pol::OffsetArray{}
    maint_exp_perc_prem::OffsetArray{}
    disc_rate_ann::OffsetArray{}
    disc_rate_mth::OffsetArray{}
    invt_ret_ann::OffsetArray{}
    invt_ret_mth::OffsetArray{}
    prem_tax_rate::OffsetArray{}
    tax_rate::OffsetArray{}

    function AssumptionsTable()
        new(
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # mort_rate_ann
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # mort_rate_mth
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # lapse_rate_ann
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # lapse_rate_mth
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # acq_exp_per_pol
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # acq_exp_perc_prem
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # maint_exp_per_pol
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # maint_exp_perc_prem
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # disc_rate_ann
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # disc_rate_mth
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # invt_ret_ann
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # invt_ret_mth
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # prem_tax_rate
            ZerobasedIndex!(zeros(Float64, proj_len+1))  # tax_rate
        )
    end
end

mutable struct PerPolicyCFTable <: Projection
    premium_pp::OffsetArray{Float64}
    comm_pp::OffsetArray{Float64}
    prem_tax_pp::OffsetArray{Float64}
    death_ben_pp::OffsetArray{Float64}
    surr_ben_pp::OffsetArray{Float64}
    acq_exp_pp::OffsetArray{Float64}
    maint_exp_pp::OffsetArray{Float64}
    resv_pp::OffsetArray{Float64}
    capreq_pp::OffsetArray{Float64}

    function PerPolicyCFTable()
        new(
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # premium_pp
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # comm_pp
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # prem_tax_pp
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # death_ben_pp
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # surr_ben_pp
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # acq_exp_pp
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # maint_exp_pp
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # resv_pp
            ZerobasedIndex!(zeros(Float64, proj_len+1))  # capreq_pp
        )
    end
end

mutable struct SurvivalshipTable <: Projection  
    pol_if::OffsetArray{Float64}
    pol_death::OffsetArray{Float64}
    pol_lapse::OffsetArray{Float64}
    pol_maturity::OffsetArray{Float64}

    function SurvivalshipTable()
        new(
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pol_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pol_death
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pol_lapse
            ZerobasedIndex!(zeros(Float64, proj_len+1))  # pol_maturity
        )
    end
end

mutable struct InForceCFTable <: Projection
    premium_if::OffsetArray{Float64}
    prem_tax_if::OffsetArray{Float64}
    comm_if::OffsetArray{Float64}
    acq_exp_if::OffsetArray{Float64}
    maint_exp_if::OffsetArray{Float64}
    death_ben_if::OffsetArray{Float64}
    surr_ben_if::OffsetArray{Float64}
    resv_if::OffsetArray{Float64}
    inc_resv_if::OffsetArray{Float64}
    invt_return_if::OffsetArray{Float64}
    prof_bef_tax_capreq_if::OffsetArray{Float64}
    tax_if::OffsetArray{Float64}
    prof_aft_tax_bef_capreq_if::OffsetArray{Float64}
    capreq_if::OffsetArray{Float64}
    inc_capreq_if::OffsetArray{Float64}
    invt_return_on_capreq_if::OffsetArray{Float64}
    tax_on_invt_return_on_capreq_if::OffsetArray{Float64}
    prof_aft_tax_capreq_if::OffsetArray{Float64}

    function InForceCFTable()
        new(
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # premium_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # prem_tax_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # comm_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # acq_exp_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # maint_exp_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # death_ben_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # surr_ben_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # resv_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # inc_resv_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # invt_return_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # prof_bef_tax_capreq_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # tax_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # prof_aft_tax_bef_capreq_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # capreq_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # inc_capreq_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # invt_return_on_capreq_if
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # tax_on_invt_return_on_capreq_if
            ZerobasedIndex!(zeros(Float64, proj_len+1))  # prof_aft_tax_capreq_if

        )
    end
end

mutable struct PVCFTable <: Projection
    pv_premium::OffsetArray{Float64}
    pv_prem_tax::OffsetArray{Float64}
    pv_comm::OffsetArray{Float64}
    pv_acq_exp::OffsetArray{Float64}
    pv_maint_exp::OffsetArray{Float64}
    pv_death_ben::OffsetArray{Float64}
    pv_surr_ben::OffsetArray{Float64}
    pv_cf::OffsetArray{Float64}
    pv_inc_resv::OffsetArray{Float64}
    pv_invt_return::OffsetArray{Float64}
    pv_prof_bef_tax_capreq::OffsetArray{Float64}
    pv_tax::OffsetArray{Float64}
    pv_prof_aft_tax_bef_capreq::OffsetArray{Float64}
    pv_inc_capreq::OffsetArray{Float64}
    pv_invt_return_on_capreq::OffsetArray{Float64}
    pv_tax_on_invt_return_on_capreq::OffsetArray{Float64}
    pv_prof_aft_tax_capreq::OffsetArray{Float64}

    function PVCFTable()
        new(
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_premium
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_prem_tax
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_comm
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_acq_exp
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_maint_exp
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_death_ben
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_surr_ben
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_cf
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_inc_resv
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_invt_return
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_prof_bef_tax_capreq
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_tax
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_prof_aft_tax_bef_capreq
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_inc_capreq
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_invt_return_on_capreq
            ZerobasedIndex!(zeros(Float64, proj_len+1)),  # pv_tax_on_invt_return_on_capreq
            ZerobasedIndex!(zeros(Float64, proj_len+1))  # pv_prof_aft_tax_capreq
        )
    end
end