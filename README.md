## Actuarial Projection for Traditional Life Insurance Products

This Julia program performs actuarial projection for traditional life insurance products based on the following inputs and generates corresponding outputs:

### Inputs:
- Inputs for Product Features and Assumptions (one Excel file per product)
- Model Points (one CSV file per product)

### Outputs:
- First model point results of each product for base and inner projections
- Aggregate results by product
- Aggregate results for all products

Currently, two products are set up.

### Data Structures Used:

- Model Points
- Assumptions Sets
- Policy Information Projection Tables
- Assumptions Projection Tables
- Per Policy Cashflow Projection Tables
- Survivalship Projection Tables
- In Force Cashflow Projection Tables
- Present Value of Cashflow Projection Tables
  
### Program Workflow:

1. Loop through all products
2. For each product, loop through all model points
3. For each model point:
   - Load model point and perform necessary calculations
   - Load assumptions sets
   - Project assumptions
   - Project per policy cash flow before reserve and capital requirement
   - Project survivalship
   - Project in force cash flow before reserve and capital requirement
   - Project present value of in force cash flow before reserve and capital requirement
   - Project reserve per policy with reserving assumptions
   - Project capital requirement per policy with capital requirement assumptions
   - Project in force cash flow for increase in reserve and capital requirement 
   - Project present value of in force cash flow for increase in reserve and capital requirement

### Running the Program:

To run the program:

1. Clone or download this repository to your local machine.
2. Navigate to the directory where the program is located.
3. Open a command prompt.
4. Run the Julia script `main.jl` using the following command:
   
   ```
   julia src/main.jl
   ```

### Configurable Parameters:

`Settings.jl` contains the following configurable parameters:

- File Paths
- Selected Products
- Valuation Date
- Projection Years
- Multiprocessing Indicator and Number of Workers
- Gross up Factor to arrive at Total Capital Requirement

Settings.xlsx - Print options for CSV output file can be adjusted here. 


### Note:

The program has not been tested except for value checks against the checking spreadsheet, so errors may occur. If you have any suggestions, bug fixes, or improvements, please feel free to open a pull request or raise an issue on GitHub.

Thank you for checking out this program.