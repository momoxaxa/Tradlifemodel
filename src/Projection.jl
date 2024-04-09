"""
project_per_policy_with_product_features!(ppt::PerPolicyCFTable, input_tables_dict::Dict, mp::ModelPoint, pol_year, duration, modal_cf_indicator, product_features_set)
project_per_policy_with_assumptions!(ppt::PerPolicyCFTable, asmpt:: AssumptionsTable)
project_survivalship!(svt::SurvivalshipTable, asmpt:: AssumptionsTable, pol_term, curr_dur)
project_in_force_bef_resv_capreq!(ift::InForceCFTable, ppt::PerPolicyCFTable, svt::SurvivalshipTable)
project_present_value_bef_resv_capreq!(pvcft::PVCFTable, disc_rate::Array, ift::InForceCFTable)
project_present_value_outgo_net_income!(pvcft::PVCFTable)

project_per_policy_reserve!(ppt::PerPolicyCFTable, polt::PolicyInfoTable, input_tables_dict::Dict, mp::ModelPoint, valn_asmpset::AssumptionSet, s::Integer, prod_code::String, runset::RunSet, valn_method::String="Gross Premium Valuation")

project_per_policy_capreq!(ppt::PerPolicyCFTable, polt::PolicyInfoTable, input_tables_dict::Dict, mp::ModelPoint, capreq_asmpset::AssumptionSet, s::Integer, prod_code::String, runset::RunSet, capreq_method::String="Risk Based Capital")

project_in_force_inc_resv_capreq!(ift::InForceCFTable, asmpt::AssumptionsTable, ppt::PerPolicyCFTable, svt::SurvivalshipTable)
project_present_value_inc_resv_capreq!(pvcft::PVCFTable, disc_rate::Array, ift::InForceCFTable)

inner_proj(curr_asmpset::AssumptionSet, base_asmpset::AssumptionSet, polt::PolicyInfoTable, ppt::PerPolicyCFTable, asmpt::AssumptionsTable, input_tables_dict::Dict, mp::ModelPoint, s::Integer, prod_code::String, inner_proj_loop::String)

run_product(prod_code::String)

"""

function project_per_policy_with_product_features!(ppt::PerPolicyCFTable, input_tables_dict::Dict, mp::ModelPoint, pol_year, duration, modal_cf_indicator, product_features_set)
    
    # Premium Per Policy

    ppt.premium_pp = fill(mp.init_prem, proj_len) .* modal_cf_indicator

    # Sum Assured Per Policy

    ppt.sum_assured_pp = fill(mp.init_sum_assured, proj_len)

    # Death Benefit Per Policy

    ppt.death_ben_pp = death_benefit(input_tables_dict, mp.init_sum_assured, pol_year, duration, product_features_set)

    # Surrender Benefit Per Policy

    ppt.surr_ben_pp = surr_benefit(input_tables_dict, mp.init_sum_assured, pol_year, duration, product_features_set)

    # Commission Per Policy

    ppt.comm_pp = comm_rate(input_tables_dict, pol_year, duration, product_features_set) .* ppt.premium_pp

end

function project_per_policy_with_assumptions!(ppt::PerPolicyCFTable, asmpt:: AssumptionsTable)
    
    # Acquisition Expense Per Policy

    ppt.acq_exp_pp = asmpt.acq_exp_per_pol .+ asmpt.acq_exp_perc_prem .* ppt.premium_pp

    # Maintenance Expense Per Policy

    ppt.maint_exp_pp = asmpt.maint_exp_per_pol .+ asmpt.maint_exp_perc_prem .* ppt.premium_pp

    # Premium Tax Per Policy

    ppt.prem_tax_pp = asmpt.prem_tax_rate .* ppt.premium_pp

end

function project_survivalship!(svt::SurvivalshipTable, asmpt:: AssumptionsTable, pol_term, curr_dur)

    # Survivalship

    for k in 1:proj_len
        if k == 1
            svt.pol_if[k] = 1
        else
            svt.pol_if[k] = svt.pol_if[k-1] - svt.pol_death[k-1] - svt.pol_lapse[k-1] - svt.pol_maturity[k-1]
        end       

        svt.pol_death[k] = svt.pol_if[k] * asmpt.mort_rate_mth[k]
        svt.pol_lapse[k] = (svt.pol_if[k] - svt.pol_death[k]) * asmpt.lapse_rate_mth[k]
        
        if k == pol_term*12 - curr_dur + 1
            svt.pol_maturity[k] = svt.pol_if[k] - svt.pol_death[k] - svt.pol_lapse[k]
        end
    end

