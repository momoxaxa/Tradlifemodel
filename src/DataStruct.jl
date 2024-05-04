using Dates

# Define struct for model points

struct ModelPoint
    pol_id::Integer
    prod_id::String
    iss_date::Date
    iss_age::Integer
    sex::String
    pol_term::Integer
    init_sum_assured::Float64
    init_prem::Float64
    prem_mode::String
    curr_dur::Integer
    curr_pol_yr::Integer
    pol_proj_len::Integer

    function ModelPoint(df::DataFrame, k::Integer)
        curr_dur = if_months(df[k, "Issue_Date"], valn_date) + 1
        curr_pol_yr = ceil(curr_dur/12)
        pol_proj_len = df[k, "Pol_Term"] * 12 - curr_dur + 1
        new(
            df[k,"Pol_ID"],
            df[k,"Prod_ID"],
            df[k, "Issue_Date"],
            df[k,"Issue_Age"], 
            df[k,"Sex"], 
            df[k,"Pol_Term"], 
            df[k,"Sum_Assured"],
            df[k,"Premium"],
            df[k,"Premium_Mode"],
            curr_dur,
            curr_pol_yr,
            pol_proj_len
            )
    end
end

# Define struct for Input Fields

mutable struct InputFields
    mult::Union{Float64, Missing}
    table::Union{String, Missing}
    table_column::Union{String, Missing}
    PAD::Union{Float64, Missing}

    function InputFields(
        mult::Union{Float64, Missing},
        table::Union{String, Missing},
        table_column::Union{String, Missing}, 
        PAD::Union{Float64, Missing}
        )

        new(mult, table, table_column, PAD)
    end
end

# Define struct for Product Feature Sets

mutable struct ProductFeatureSet
    death_ben::InputFields
    surr_ben::InputFields
    commission::InputFields

    function ProductFeatureSet(df::DataFrame, projtype::String, prodcode::String)
        df_prodfeatures = filter("Projection Type" => x -> x == projtype, df)[:, Cols(Between("Projection Type", "Data Type"), Symbol(prodcode))]

        prodfeatures = Dict(
            "death_ben" => InputFields(1.0, "", "", 0.0),
            "surr_ben" => InputFields(1.0, "", "", 0.0),
            "commission" => InputFields(1.0, "", "", 0.0)
        )

        fields_default = Dict(
            "Mult" => 1.0,
            "Table" => "",
            "Table Column" => "",
            "PAD" => 0.0
        )
        
        for prodfeature in collect(unique(df_prodfeatures[:,"Projection Variable"]))
            df_prodfeatures_2 = filter("Projection Variable" => x -> x == prodfeature, df_prodfeatures)
            fields = copy(fields_default)
            for field in collect(df_prodfeatures_2[:,"Data Type"])
                fields[field] = filter(row -> row."Data Type" == field, df_prodfeatures_2)[1,4]
            end
            prodfeatures[prodfeature] = InputFields(fields["Mult"], fields["Table"], fields["Table Column"], fields["PAD"])
        end

        new(
            prodfeatures["death_ben"],
            prodfeatures["surr_ben"],
            prodfeatures["commission"]
        )
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
            "mortality" => InputFields(1.0, "", "", 0.0),
            "lapse" => InputFields(1.0, "", "", 0.0),
            "expense" => InputFields(1.0, "", "", 0.0),
            "disc_rate" => InputFields(1.0, "", "", 0.0),
            "invt_return" => InputFields(1.0, "", "", 0.0),
            "prem_tax" => InputFields(1.0, "", "", 0.0),
            "tax" => InputFields(1.0, "", "", 0.0)
        )

        fields_default = Dict(
            "Mult" => 1.0,
            "Table" => "",
            "Table Column" => "",
            "PAD" => 0.0
        )

        for assumption in collect(unique(df_asmp[:,"Projection Variable"]))
            df_asmp_2 = filter("Projection Variable" => x -> x == assumption, df_asmp)
            fields = copy(fields_default)
            for field in collect(df_asmp_2[:,"Data Type"])
                fields[field] = filter(row -> row."Data Type" == field, df_asmp_2)[1,4]
            end
            assumptions[assumption] = InputFields(fields["Mult"], fields["Table"], fields["Table Column"], fields["PAD"])
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
    date::Array{Date}
    duration::Array{Integer}
    pol_year::Array{Integer}
    att_age::Array{Integer}
    modal_cf_indicator::Array{Float64}
   
    function PolicyInfoTable(curr_dur::Integer, iss_age::Integer, prem_mode::String)
        date = [valn_date+Dates.Day(1) + Dates.Month(i-1) for i in 1:proj_len]
        duration = collect(curr_dur:proj_len+curr_dur-1)
        pol_year = ceil.(duration/12)
        att_age = iss_age .+ pol_year .- 1
        prem_freq = get_prem_freq(prem_mode)
        modal_cf_indicator = Int.(mod.(duration .- 1, 12/prem_freq) .== 0)
        new(
            date,  # date
            duration,  # duration
            pol_year,  # pol_year
            att_age,  # att_age
            modal_cf_indicator  # modal_cf_indicator          
        )
    end
