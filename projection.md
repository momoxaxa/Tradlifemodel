@def title = "Projection"

## How a policy is projected

Every month-indexed array is 0-based: index `0` = valuation date, index `t` = `t` months
into the projection. The horizon is fixed at 120 years.

1. **Policy timeline** — date, duration, projection year, policy year, attained age, modal cash flow indicator.
2. **Read assumptions** — mortality, lapse, expense, discount rate, investment return, premium tax, tax. Apply *Mult × run adjustment × PAD*; convert annual rates to monthly.
3. **Per-policy cash flows** — premium (only in modal payment months), commission, expenses, death and surrender benefit.
4. **Survivorship** — decrement by mortality → lapse → maturity at end of term.
5. **In-force cash flows** — scale per-policy cash flows by the appropriate survivorship.
6. **Present values** — discount BOP items and EOP items with correct timing.
7. **Reserve inner projection** — using Valuation assumptions, run lapse-up and lapse-down; take the higher present value.
8. **Capital requirement inner projection** — same lapse up / down pattern with Capital Requirement assumptions; gross up by `(1 + Capital Requirement Gross Up Factor)`.
9. **Post-reserve cash flows and PVs** — investment return on reserves and on capital, change in reserve and capital, tax, profit metrics.
10. **Aggregate** — add this policy's monthly totals into the product-level result DataFrame.

For the first model point in each product, `Print.jl` also writes
`firstmpresult_<PROD>.csv` + `firstmpresult_innerproj_*.csv` (4 scenarios, for reconciliation).

## Three assumption sets per product

Every product configuration carries three assumption sets that reference shared tables.
Base Projection drives the primary cash flow projection; Valuation and Capital Requirement
drive the two inner projections.

| Set | Assumptions | Used in |
|---|---|---|
| **Base Projection** | mortality, lapse, expense, discount rate, investment return, premium tax, tax | Primary cash flow projection |
| **Valuation** | mortality, lapse, expense, discount rate, premium tax **+ PAD per assumption** | Gross Premium Valuation reserve inner projection |
| **Capital Requirement** | mortality, lapse, expense, discount rate, premium tax **+ PAD per assumption** | Risk-Based Capital inner projection |

PAD is multiplicative for mortality / lapse / expense (`(1 + PAD) × rate`) and additive
for discount rate.

## Multiplicative vs additive run adjustments

Run Settings adjustments overlay on top of the product-level configuration:

- **Mortality, lapse, expense** — multiplicative (base = `1`; `1.1` = +10% stress)
- **Discount rate, investment return** — additive shifts in decimal units (base = `0`; `-0.01` = −100 bps)

Effective rate = `table × product_mult × run_adjustment` (multiplicative), or
`table × product_mult + run_adjustment` (additive).

## Output files (per run)

| File | Contents |
|---|---|
| `result_<PROD>.csv` | Portfolio aggregates by month for one product |
| `result_allproducts.csv` | Sum across successful products in the run |
| `firstmpresult_<PROD>.csv` | Full per-column detail for the first model point |
| `firstmpresult_innerproj_<scenario>_<PROD>.csv` | Inner projection detail (lapse-up / lapse-down for reserve and capital requirement) |
| `run_log.txt` | Invocation-level log (validation, per-product failures, timings) |

Column selection is controlled by `Input/print_option.json` — variables can be toggled on
and off without changing code.
