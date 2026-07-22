+++
title = "Projection"
+++

The model calculates a base cashflow projection which calls for multiple inner loops to calculate policy liabilities and capital requirement. The projection cashflow has been segregated and represented by various data structs. The projection flow through various projection functions where the inner loops reuse these data structs. Run sets are overlaid on top to allow sensitivities on assumptions to be applied.

Data Structs used to represent "components" of the projection cashflow:
   - Policy Information
   - Assumptions
   - Per Policy Cashflow
   - Survivorship
   - In Force Cashflow
   - Present Value of Cashflow

Other Data Struct used:
   - Product Feature Set

   - Assumption Sets 
      - Base 
      - Valuation 
      - Capital Requirement 

   - Run Sets
      - 20 sensitivity runs allowing adjustment to Base, Valuation and Capital Requirement assumptions

The flow of the projection is structured as follows:
1. Iterate through selected runs and load run set for each selected run
2. Iterate through selected products
3. For each product:
   - Read all model points into DataFrame
   - Load product feature set and validate its User Defined Formula variables
   - Load assumption sets for base projection, reserving and capital requirement inner projections
4. For each model point:
   - Load model point
   - Load policy information tables
   - Load assumptions tables
   - Project Per Policy Table with product feature set
   - Project Per Policy Table with base assumption set
   - Project survivorship
   - Project in force cash flow before reserve and capital requirement
   - Project present value of in force cash flow before reserve and capital requirement
   - Project reserve per policy based on reserving assumption set
   - Project capital requirement per policy based on capital requirement assumption set
   - Project in force cash flow for increase in reserve and capital requirement
   - Project present value for increase in reserve and capital requirement

Error isolation
- Before any run starts, each selected product is checked for unresolved table references — products with missing tables are excluded from the run and logged. The checks do not cover table reference in mapping tables, which may still cause a runtime failure.

- If a single product fails, its stack trace is captured in `run_log.txt`, that product is excluded from the run's combined result, and all other products and runs continue — a failure in one product's projection doesn't stop the rest.