end

mutable struct AssumptionsTable <: Projection 
    mort_rate_ann::Vector{Float64}
    mort_rate_mth::Vector{Float64}
    lapse_rate_ann::Vector{Float64}
    lapse_rate_mth::Vector{Float64}
    acq_exp_per_pol::Vector{Float64}
    acq_exp_perc_prem::Vector{Float64}
    maint_exp_per_pol::Vector{Float64}
    maint_exp_perc_prem::Vector{Float64}
    disc_rate_ann::Vector{Float64}
    disc_rate_mth::Vector{Float64}
    invt_ret_ann::Vector{Float64}
    invt_ret_mth::Vector{Float64}
    prem_tax_rate::Vector{Float64}
    tax_rate::Vector{Float64}

    function AssumptionsTable()
        new(
            zeros(Float64, proj_len),  # mort_rate_ann
            zeros(Float64, proj_len),  # mort_rate_mth
            zeros(Float64, proj_len),  # lapse_rate_ann
            zeros(Float64, proj_len),  # lapse_rate_mth
            zeros(Float64, proj_len),  # acq_exp_per_pol
            zeros(Float64, proj_len),  # acq_exp_perc_prem
            zeros(Float64, proj_len),  # maint_exp_per_pol
            zeros(Float64, proj_len),  # maint_exp_perc_prem
            zeros(Float64, proj_len),  # disc_rate_ann
            zeros(Float64, proj_len),  # disc_rate_mth
            zeros(Float64, proj_len),  # invt_ret_ann
            zeros(Float64, proj_len),  # invt_ret_mth
            zeros(Float64, proj_len),  # prem_tax_rate
            zeros(Float64, proj_len)  # tax_rate
        )
    end
end

mutable struct PerPolicyCFTable <: Projection
    premium_pp::Vector{Float64}
    sum_assured_pp::Vector{Float64}
    comm_pp::Vector{Float64}
    prem_tax_pp::Vector{Float64}
    death_ben_pp::Vector{Float64}
    surr_ben_pp::Vector{Float64}
    acq_exp_pp::Vector{Float64}
    maint_exp_pp::Vector{Float64}
    resv_pp::Vector{Float64}
    capreq_pp::Vector{Float64}

    function PerPolicyCFTable()
        new(
            zeros(Float64, proj_len),  # premium_pp
            zeros(Float64, proj_len),  # sum_assured_pp
            zeros(Float64, proj_len),  # comm_pp
            zeros(Float64, proj_len),  # prem_tax_pp
            zeros(Float64, proj_len),  # death_ben_pp
            zeros(Float64, proj_len),  # surr_ben_pp
            zeros(Float64, proj_len),  # acq_exp_pp
            zeros(Float64, proj_len),  # maint_exp_pp
            zeros(Float64, proj_len),  # resv_pp
            zeros(Float64, proj_len)  # capreq_pp
        )
    end
end

mutable struct SurvivalshipTable <: Projection  
    pol_if::Vector{Float64}
    pol_death::Vector{Float64}
    pol_lapse::Vector{Float64}
    pol_maturity::Vector{Float64}

    function SurvivalshipTable()
        new(
            zeros(Float64, proj_len),  # pol_if
            zeros(Float64, proj_len),  # pol_death
            zeros(Float64, proj_len),  # pol_lapse
            zeros(Float64, proj_len)  # pol_maturity
        )
    end
