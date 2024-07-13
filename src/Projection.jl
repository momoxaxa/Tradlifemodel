#=
project_per_policy_with_product_features!(ppt::PerPolicyCFTable, input_tables_dict::Dict, mp::ModelPoint, pol_year, duration, modal_cf_indicator, product_features_set)
project_per_policy_with_assumptions!(ppt::PerPolicyCFTable, asmpt:: AssumptionsTable)

project_survivalship!(svt::SurvivalshipTable, asmpt:: AssumptionsTable, pol_term, dur_at_valn_date)

project_in_force_bef_resv_capreq!(ift::InForceCFTable, ppt::PerPolicyCFTable, svt::SurvivalshipTable)
project_present_value_bef_resv_capreq!(pvcft::PVCFTable, ift::InForceCFTable, disc_rate_mth)

project_present_value_outgo_net_income!(pvcft::PVCFTable)
project_present_value_profit!(pvcft::PVCFTable)

project_per_policy_reserve!(ppt::PerPolicyCFTable, polt::PolicyInfoTable, input_tables_dict::Dict, mp::ModelPoint, valn_asmpset::AssumptionSet, s::Integer, prod_code::String, runset::RunSet, valn_method::String="Gross Premium Valuation")

project_per_policy_capreq!(ppt::PerPolicyCFTable, polt::PolicyInfoTable, input_tables_dict::Dict, mp::ModelPoint, capreq_asmpset::AssumptionSet, s::Integer, prod_code::String, runset::RunSet, capreq_method::String="Risk Based Capital")

project_in_force_inc_resv_capreq!(ift::InForceCFTable, asmpt::AssumptionsTable, ppt::PerPolicyCFTable, svt::SurvivalshipTable)
project_present_value_inc_resv_capreq!(pvcft::PVCFTable, ift::InForceCFTable, disc_rate_mth)

inner_proj(curr_asmpset::AssumptionSet, polt::PolicyInfoTable, ppt::PerPolicyCFTable, input_tables_dict::Dict, mp::ModelPoint, s::Integer, prod_code::String, inner_proj_loop::String, runset::RunSet)

run_product(prod_code::String, runset::RunSet)

=#

using .ProductFeatures

function project_per_policy_with_product_features!(ppt::PerPolicyCFTable, input_tables_dict::Dict, mp::ModelPoint, pol_year, duration, modal_cf_indicator, product_features_set)
    
    # Premium Per Policy

    ppt.premium_pp = premium(input_tables_dict, mp, pol_year, modal_cf_indicator, duration, product_features_set)

    # Death Benefit Per Policy

    ppt.death_ben_pp = death_benefit(input_tables_dict, mp, pol_year, duration, product_features_set)

    # Surrender Benefit Per Policy

    ppt.surr_ben_pp = surr_benefit(input_tables_dict, mp, pol_year, duration, product_features_set)

    # Commission Per Policy

    ppt.comm_pp = comm_perc(input_tables_dict, mp, pol_year, duration, product_features_set) .* ppt.premium_pp

end

function project_per_policy_with_assumptions!(ppt::PerPolicyCFTable, asmpt:: AssumptionsTable)
    
    # Acquisition Expense Per Policy

    ppt.acq_exp_pp = asmpt.acq_exp_per_pol .+ asmpt.acq_exp_perc_prem .* ppt.premium_pp

    # Maintenance Expense Per Policy

    ppt.maint_exp_pp = asmpt.maint_exp_per_pol .+ asmpt.maint_exp_perc_prem .* ppt.premium_pp

    # Premium Tax Per Policy

    ppt.prem_tax_pp = asmpt.prem_tax_rate .* ppt.premium_pp

end

