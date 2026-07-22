+++
title = "Product Setup"
+++

Each product is one `Input/Products/<PROD>.json` file.

## Product Features
- Premium
- Death Benefit
- Surrender Benefit
- Commission

Input fields include:
- Mult
- Table
- Table Type (automatically updated from the Table you choose)
- UDF (User Defined Formula)

## Assumptions for Base Projection 
- Mortality
- Lapse
- Expense
- Discount Rate
- Investment Return
- Premium Tax
- Tax

Input fields include:
- Mult
- Table
- Table Type (automatically updated from the Table you choose)
- Table Column (applicable to Discount Rate and Investment Return only)

## Assumptions for Valuation
- Mortality
- Lapse
- Expense
- Discount Rate
- Premium Tax

Input fields include:
- Mult
- Table
- Table Type (automatically updated from the Table you choose)
- Table Column (applicable to Discount Rate only)
- PAD (applicable to Mortality, Lapse, Expense and Discount Rate only)

## Assumptions for Capital Requirement
- Mortality
- Lapse
- Expense
- Discount Rate
- Premium Tax

Input fields for each of the above include:
- Mult
- Table
- Table Type (automatically updated from the Table you choose)
- Table Column (applicable to Discount Rate only)
- PAD (applicable to Mortality, Lapse, Expense and Discount Rate only)

There are two ways to manage a product: through the web UI, or directly in the JSON file.

## Web UI

The **Product Setup** page supports the full lifecycle:
- **Add**: click **+ Add New** to create a product, then fill in its features and assumptions.
- **Update**: select a product and edit its fields directly.
- **Delete**: select a product, then click **Delete**.

## JSON File

- **Add**: copy an existing `Input/Products/<PROD>.json` file to a new file named after the new product code — the product code is taken from the filename, not from a field inside the file.
- **Update**: edit the JSON file directly.
- **Delete**: remove the JSON file.
