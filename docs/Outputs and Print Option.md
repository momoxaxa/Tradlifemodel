+++
title = "Outputs and Print Option"
+++

Each run creates a new timestamped folder under `Output/<yyyy-mm-dd_HHMMSS>/`. Each folder is one **invocation** — one press of Run Model or one CLI command — and contains one subfolder per enabled run (`Run01/`, `Run02/`, ...).

**Output Files** are saved as CSV in each run's folder, viewable through the web UI's **Run Result** page.

## Full Model Point Details

Full per-column detail for the first model point of each product:
- `firstmpresult_<PROD>.csv`
- `firstmpresult_innerproj_valn_lapse_up_<PROD>.csv`, `firstmpresult_innerproj_valn_lapse_down_<PROD>.csv`, `firstmpresult_innerproj_capreq_lapse_up_<PROD>.csv`, `firstmpresult_innerproj_capreq_lapse_down_<PROD>.csv` — inner projection detail (lapse-up / lapse-down, for both the valuation and capital requirement loops)

## Aggregate Results

- `result_<PROD>.csv` — aggregate results by product
- `result_allproducts.csv` — aggregate results summed across all successful products in the run

## Run Log

`run_log.txt`, at the invocation root, holds the run-level log (validation, per-product failures, timings).

## Print Option

Controls which variables are included in the **Aggregate Results** files (`result_<PROD>.csv`, `result_allproducts.csv`) — edited directly in `Input/print_option.json` (there's no web UI for this). Each entry has:
- `Variable` — the field name
- `Struct` — which internal table it comes from (`polt`, `asmpt`, `ppt`, `svt`, `ift`, `pvcft`)
- `Print` — `"Yes"` or `"No"`, whether to include it in the aggregate files

The `firstmpresult` files always include every variable listed here, regardless of `Print`.
