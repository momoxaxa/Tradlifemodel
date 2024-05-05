module ValidateUDF

include("Settings.jl")
include("DataStruct.jl")

println("This script checks if the user defined tables contains all the variables used in user defined formula, for all products and their product features. It will return a list of products with their product features where the validation fails. The errors should be rectified before proceeding to run the program.\n")

# Dictionary to store failed product feature fields for each product

failed_products_dict = Dict()  

for prod_code in selected_products

    # Read product features into product features set
    
    product_features_set = ProductFeatureSet(assumption_set_df, "Product Feature", prod_code)

    # Array to store failed product feature fields

    failed_prodfeatures = []

    # Check that user defined table contains all the variables used in the user defined formula

    validate_formula_variables(product_features_set, update_prodfeatset=false,failed_prodfeatures=failed_prodfeatures)

    if !isempty(failed_prodfeatures)
        failed_products_dict[prod_code] = failed_prodfeatures
    end

end

if isempty(failed_products_dict)
    println("No errors found in variables validation. You may proceed to run the program.")
else
    for (prod_code, failed_products) in failed_products_dict
        println("Variables validation failed for product $prod_code, product feature: $(join(failed_products, ", ")).")
    end
    println("\nPlease check that the user defined table contains all the variables used in the user defined formula.")
end

end