"""

read_mortality!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet, runset::RunSet)
read_lapse!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet, runset::RunSet)
read_expense!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet, runset::RunSet)
read_disc_rate!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet, runset::RunSet)
read_invt_return!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet, runset::RunSet)
read_other_assumptions!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, sex::String, att_age::Array, curr_asmpset::AssumptionSet)

"""

# Read mortality assumptions from select and ultimate table
function read_sel_ult_mort(mort_table, mp::ModelPoint, polt::PolicyInfoTable)
    sel_ult_vector = mort_table.select[mp.issue_age]
    sel_ult_vector = Array(OffsetArray(sel_ult_vector, OffsetArrays.Origin(1)))
    sel_ult_vector = repeat(sel_ult_vector, inner=12)[polt.duration[1]:end]
    if length(sel_ult_vector) < proj_len
        annual_rate = append!(sel_ult_vector, zeros(Float64, proj_len - length(sel_ult_vector)))
    else
        annual_rate = sel_ult_vector[1:proj_len]
    end
    return annual_rate
end

# Create select and ultmate mortality table
function create_sel_ult_table(df)
    ult_start_age = df[1, "Attained Age"]
    ult_end_age = maximum(dropmissing(df, :"Attained Age")[:, "Attained Age"])
    ult_end_age_loc = findfirst(df[:, "Attained Age"] .== ult_end_age)
    ult_vector = Vector{Float64}(df[1:ult_end_age_loc, "Ultimate"])
    ult = UltimateMortality(ult_vector; start_age = ult_start_age)

    sel_start_age = df[1, 1]
    sel_end_age = maximum(dropmissing(df, 1)[:, 1])
    sel_end_age_loc = findfirst(df[:, 1] .== sel_end_age)
    sel_matrix = Matrix(df[1:sel_end_age_loc, 2:end-2])
    sel = SelectMortality(sel_matrix, ult, start_age=sel_start_age)
    
    mort_table = MortalityTable(sel,ult)
    return mort_table
end

# Read mortality assumptions

function read_mortality!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, mp::ModelPoint, polt::PolicyInfoTable, curr_asmpset::AssumptionSet, runset::RunSet)         
    df = input_tables_dict[curr_asmpset.mortality.table]
    annual_rate = zeros(proj_len)

    if curr_asmpset.projtype == "Base Projection"
        adj = runset.BaseProjMort
    elseif curr_asmpset.projtype == "Valuation"
        adj = runset.ValnMort
    elseif curr_asmpset.projtype == "Capital Requirement"
        adj = runset.CapReqMort
    end
    
    mult = curr_asmpset.mortality.mult * adj
    
    if curr_asmpset.mortality.table_type == "Attained Age"
        annual_rate = read_excel_AA(df, "Unisex", polt.att_age) * mult

    elseif curr_asmpset.mortality.table_type == "Attained Age Sex Distinct"
        annual_rate = read_excel_AA(df, mp.sex, polt.att_age) * mult

    elseif curr_asmpset.mortality.table_type == "Attained Age Sex Smoker Distinct"
        annual_rate = read_excel_AA(df, string(mp.sex, " ", mp.smoker), polt.att_age) * mult

    elseif curr_asmpset.mortality.table_type == "Select and Ultimate"
        mort_table = create_sel_ult_table(df)
        annual_rate = read_sel_ult_mort(mort_table, mp, polt) * mult

    elseif curr_asmpset.mortality.table_type == "Select and Ultimate - Sex Distinct"
        mort_table_name = filter(row ->row."Class" == mp.sex, df)[1, "Mort Table Name"]
        mort_table_df = input_tables_dict[mort_table_name]
        mort_table = create_sel_ult_table(mort_table_df)
        annual_rate = read_sel_ult_mort(mort_table, mp, polt) * mult

    elseif curr_asmpset.mortality.table_type == "Select and Ultimate - Sex Smoker Distinct"
        mort_table_name = filter(row ->row."Class" == string(mp.sex, " ", mp.smoker), df)[1, "Mort Table Name"]
        mort_table_df = input_tables_dict[mort_table_name]
        mort_table = create_sel_ult_table(mort_table_df)
        annual_rate = read_sel_ult_mort(mort_table, mp, polt) * mult

    elseif curr_asmpset.mortality.table_type == "Select and Ultimate - Sex Distinct - SOA Table ID"
        mort_table_id = filter(row ->row."Class" == mp.sex, df)[1, "SOA Table ID"]
        mort_table = MortalityTables.table(mort_table_id)
        annual_rate = read_sel_ult_mort(mort_table, mp, polt) * mult
        
    elseif curr_asmpset.mortality.table_type == "Select and Ultimate - Sex Smoker Distinct - SOA Table ID"
        mort_table_id = filter(row ->row."Class" == string(mp.sex, " ", mp.smoker), df)[1, "SOA Table ID"]
        mort_table = MortalityTables.table(mort_table_id)
        annual_rate = read_sel_ult_mort(mort_table, mp, polt) * mult
    end
    
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

