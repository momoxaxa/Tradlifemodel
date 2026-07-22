+++
title = "Model Points"
+++

Model Points are stored one CSV file per product, `MP/mp_<PROD>.csv`, with the following fields:

- pol_id (Policy ID)
- prod_id (Product ID)
- issue_date
- issue_age
- sex
- smoker
- pol_term
- prem_term
- sum_assured
- premium
- premium_mode

There are two ways to manage Model Points: through the web UI, or directly in the CSV file.

## Web UI

The **Model Point** page lets you view a file's contents — up to the first 1,000 rows. There's no add, update, or delete capability here; changes must be made directly in the CSV file.

## CSV File

Add, update, or delete rows by editing `MP/mp_<PROD>.csv` directly.