end

function project_in_force_bef_resv_capreq!(ift::InForceCFTable, ppt::PerPolicyCFTable, svt::SurvivalshipTable)

    # In Force Cashflow

    ift.premium_if = ppt.premium_pp .* svt.pol_if
    ift.prem_tax_if = ppt.prem_tax_pp .* svt.pol_if
    ift.comm_if = ppt.comm_pp .* svt.pol_if
    ift.acq_exp_if = ppt.acq_exp_pp .* svt.pol_if
    ift.maint_exp_if = ppt.maint_exp_pp .* svt.pol_if
    ift.death_ben_if = ppt.death_ben_pp .* svt.pol_death
    ift.surr_ben_if = ppt.surr_ben_pp .* svt.pol_lapse

end

function project_present_value_bef_resv_capreq!(pvcft::PVCFTable, ift::InForceCFTable, disc_rate_mth::Array)

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

        ppt.resv_pp[1:mp.pol_proj_len] = max.(resv_pp_lapse_up[1:mp.pol_proj_len], resv_pp_lapse_down[1:mp.pol_proj_len])

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
        ppt.capreq_pp = max.(capreq_lapse_up, capreq_lapse_down) .* (1 + capreq_grossup_factor)
    end

end

function project_in_force_inc_resv_capreq!(ift::InForceCFTable, asmpt::AssumptionsTable, ppt::PerPolicyCFTable, svt::SurvivalshipTable)

    # In Force Cashflow

    ift.resv_if = ppt.resv_pp .* svt.pol_if
    ift.inc_resv_if = append!(ift.resv_if[2:end], 0) - ift.resv_if
    ift.invt_return_if = (
        ift.premium_if 
        .- ift.comm_if 
        .- ift.prem_tax_if 
        .- ift.acq_exp_if 
        .- ift.maint_exp_if 
        .+ ift.resv_if
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
    ift.inc_capreq_if = append!(ift.capreq_if[2:end], 0) - ift.capreq_if
    ift.invt_return_on_capreq_if = ift.capreq_if .* asmpt.invt_ret_mth
    ift.tax_on_invt_return_on_capreq_if = ift.invt_return_on_capreq_if .* asmpt.tax_rate
    ift.prof_aft_tax_capreq_if = (
        ift.prof_aft_tax_bef_capreq_if 
        .- ift.inc_capreq_if 
        .+ ift.invt_return_on_capreq_if 
        .- ift.tax_on_invt_return_on_capreq_if
    )

end

function project_present_value_inc_resv_capreq!(pvcft::PVCFTable, ift::InForceCFTable, disc_rate_mth::Array)

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

    read_mortality!(asmpt_inner, input_tables_dict, mp.sex, polt.att_age, curr_asmpset, runset)
    read_lapse!(asmpt_inner, input_tables_dict, polt.pol_year, polt.duration, curr_asmpset, runset)
    read_expense!(asmpt_inner, input_tables_dict, polt.pol_year, polt.duration, curr_asmpset, runset)
    read_disc_rate!(asmpt_inner, input_tables_dict, polt.pol_year, polt.duration,curr_asmpset, runset)
    read_invt_return!(asmpt_inner, input_tables_dict, polt.pol_year, polt.duration, curr_asmpset, runset)
    read_prem_tax!(asmpt_inner, input_tables_dict, polt.pol_year, polt.duration, curr_asmpset)

    project_per_policy_with_assumptions!(ppt_inner, asmpt_inner)
    project_survivalship!(svt_inner, asmpt_inner, mp.pol_term, mp.curr_dur)
    project_in_force_bef_resv_capreq!(ift_inner, ppt_inner, svt_inner)
    project_present_value_bef_resv_capreq!(pvcft_inner, ift_inner, asmpt_inner.disc_rate_mth)
    project_present_value_outgo_net_income!(pvcft_inner)

    # function print_innerproj_result()
    if s == 1
        firstmpresult = print_single_mp(polt, asmpt_inner, ppt_inner, svt_inner, ift_inner, pvcft_inner)
        CSV.write("$output_file_path$curr_run\\firstmpresult_innerproj_$(inner_proj_loop)_$prod_code.csv", firstmpresult)
    end

    result = zeros(Float64, proj_len)
    result[1:mp.pol_proj_len] = pvcft_inner.pv_cf[1:mp.pol_proj_len] ./ svt_inner.pol_if[1:mp.pol_proj_len]
    return result
end

function run_product(prod_code::String, runset::RunSet)
    
    # Set current run number for print directory

    curr_run = runset.RunNumber
    
    # Read all model points for the product into DataFrame

    model_point_df = CSV.read("$(modelpoints_file_path)mp_$prod_code.csv", DataFrame,  dateformat="dd/mm/YYYY")
    
    # Read assumptions into assumption sets for Base Projection, Valuation and Capital Requiremnet Inner Projections
    
    product_features_set = ProductFeatureSet(assumption_set_df, "Product Feature", prod_code)
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
        
        polt = PolicyInfoTable(mp.curr_dur, mp.iss_age, mp.prem_mode)
        
        # Initialize Assumptions, Per Policy, Survivalship, In Force, Present Value Tables
        
        asmpt = AssumptionsTable()
        ppt = PerPolicyCFTable()
        svt = SurvivalshipTable()
        ift = InForceCFTable()
        pvcft = PVCFTable()

        # Read Assumptions for Base Projection into Assumption Table

        read_mortality!(asmpt, input_tables_dict, mp.sex, polt.att_age, base_asmpset, runset)
        read_lapse!(asmpt, input_tables_dict, polt.pol_year, polt.duration, base_asmpset, runset)
        read_expense!(asmpt, input_tables_dict, polt.pol_year, polt.duration, base_asmpset, runset)
        read_disc_rate!(asmpt, input_tables_dict, polt.pol_year, polt.duration, base_asmpset, runset)
        read_invt_return!(asmpt, input_tables_dict, polt.pol_year, polt.duration, base_asmpset, runset)
        read_prem_tax!(asmpt, input_tables_dict, polt.pol_year, polt.duration, base_asmpset)
        read_tax!(asmpt, input_tables_dict, polt.pol_year, polt.duration, base_asmpset)
             
        # Read Product Features into Per Policy Table

        project_per_policy_with_product_features!(ppt, input_tables_dict, mp, polt.pol_year, polt.duration, polt.modal_cf_indicator, product_features_set)
        
        # Read Assumptions into Per Policy Table

        project_per_policy_with_assumptions!(ppt, asmpt)

        # Calculate decrement using assumptions and store in Survivalship Table

        project_survivalship!(svt, asmpt, mp.pol_term, mp.curr_dur)
        
        # Apply decrement from Survivalship Table to Per Policy Table and store in In Force Table

        project_in_force_bef_resv_capreq!(ift, ppt, svt)

        # Apply Discounting to In Force Table and store in Present Value of Cashflow Table

        project_present_value_bef_resv_capreq!(pvcft, ift, asmpt.disc_rate_mth)

        # Calculate PV of Outgo net Income

        project_present_value_outgo_net_income!(pvcft)

        # Run Projection for Reserve Per Policy using Valuation Assumptions Set
        
        project_per_policy_reserve!(ppt, polt, input_tables_dict, mp, valn_asmpset, s, prod_code, runset)
        
        # Run Projection for Capital Requirement Per Policy using Capital Requiremnt Assumptions Set

        project_per_policy_capreq!(ppt, polt, input_tables_dict, mp, capreq_asmpset, s, prod_code, runset)

        # Project In force Cash Flow and calculate Present Value for increase in Reserves and Capital Requirements

        project_in_force_inc_resv_capreq!(ift, asmpt, ppt, svt)   # to split
        project_present_value_inc_resv_capreq!(pvcft, ift, asmpt.disc_rate_mth)   # to split
        
        # Calculate PV of outgo net income (#to change to income net outgo aka profit)
        
        project_present_value_outgo_net_income!(pvcft)
        
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
