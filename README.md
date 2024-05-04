## Actuarial Projection for Traditional Life Insurance Products

This program is written in Julia Programming Language and can be used to perform actuarial projection for traditional life insurance products. The program offers basic functionality, however, you may modify or add additional features to cater for your specific requirements.

### Inputs:

- `Settings.xlsx`
- `Tables.xlsx`
- Model Points (one CSV file per product)

### Settings:

`Settings.xlsx` contains the following configurable parameters:

1. General Settings
   - Valuation Date
   - Projection Years
   - Capital Requirement Gross up Factor
   - Number of Workers for Multiprocessing
   - Products to run
2. Run Settings
   - Run Indicator
   - Run Descriptions
   - Adjustment to apply on existing assumptions (e.g. for sensitivity and scenario testing purposes)
3. Product Setup & Table Listings
   - Each column represents a product
   - Copy an existing column to a new column to create a new product
   - Select or enter the inputs for Projection Type/Variable and Data Type for the new product
   - Table selection is restricted by Table listings
   - Table listings is linked to `Tables.xlsx` for up to 20 tables and should be updated after `Tables.xlsx` is updated
4. Print Option
   -  Variables to print can be adjusted here

### Tables:

1. Tables
   - Tables are stored in `Tables.xlsx` for product features and assumptions
2. Steps to add new tables:
   - open `Tables.xlsx` 
   - copy an existing sheet for the relevant table category (e.g. `lapse`)
   - name the new sheet with the table name
   - update the new sheet 
   - update the corresponding table listing sheet for the new table (e.g. after adding a new lapse table `LAPSE02`, go to `lapse` sheet, in the next empty row, enter the fields `Table Name` with `LAPSE02` and `Table Details` and `Table Type` accordingly)

### Outputs:

- First model point results of each product for base and inner projections
- Aggregate results by product
- Aggregate results for all products

Currently, two products and four runs are set up.

### Main Data Structures Used:

- Model Points
- Product Feature Sets
- Assumption Sets
- Run Sets
- Projection Tables:
   - Policy Information
   - Assumptions
   - Per Policy Cashflow
   - Survivalship
   - In Force Cashflow
   - Present Value of Cashflow
  
### Program Workflow:

1. Iterate through selected runs based on run settings
2. Iterate through selected products based on general settings
3. For each product:
   - Read all model points into DataFrame
   - Load product feature set
   - Load assumption sets for base projection and reserving and capital requirement inner projections
4. For each model point:
   - Load the model point
   - Project policy information tables
   - Project assumptions tables based on base projection assumption set
   - Project Per Policy Table with product feature set
   - Project Per Policy Table with assumption tables
   - Project survivalship
   - Project in force cash flow before reserve and capital requirement
   - Project present value of in force cash flow before reserve and capital requirement
   - Project reserve per policy based on reserving assumption set
   - Project capital requirement per policy based on capital requirement assumption set
   - Project in force cash flow and present value for and after increase in reserve and capital requirement

### Running the Program:

To run the program:

1. Clone or download this repository to your local machine.
2. Navigate to the directory where the program is located.
3. Open a command prompt.
4. Run the Julia script `TradLifeModel.jl` using the following command:
   
   ```
   julia src/TradLifeModel.jl
   ```

### Note:

Thank you for your interest in this program. Please be aware that the program has not been tested beyond value checks against the reference spreadsheet, so errors may occur.