function project_survivalship!(svt::SurvivalshipTable, asmpt:: AssumptionsTable, pol_term, dur_valdate)

    # Survivalship

    for t in 0:proj_len
        if t == 0
            svt.pol_if[t] = 1
        elseif t <= pol_term*12 - dur_valdate
            svt.pol_death[t] = svt.pol_if[t-1] * asmpt.mort_rate_mth[t]
            svt.pol_lapse[t] = (svt.pol_if[t-1] - svt.pol_death[t]) * asmpt.lapse_rate_mth[t]
            if t == pol_term*12 - dur_valdate
                svt.pol_maturity[t] = svt.pol_if[t-1] - svt.pol_death[t] - svt.pol_lapse[t]
            end
            svt.pol_if[t] = svt.pol_if[t-1] - svt.pol_death[t] - svt.pol_lapse[t] - svt.pol_maturity[t]
        end
    end

end

function project_in_force_bef_resv_capreq!(ift::InForceCFTable, ppt::PerPolicyCFTable, svt::SurvivalshipTable)

    # In Force Cashflow

    ift.premium_if = ppt.premium_pp .* ZerobasedIndex!([0; svt.pol_if[0:end-1]])
    ift.prem_tax_if = ppt.prem_tax_pp .* ZerobasedIndex!([0; svt.pol_if[0:end-1]])
    ift.comm_if = ppt.comm_pp .* ZerobasedIndex!([0; svt.pol_if[0:end-1]])
    ift.acq_exp_if = ppt.acq_exp_pp .* ZerobasedIndex!([0; svt.pol_if[0:end-1]])
    ift.maint_exp_if = ppt.maint_exp_pp .* ZerobasedIndex!([0; svt.pol_if[0:end-1]])
    ift.death_ben_if = ppt.death_ben_pp .* svt.pol_death
    ift.surr_ben_if = ppt.surr_ben_pp .* svt.pol_lapse

end

function project_present_value_bef_resv_capreq!(pvcft::PVCFTable, ift::InForceCFTable, disc_rate_mth)

    # Present Value of Cashflow

    pvcft.pv_premium = rev_cumsum_disc(ift.premium_if, disc_rate_mth, "BOP")
    pvcft.pv_prem_tax = rev_cumsum_disc(ift.prem_tax_if, disc_rate_mth, "BOP")
    pvcft.pv_comm = rev_cumsum_disc(ift.comm_if, disc_rate_mth, "BOP")
    pvcft.pv_acq_exp = rev_cumsum_disc(ift.acq_exp_if, disc_rate_mth, "BOP")
    pvcft.pv_maint_exp = rev_cumsum_disc(ift.maint_exp_if, disc_rate_mth, "BOP")
    pvcft.pv_death_ben = rev_cumsum_disc(ift.death_ben_if, disc_rate_mth, "EOP")
    pvcft.pv_surr_ben = rev_cumsum_disc(ift.surr_ben_if, disc_rate_mth, "EOP")

end
    
function project_present_value_outgo_net_income!(pvcft::PVCFTable)

    # PVCF

    pvcft.pv_cf = pvcft.pv_death_ben + pvcft.pv_surr_ben + pvcft.pv_prem_tax + pvcft.pv_comm + pvcft.pv_acq_exp + pvcft.pv_maint_exp - pvcft.pv_premium

end

function project_per_policy_reserve!(ppt::PerPolicyCFTable, polt::PolicyInfoTable, input_tables_dict::Dict, mp::ModelPoint, valn_asmpset::AssumptionSet, s::Integer, prod_code::String, runset::RunSet, valn_method::String="Gross Premium Valuation")

    # Calculate Reserve Per Policy

    if valn_method == "Gross Premium Valuation"
        valn_asmpset_lapse_up = deepcopy(valn_asmpset)
        valn_asmpset_lapse_down = deepcopy(valn_asmpset)
        valn_asmpset_lapse_down.lapse.PAD = -1.0 * valn_asmpset.lapse.PAD
    
        resv_pp_lapse_up = inner_proj(valn_asmpset_lapse_up, polt, ppt, input_tables_dict, mp, s, prod_code, "valn_lapse_up", runset)
        resv_pp_lapse_down = inner_proj(valn_asmpset_lapse_down, polt, ppt, input_tables_dict, mp, s, prod_code, "valn_lapse_down", runset)
        ppt.resv_pp[0:mp.pol_proj_len-1] = max.(resv_pp_lapse_up[0:mp.pol_proj_len-1], resv_pp_lapse_down[0:mp.pol_proj_len-1])
    end