function read_lapse!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, mp::ModelPoint, polt::PolicyInfoTable, curr_asmpset::AssumptionSet, runset::RunSet)         
    df = input_tables_dict[curr_asmpset.lapse.table]

    if curr_asmpset.projtype == "Base Projection"
        adj = runset.BaseProjLapse
    elseif curr_asmpset.projtype == "Valuation"
        adj = runset.ValnLapse
    elseif curr_asmpset.projtype == "Capital Requirement"
        adj = runset.CapReqLapse
    end

    mult = curr_asmpset.lapse.mult * adj
    if curr_asmpset.lapse.table_type == "Pol Year/Pol Term"
        annual_rate = read_excel_PY(df, string(mp.pol_term), polt.pol_year, polt.duration) * mult
    elseif curr_asmpset.lapse.table_type == "Pol Year/Pol Term/Prem Term"
        annual_rate = read_excel_PY_MI(input_tables_dict[curr_asmpset.lapse.table], mp.pol_term, mp.prem_term, "Value", polt.pol_year)
    end
    
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

function read_expense!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, polt::PolicyInfoTable, curr_asmpset::AssumptionSet, runset::RunSet)

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
            assumptions_array = read_excel_PY(df, assumption, polt.pol_year, polt.duration) * mult
        elseif assumption == "acq_exp_per_pol"
            assumptions_array = read_excel_PY(df, assumption, polt.pol_year, polt.duration, "BOP") * mult
        elseif assumption == "maint_exp_per_pol"
            assumptions_array = read_excel_PY(df, assumption, polt.pol_year, polt.duration, "EvenlySpreadOut") * mult
        end

        PAD = curr_asmpset.expense.PAD            
        if PAD !== missing
            assumptions_array = (1+PAD) * assumptions_array
        end

        setfield!(curr_asmpt, Symbol(assumption), assumptions_array)

    end
end

# Read discount rate assumptions

function read_disc_rate!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, polt::PolicyInfoTable, curr_asmpset::AssumptionSet, runset::RunSet)         
    df = input_tables_dict[curr_asmpset.disc_rate.table]
    annual_rate = zeros(proj_len)

    if curr_asmpset.projtype == "Base Projection"
        adj = runset.BaseProjDiscRate
    elseif curr_asmpset.projtype == "Valuation"
        adj = runset.ValnDiscRate
    elseif curr_asmpset.projtype == "Capital Requirement"
        adj = runset.CapReqDiscRate
    end
        
    mult = curr_asmpset.disc_rate.mult

    if curr_asmpset.disc_rate.table_type == "Prj Year"
        annual_rate = read_excel_PRJY_CY(df, curr_asmpset.disc_rate.table_column, polt.proj_year) * mult .+ adj
    elseif curr_asmpset.disc_rate.table_type == "Cal Year"
        annual_rate = read_excel_PRJY_CY(df, curr_asmpset.disc_rate.table_column, year.(polt.date)) * mult .+ adj
    elseif curr_asmpset.disc_rate.table_type == "Mix of Prj Year and Cal Year"
        int_table_name = filter(row -> row."Class" == curr_asmpset.disc_rate.table_column, df)[1, "Interest Rate Table Name"]
        int_table_df = input_tables_dict[int_table_name]
 
        year_index_type = filter(row -> row."Class" == curr_asmpset.disc_rate.table_column, df)[1, "Prj Year/Cal Year"]
        year_index =    if year_index_type == "Calendar Year"
                            year.(polt.date)
                        elseif year_index_type == "Projection Year"
                            polt.proj_year
                        end
        
        annual_rate = read_excel_PRJY_CY(int_table_df, curr_asmpset.disc_rate.table_column, year_index * mult) .+ adj
    end
    
    PAD = curr_asmpset.disc_rate.PAD 
    if PAD !== missing
        annual_rate = PAD .+ annual_rate
    end

    assumptions_array = (1 .+ annual_rate).^(1/12) .- 1
    setfield!(curr_asmpt, :disc_rate_ann, annual_rate)
    setfield!(curr_asmpt, :disc_rate_mth, assumptions_array) 

