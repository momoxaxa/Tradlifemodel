+++
title = "Run Settings"
+++

Run Settings hold a fixed set of **20 run slots** — you toggle and configure the ones you use, but can't add or remove slots.

**Run Indicator**: Enter "Yes" or "No" to indicate if the run should be performed.

**Run Description**: Provide a description for reference, not used in the actual run.

**Base Projection**: Enter the adjustments for Base Projection.

**Valuation**: Enter the adjustments for Valuation.

**Capital Requirement**: Enter the adjustments for Capital Requirement.

Adjustments are multiplicative for mortality, lapse and expense (base = `1`; `1.1` = +10% stress) and additive for discount rate and investment return, in decimal units (base = `0`; `-0.01` = -100 bps).

There are two ways to update Run Settings: through the web UI, or directly in the JSON file.

## Web UI

The **Run Settings** page shows all 20 run slots in a grid where you can toggle **Run Indicator**, set a **Run Description**, and enter adjustments for Base Projection, Valuation, and Capital Requirement. There's no add/delete here — the grid is always exactly 20 rows.

## JSON File

Edit `Input/run_settings.json` directly — same 20 entries by default. Nothing in the model itself enforces exactly 20 (it just reads whatever runs are in the file), so you can add or remove entries here if you need more or fewer than 20 — just note that saving through the web UI afterwards would reset it back to a fixed 20 rows.