end

function project_per_policy_capreq!(ppt::PerPolicyCFTable, polt::PolicyInfoTable, input_tables_dict::Dict, mp::ModelPoint, capreq_asmpset::AssumptionSet, s::Integer, prod_code::String, runset::RunSet, capreq_method::String="Risk Based Capital")

    # Calculate Capital Requirement Per Policy

    if capreq_method == "Risk Based Capital"
        capreq_asmpset_lapse_up = deepcopy(capreq_asmpset)
        capreq_asmpset_lapse_down = deepcopy(capreq_asmpset)
        capreq_asmpset_lapse_down.lapse.PAD = -1.0 * capreq_asmpset.lapse.PAD

        capreq_pp_lapse_up = inner_proj(capreq_asmpset_lapse_up, polt, ppt, input_tables_dict, mp, s, prod_code, "capreq_lapse_up", runset)
        capreq_pp_lapse_down = inner_proj(capreq_asmpset_lapse_down, polt, ppt, input_tables_dict, mp, s, prod_code, "capreq_lapse_down", runset)

        capreq_lapse_up = max.(capreq_pp_lapse_up .- ppt.resv_pp, 0)
        capreq_lapse_down = max.(capreq_pp_lapse_down .- ppt.resv_pp, 0)
        ppt.capreq_pp[0:mp.pol_proj_len-1] = max.(capreq_lapse_up, capreq_lapse_down)[0:mp.pol_proj_len-1] .* (1 + capreq_grossup_factor)
    end

end

function project_in_force_inc_resv_capreq!(ift::InForceCFTable, asmpt::AssumptionsTable, ppt::PerPolicyCFTable, svt::SurvivalshipTable)

    # In Force Cashflow

    ift.resv_if = ppt.resv_pp .* svt.pol_if
    ift.resv_if[0] = 0.0 # Force time 0 reserve to be zero
    ift.inc_resv_if = ift.resv_if - OffsetArray([0; ift.resv_if[0:end-1]], Origin(0))
    ift.invt_return_if = (
        ift.premium_if 
        .- ift.comm_if 
        .- ift.prem_tax_if 
        .- ift.acq_exp_if 
        .- ift.maint_exp_if 
        .+ OffsetArray([0; ift.resv_if[0:end-1]], Origin(0))
        ) .* asmpt.invt_ret_mth

    ift.prof_bef_tax_capreq_if = (
        ift.premium_if 
        .- ift.comm_if 
        .- ift.prem_tax_if 
        .- ift.acq_exp_if 
        .- ift.maint_exp_if 
        .- ift.death_ben_if 
        .- ift.surr_ben_if 
        .- ift.inc_resv_if 
        .+ ift.invt_return_if
    )
    ift.tax_if = ift.prof_bef_tax_capreq_if .* asmpt.tax_rate
    ift.prof_aft_tax_bef_capreq_if = ift.prof_bef_tax_capreq_if .- ift.tax_if
    ift.capreq_if = ppt.capreq_pp .* svt.pol_if
    ift.capreq_if[0] = 0.0 # Force time 0 capital requirement to be zero
    ift.inc_capreq_if = ift.capreq_if - OffsetArray([0; ift.capreq_if[0:end-1]], Origin(0))
    ift.invt_return_on_capreq_if = OffsetArray([0; ift.capreq_if[0:end-1]], Origin(0)) .* asmpt.invt_ret_mth
    ift.tax_on_invt_return_on_capreq_if = ift.invt_return_on_capreq_if .* asmpt.tax_rate
    ift.prof_aft_tax_capreq_if = (
        ift.prof_aft_tax_bef_capreq_if 
        .- ift.inc_capreq_if 
        .+ ift.invt_return_on_capreq_if 
        .- ift.tax_on_invt_return_on_capreq_if
    )

end

