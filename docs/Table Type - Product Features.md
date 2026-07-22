+++
title = "Table Type - Product Features"
+++

## Premium
- `Rate per 1000 SA by Age/Pol Term` — rate per 1000 Sum Assured, looked up by Issue Age and Policy Term and applied for the life of the policy; multiplied by Model Point Sum Assured
- `Mult to MP Premium by Duration` — multiple looked up by Policy Year; multiplied by Model Point Premium
- `User Defined Table` — evaluates a formula you define over columns of the user defined table you choose

## Death Benefit
- `Mult to MP SA by Duration` — multiple looked up by Policy Year; multiplied by Model Point Sum Assured
- `User Defined Table` — evaluates a formula you define over columns of the user defined table you choose

## Surrender Benefit
- `Rate per 1000 SA by Year/Age` — rate per 1000 Sum Assured, looked up by Policy Year and Issue Age; multiplied by Model Point Sum Assured
- `User Defined Table` — evaluates a formula you define over columns of the user defined table you choose

## Commission
- `Perc by Pol Year/Pol Term` — percentage looked up by Policy Year, using the column matching the model point's Policy Term; multiplied by the computed Premium
- `User Defined Table` — evaluates a formula you define over columns of the user defined table you choose

User Defined Formulas are validated automatically at the start of every run — checking that any User Defined Table referenced has all the variables used in its formula.
