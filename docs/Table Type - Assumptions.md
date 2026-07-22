+++
title = "Table Type - Assumptions"
+++

## Mortality
- `Attained Age` — one rate per Attained Age, applied to all model points regardless of sex or smoker status
- `Attained Age Sex Distinct` — one rate per Attained Age, applied according to each model point's sex
- `Attained Age Sex Smoker Distinct` — one rate per Attained Age, applied according to each model point's sex and smoker status
- `Select and Ultimate` — select-and-ultimate mortality, applied to all model points regardless of sex or smoker status
- `Select and Ultimate - Sex Distinct` — select-and-ultimate mortality, applied according to each model point's sex
- `Select and Ultimate - Sex Smoker Distinct` — select-and-ultimate mortality, applied according to each model point's sex and smoker status
- `Select and Ultimate - Sex Distinct - SOA Table ID` — select-and-ultimate mortality read from the MortalityTables.jl package (JuliaActuary.org), applied according to each model point's sex
- `Select and Ultimate - Sex Smoker Distinct - SOA Table ID` — select-and-ultimate mortality read from the MortalityTables.jl package (JuliaActuary.org), applied according to each model point's sex and smoker status

## Lapse
- `Pol Year/Pol Term` — rate looked up by Policy Year, using the column matching the model point's Policy Term

## Expense
- `Policy Year` — the table must have `acq_exp_per_pol`, `acq_exp_perc_prem`, `maint_exp_per_pol`, `maint_exp_perc_prem` columns, each looked up by Policy Year

## Discount Rate
- `Projection Year` — rate indexed by years since the valuation date (the same timeline for every policy, regardless of issue date)
- `Calendar Year` — rate indexed by the actual calendar year of each projected month
- `Mix of Prj Year and Cal Year` — looks up a secondary interest rate table where each column can independently be indexed by Projection Year or Calendar Year

## Investment Return
- `Projection Year` — rate indexed by years since the valuation date (the same timeline for every policy, regardless of issue date)
- `Calendar Year` — rate indexed by the actual calendar year of each projected month
- `Mix of Prj Year and Cal Year` — looks up a secondary interest rate table where each column can independently be indexed by Projection Year or Calendar Year

## Premium Tax
- `Scalar` — a single constant rate applied across the whole projection
- `Policy Year` — rate looked up by Policy Year

## Tax
- `Scalar` — a single constant rate applied across the whole projection
- `Policy Year` — rate looked up by Policy Year