function project_present_value_inc_resv_capreq!(pvcft::PVCFTable, ift::InForceCFTable, disc_rate_mth)

    # Present Value of Cashflow

    pvcft.pv_inc_resv = rev_cumsum_disc(ift.inc_resv_if, disc_rate_mth, "EOP")
    pvcft.pv_invt_return = rev_cumsum_disc(ift.invt_return_if, disc_rate_mth, "EOP")
    pvcft.pv_prof_bef_tax_capreq = rev_cumsum_disc(ift.prof_bef_tax_capreq_if, disc_rate_mth, "EOP")
    pvcft.pv_tax = rev_cumsum_disc(ift.tax_if, disc_rate_mth, "EOP")
    pvcft.pv_prof_aft_tax_bef_capreq = rev_cumsum_disc(ift.prof_aft_tax_bef_capreq_if, disc_rate_mth, "EOP")
    pvcft.pv_inc_capreq = rev_cumsum_disc(ift.inc_capreq_if, disc_rate_mth, "EOP")
    pvcft.pv_invt_return_on_capreq = rev_cumsum_disc(ift.invt_return_on_capreq_if, disc_rate_mth, "EOP")
    pvcft.pv_tax_on_invt_return_on_capreq = rev_cumsum_disc(ift.tax_on_invt_return_on_capreq_if, disc_rate_mth, "EOP")
    pvcft.pv_prof_aft_tax_capreq = rev_cumsum_disc(ift.prof_aft_tax_capreq_if, disc_rate_mth, "EOP")

end

function inner_proj(curr_asmpset::AssumptionSet, polt::PolicyInfoTable, ppt::PerPolicyCFTable, input_tables_dict::Dict, mp::ModelPoint, s::Integer, prod_code::String, inner_proj_loop::String, runset::RunSet)

    curr_run = runset.RunNumber
    
    ppt_inner = deepcopy(ppt)
    asmpt_inner = AssumptionsTable()
    svt_inner = SurvivalshipTable()
    ift_inner = InForceCFTable()
    pvcft_inner = PVCFTable()

    read_mortality!(asmpt_inner, input_tables_dict, mp, polt, curr_asmpset, runset)
    read_lapse!(asmpt_inner, input_tables_dict, mp, polt, curr_asmpset, runset)
    read_expense!(asmpt_inner, input_tables_dict, polt, curr_asmpset, runset)
    read_disc_rate!(asmpt_inner, input_tables_dict, polt, curr_asmpset, runset)
    read_invt_return!(asmpt_inner, input_tables_dict, polt, curr_asmpset, runset)
    read_prem_tax!(asmpt_inner, input_tables_dict, polt, curr_asmpset)

    project_per_policy_with_assumptions!(ppt_inner, asmpt_inner)
    project_survivalship!(svt_inner, asmpt_inner, mp.pol_term, mp.dur_valdate)
    project_in_force_bef_resv_capreq!(ift_inner, ppt_inner, svt_inner)
    project_present_value_bef_resv_capreq!(pvcft_inner, ift_inner, asmpt_inner.disc_rate_mth)
    project_present_value_outgo_net_income!(pvcft_inner)

    # function print_innerproj_result()
    if s == 1
        firstmpresult = print_single_mp(polt, asmpt_inner, ppt_inner, svt_inner, ift_inner, pvcft_inner)
        CSV.write("$output_file_path$curr_run\\firstmpresult_innerproj_$(inner_proj_loop)_$prod_code.csv", firstmpresult)
    end

    result = zeros(Float64, proj_len+1) |> ZerobasedIndex!
    result[0:mp.pol_proj_len] = pvcft_inner.pv_cf[0:mp.pol_proj_len] ./ svt_inner.pol_if[0:mp.pol_proj_len]
    return result
end

