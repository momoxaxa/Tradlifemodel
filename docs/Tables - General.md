+++
title = "Tables - General"
+++

**Tables** are CSV files stored in `Input/Tables/`. Each table CSV starts with three header comment lines, each a `#Key: Value` pair, e.g.:
```
#Table Type: Attained Age
#Table Category: mortality
#Table Details: Attained Age Unisex Mortality Table
```

These headers are scanned on startup and validated against `Input/table_type_defn.json`; tables with unrecognised or malformed headers are skipped with a warning.

`Input/table_type_defn.json` defines every valid `Table Category`/`Table Type` combination — a table whose header doesn't match a recognised pair is excluded entirely. For each combination it also defines the expected shape (vector, matrix, or user defined; row/column counts; row and column labels), which is what the **Table Setup** page's grid editor uses to render the correct rows and columns when you create or edit a table of that type.

There are two ways to manage a table: through the web UI, or directly in the CSV file.

## Web UI

The **Table Setup** page supports the full lifecycle:
- **Add**: click **+ Add New**, choose a category, and fill in the metadata and grid.
- **Update**: select a table from the list and edit its values directly in the grid.
- **Delete**: select a table, then click **Delete**.

## CSV File

- **Add**: create a new CSV file in `Input/Tables/`, named after the table (e.g. `LAPSE02.csv`), with the three `#Key: Value` header lines followed by the table data.
- **Update**: edit the CSV file directly.
- **Delete**: remove the CSV file.

Either way, reference the table by name (the filename without `.csv`) from the relevant product's **Product Setup** page or `Input/Products/<PROD>.json`.