end

mutable struct InForceCFTable <: Projection
    premium_if::Vector{Float64}
    prem_tax_if::Vector{Float64}
    comm_if::Vector{Float64}
    acq_exp_if::Vector{Float64}
    maint_exp_if::Vector{Float64}
    death_ben_if::Vector{Float64}
    surr_ben_if::Vector{Float64}
    resv_if::Vector{Float64}
    inc_resv_if::Vector{Float64}
    invt_return_if::Vector{Float64}
    prof_bef_tax_capreq_if::Vector{Float64}
    tax_if::Vector{Float64}
    prof_aft_tax_bef_capreq_if::Vector{Float64}
    capreq_if::Vector{Float64}
    inc_capreq_if::Vector{Float64}
    invt_return_on_capreq_if::Vector{Float64}
    tax_on_invt_return_on_capreq_if::Vector{Float64}
    prof_aft_tax_capreq_if::Vector{Float64}

    function InForceCFTable()
        new(
            zeros(Float64, proj_len),  # premium_if
            zeros(Float64, proj_len),  # prem_tax_if
            zeros(Float64, proj_len),  # comm_if
            zeros(Float64, proj_len),  # acq_exp_if
            zeros(Float64, proj_len),  # maint_exp_if
            zeros(Float64, proj_len),  # death_ben_if
            zeros(Float64, proj_len),  # surr_ben_if
            zeros(Float64, proj_len),  # resv_if
            zeros(Float64, proj_len),  # inc_resv_if
            zeros(Float64, proj_len),  # invt_return_if
            zeros(Float64, proj_len),  # prof_bef_tax_capreq_if
            zeros(Float64, proj_len),  # tax_if
            zeros(Float64, proj_len),  # prof_aft_tax_bef_capreq_if
            zeros(Float64, proj_len),  # capreq_if
            zeros(Float64, proj_len),  # inc_capreq_if
            zeros(Float64, proj_len),  # invt_return_on_capreq_if
            zeros(Float64, proj_len),  # tax_on_invt_return_on_capreq_if
            zeros(Float64, proj_len)  # prof_aft_tax_capreq_if

        )
    end
end

mutable struct PVCFTable <: Projection
    pv_premium::Vector{Float64}
    pv_prem_tax::Vector{Float64}
    pv_comm::Vector{Float64}
    pv_acq_exp::Vector{Float64}
    pv_maint_exp::Vector{Float64}
    pv_death_ben::Vector{Float64}
    pv_surr_ben::Vector{Float64}
    pv_cf::Vector{Float64}
    pv_inc_resv::Vector{Float64}
    pv_invt_return::Vector{Float64}
    pv_prof_bef_tax_capreq::Vector{Float64}
    pv_tax::Vector{Float64}
    pv_prof_aft_tax_bef_capreq::Vector{Float64}
    pv_inc_capreq::Vector{Float64}
    pv_invt_return_on_capreq::Vector{Float64}
    pv_tax_on_invt_return_on_capreq::Vector{Float64}
    pv_prof_aft_tax_capreq::Vector{Float64}

    function PVCFTable()
        new(
            zeros(Float64, proj_len),  # pv_premium
            zeros(Float64, proj_len),  # pv_prem_tax
            zeros(Float64, proj_len),  # pv_comm
            zeros(Float64, proj_len),  # pv_acq_exp
            zeros(Float64, proj_len),  # pv_maint_exp
            zeros(Float64, proj_len),  # pv_death_ben
            zeros(Float64, proj_len),  # pv_surr_ben
            zeros(Float64, proj_len),  # pv_cf
            zeros(Float64, proj_len),  # pv_inc_resv
            zeros(Float64, proj_len),  # pv_invt_return
            zeros(Float64, proj_len),  # pv_prof_bef_tax_capreq
            zeros(Float64, proj_len),  # pv_tax
            zeros(Float64, proj_len),  # pv_prof_aft_tax_bef_capreq
            zeros(Float64, proj_len),  # pv_inc_capreq
            zeros(Float64, proj_len),  # pv_invt_return_on_capreq
            zeros(Float64, proj_len),  # pv_tax_on_invt_return_on_capreq
            zeros(Float64, proj_len)  # pv_prof_aft_tax_capreq
        )
    end
end