function run_product(prod_code::String, runset::RunSet)
    
    # Set current run number for print directory

    curr_run = runset.RunNumber
    
    # Read all model points for the product into DataFrame

    model_point_df = CSV.read("$(modelpoints_file_path)mp_$prod_code.csv", DataFrame,  dateformat="dd/mm/YYYY")
    
    # Read product features into product features set
    
    product_features_set = ProductFeatureSet(assumption_set_df, "Product Feature", prod_code)
    validate_formula_variables(product_features_set, update_prodfeatset=true, failed_prodfeatures=nothing)
    
    # Read assumptions into assumption sets for Base Projection, Valuation and Capital Requiremnet Inner Projections

    base_asmpset = AssumptionSet(assumption_set_df, "Base Projection", prod_code)
    valn_asmpset = AssumptionSet(assumption_set_df, "Valuation", prod_code)
    capreq_asmpset = AssumptionSet(assumption_set_df, "Capital Requirement", prod_code)
    
    # initialize for printing results

    firstmpresult = DataFrame()
    resultbyproduct = DataFrame()

    # Display current product and size of the model points
    
    println("$(prod_code): $(size(model_point_df))")

    for s in 1:size(model_point_df)[1]
        
        # Read Model Point

        mp = ModelPoint(model_point_df, s)
        
        # Initiatize and Load Policy Information Table
        polt = PolicyInfoTable(mp.dur_valdate, mp.issue_age, mp.prem_mode)
        
        # Initialize Assumptions, Per Policy, Survivalship, In Force, Present Value Tables
        
        asmpt = AssumptionsTable()
        ppt = PerPolicyCFTable()
        svt = SurvivalshipTable()
        ift = InForceCFTable()
        pvcft = PVCFTable()

        # Read Assumptions for Base Projection into Assumption Table

        read_mortality!(asmpt, input_tables_dict, mp, polt, base_asmpset, runset)
        read_lapse!(asmpt, input_tables_dict, mp, polt, base_asmpset, runset)
        read_expense!(asmpt, input_tables_dict, polt, base_asmpset, runset)
        read_disc_rate!(asmpt, input_tables_dict, polt, base_asmpset, runset)
        read_invt_return!(asmpt, input_tables_dict, polt, base_asmpset, runset)
        read_prem_tax!(asmpt, input_tables_dict, polt, base_asmpset)
        read_tax!(asmpt, input_tables_dict, polt, base_asmpset)
             
        # Read Product Features into Per Policy Table

        project_per_policy_with_product_features!(ppt, input_tables_dict, mp, polt.pol_year, polt.duration, polt.modal_cf_indicator, product_features_set)
        
        # Read Assumptions into Per Policy Table

        project_per_policy_with_assumptions!(ppt, asmpt)

        # Calculate decrement using assumptions and store in Survivalship Table

        project_survivalship!(svt, asmpt, mp.pol_term, mp.dur_valdate)
        
        # Apply decrement from Survivalship Table to Per Policy Table and store in In Force Table

        project_in_force_bef_resv_capreq!(ift, ppt, svt)

        # Apply Discounting to In Force Table and store in Present Value of Cashflow Table

        project_present_value_bef_resv_capreq!(pvcft, ift, asmpt.disc_rate_mth)

        # Run Projection for Reserve Per Policy using Valuation Assumptions Set
        
        project_per_policy_reserve!(ppt, polt, input_tables_dict, mp, valn_asmpset, s, prod_code, runset)
        
        # Run Projection for Capital Requirement Per Policy using Capital Requiremnt Assumptions Set

        project_per_policy_capreq!(ppt, polt, input_tables_dict, mp, capreq_asmpset, s, prod_code, runset)

        # Project In force Cash Flow and Present Value for and after increase in Reserves and Capital Requirements

        project_in_force_inc_resv_capreq!(ift, asmpt, ppt, svt)
        project_present_value_inc_resv_capreq!(pvcft, ift, asmpt.disc_rate_mth)
        
        # Print result by product

        if s == 1
            firstmpresult = print_single_mp(polt, asmpt, ppt, svt, ift, pvcft)
            CSV.write("$output_file_path$curr_run\\firstmpresult_$prod_code.csv", firstmpresult)
            resultbyproduct = print_aggregate_result(polt.date, ppt, svt, ift, pvcft)
        else
            agg_result = print_aggregate_result(polt.date, ppt, svt, ift, pvcft)
            resultbyproduct[:, Not(:date)] .+= copy(agg_result[:, Not(:date)])
        end

    end
    
    # Save results to CSV files - by product
    CSV.write("$output_file_path$curr_run\\result_$prod_code.csv", resultbyproduct)
    println(now()-start)        

end
