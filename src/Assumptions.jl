"""

read_mortality!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet, runset::RunSet)
read_lapse!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet, runset::RunSet)
read_expense!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet, runset::RunSet)
read_disc_rate!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet, runset::RunSet)
read_invt_return!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet, runset::RunSet)
read_other_assumptions!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet)

"""

# Read mortality assumptions

function read_mortality!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet, runset::RunSet)         
    df = input_tables_dict[curr_asmpset.mortality.table]

    if curr_asmpset.projtype == "Base Projection"
        adj = runset.BaseProjMort
    elseif curr_asmpset.projtype == "Valuation"
        adj = runset.ValnMort
    elseif curr_asmpset.projtype == "Capital Requirement"
        adj = runset.CapReqMort
    end
    
    mult = curr_asmpset.mortality.mult * adj
    annual_rate = read_excel_AA(df, sex, att_age) * mult
    
    PAD = curr_asmpset.mortality.PAD
    if PAD !== missing
        annual_rate = (1+PAD) * annual_rate
    end
    
    annual_rate = min.(annual_rate, 1)
    assumptions_array = 1 .- (1 .- annual_rate).^(1/12)
    setfield!(curr_asmpt, :mort_rate_ann, annual_rate)
    setfield!(curr_asmpt, :mort_rate_mth, assumptions_array)

end

# Read lapse assumptions

function read_lapse!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, pol_year::Array, duration::Array, curr_asmpset::AssumptionSet, runset::RunSet)         
    df = input_tables_dict[curr_asmpset.lapse.table]

    if curr_asmpset.projtype == "Base Projection"
        adj = runset.BaseProjLapse
    elseif curr_asmpset.projtype == "Valuation"
        adj = runset.ValnLapse
    elseif curr_asmpset.projtype == "Capital Requirement"
        adj = runset.CapReqLapse
    end

    mult = curr_asmpset.lapse.mult * adj
    annual_rate = read_excel_PY(df, "lapse_rate", pol_year, duration) * mult
    
    PAD = curr_asmpset.lapse.PAD 
    if PAD !== missing
        annual_rate = (1+PAD) * annual_rate
    end

    annual_rate = min.(annual_rate, 1)
    
    assumptions_array = 1 .- (1 .- annual_rate).^(1/12)
    setfield!(curr_asmpt, :lapse_rate_ann, annual_rate)
    setfield!(curr_asmpt, :lapse_rate_mth, assumptions_array)      

end

# Read expense assumptions

function read_expense!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, pol_year::Array, duration::Array, curr_asmpset::AssumptionSet, runset::RunSet)

    assumptions_array = zeros(Float64, proj_len)
    df = input_tables_dict[curr_asmpset.expense.table]

    for assumption in ["acq_exp_per_pol", "acq_exp_perc_prem", "maint_exp_per_pol", "maint_exp_perc_prem"]    

        if curr_asmpset.projtype == "Base Projection"
            adj = runset.BaseProjExpense
        elseif curr_asmpset.projtype == "Valuation"
            adj = runset.ValnExpense
        elseif curr_asmpset.projtype == "Capital Requirement"
            adj = runset.CapReqExpense
        end
            
        mult = curr_asmpset.expense.mult * adj
        if assumption == "acq_exp_perc_prem" || assumption == "maint_exp_perc_prem"
            assumptions_array = read_excel_PY(df, assumption, pol_year, duration) * mult
        elseif assumption == "acq_exp_per_pol"
            assumptions_array = read_excel_PY(df, assumption, pol_year, duration, "BOP") * mult
        elseif assumption == "maint_exp_per_pol"
            assumptions_array = read_excel_PY(df, assumption, pol_year, duration, "EvenlySpreadOut") * mult
        end

        PAD = curr_asmpset.expense.PAD            
        if PAD !== missing
            assumptions_array = (1+PAD) * assumptions_array
        end

        setfield!(curr_asmpt, Symbol(assumption), assumptions_array)

    end
end

# Read discount rate assumptions

function read_disc_rate!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, pol_year::Array, duration::Array, curr_asmpset::AssumptionSet, runset::RunSet)         
    df = input_tables_dict[curr_asmpset.disc_rate.table]

    if curr_asmpset.projtype == "Base Projection"
        adj = runset.BaseProjDiscRate
    elseif curr_asmpset.projtype == "Valuation"
        adj = runset.ValnDiscRate
    elseif curr_asmpset.projtype == "Capital Requirement"
        adj = runset.CapReqDiscRate
    end
        
    mult = curr_asmpset.disc_rate.mult
    annual_rate = read_excel_PY(df, curr_asmpset.disc_rate.table_column, pol_year, duration) * mult .+ adj
    
    PAD = curr_asmpset.disc_rate.PAD 
    if PAD !== missing
        annual_rate = PAD .+ annual_rate
    end

    assumptions_array = (1 .+ annual_rate).^(1/12) .- 1
    setfield!(curr_asmpt, :disc_rate_ann, annual_rate)
    setfield!(curr_asmpt, :disc_rate_mth, assumptions_array) 

end

# Read investment return assumptions

function read_invt_return!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, pol_year::Array, duration::Array, curr_asmpset::AssumptionSet, runset::RunSet)         
    df = input_tables_dict[curr_asmpset.disc_rate.table]

    if curr_asmpset.projtype == "Base Projection"
        adj = runset.BaseProjInvtRet

        mult = curr_asmpset.invt_return.mult
        
        annual_rate = read_excel_PY(df, curr_asmpset.invt_return.table_column, pol_year, duration) * mult .+ adj
    
        assumptions_array = (1 .+ annual_rate).^(1/12) .- 1
        setfield!(curr_asmpt, :invt_ret_ann, annual_rate)
        setfield!(curr_asmpt, :invt_ret_mth, assumptions_array)
    end
end

# Read premium tax assumptions

function read_prem_tax!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, pol_year::Array, duration::Array, curr_asmpset::AssumptionSet)
    
    assumption = curr_asmpset.prem_tax.table_column
    assumptions_array = zeros(Float64, proj_len)
    df = input_tables_dict[curr_asmpset.prem_tax.table]
    mult = curr_asmpset.prem_tax.mult
    assumptions_array = read_excel_PY(df, assumption, pol_year, duration) * mult
    setfield!(curr_asmpt, Symbol(assumption), assumptions_array)

end

# Read tax assumptions

function read_tax!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, pol_year::Array, duration::Array, curr_asmpset::AssumptionSet)

    assumption = curr_asmpset.tax.table_column
    assumptions_array = zeros(Float64, proj_len)
    df = input_tables_dict[curr_asmpset.tax.table]
    mult = curr_asmpset.tax.mult
    assumptions_array = read_excel_PY(df, assumption, pol_year, duration) * mult
    setfield!(curr_asmpt, Symbol(assumption), assumptions_array)

end