end

# Read investment return assumptions

function read_invt_return!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, polt::PolicyInfoTable, curr_asmpset::AssumptionSet, runset::RunSet)         
    df = input_tables_dict[curr_asmpset.disc_rate.table]
    annual_rate = zeros(proj_len)

    if curr_asmpset.projtype == "Base Projection"
        adj = runset.BaseProjInvtRet

        mult = curr_asmpset.invt_return.mult
        
        if curr_asmpset.invt_return.table_type == "Prj Year"
            annual_rate = read_excel_PRJY_CY(df, curr_asmpset.invt_return.table_column, polt.proj_year) * mult .+ adj
        elseif curr_asmpset.invt_return.table_type == "Cal Year"
            annual_rate = read_excel_PRJY_CY(df, curr_asmpset.invt_return.table_column, year.(polt.date)) * mult .+ adj
        elseif curr_asmpset.disc_rate.table_type == "Mix of Prj Year and Cal Year"
            int_table_name = filter(row ->row."Class" == curr_asmpset.invt_return.table_column, df)[1, "Interest Rate Table Name"]
            int_table_df = input_tables_dict[int_table_name]

            year_index_type = filter(row ->row."Class" == curr_asmpset.invt_return.table_column, df)[1, "Prj Year/Cal Year"]
            year_index =    if year_index_type == "Calendar Year"
                                year.(polt.date)
                            elseif year_index_type == "Projection Year"
                                polt.proj_year
                            end

            annual_rate = read_excel_PRJY_CY(int_table_df, curr_asmpset.invt_return.table_column, year.(polt.date)) * mult .+ adj
        end
    
        assumptions_array = (1 .+ annual_rate).^(1/12) .- 1
        setfield!(curr_asmpt, :invt_ret_ann, annual_rate)
        setfield!(curr_asmpt, :invt_ret_mth, assumptions_array)
    end
end

# Read premium tax assumptions

function read_prem_tax!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, polt::PolicyInfoTable, curr_asmpset::AssumptionSet)
    
    df = input_tables_dict[curr_asmpset.prem_tax.table]
    mult = curr_asmpset.prem_tax.mult

    if curr_asmpset.prem_tax.table_type == "Scalar"
        assumptions_array = read_excel_ind(df) * ones(proj_len) * mult
    elseif curr_asmpset.prem_tax.table_type == "Policy Year"
        assumptions_array = read_excel_PY(df, "Value", polt.pol_year, polt.duration) * mult
    end
    setfield!(curr_asmpt, :prem_tax_rate, assumptions_array)

end

# Read tax assumptions

function read_tax!(curr_asmpt::AssumptionsTable, input_tables_dict::Dict, polt::PolicyInfoTable, curr_asmpset::AssumptionSet)

    df = input_tables_dict[curr_asmpset.tax.table]
    mult = curr_asmpset.tax.mult

    if curr_asmpset.tax.table_type == "Scalar"
        assumptions_array = read_excel_ind(df) * ones(proj_len) * mult
    elseif curr_asmpset.tax.table_type == "Policy Year"
        assumptions_array = read_excel_PY(df, "Value", polt.pol_year, polt.duration) * mult
    end
    setfield!(curr_asmpt, :tax_rate, assumptions_array)

end