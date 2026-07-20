@def title = "Overview"

# Model (`src/`)

The `src/` folder contains the core Julia model — projection logic, data structures,
assumption handling, and CSV I/O. `TradLifeModel.jl` is the entry point; every other file
is pulled in via `include`.

## src/ file map

| File | Role |
|---|---|
| `TradLifeModel.jl` | Runs × products loop |
| `Settings.jl` | Loads JSON configs and CSV tables |
| `TableMeta.jl` | CSV metadata headers and table discovery |
| `DataStruct.jl` | Projection struct types |
| `Utils.jl` | Table readers, present value utility, UDF evaluator |
| `ProductFeatures.jl` | Premium, death benefit, surrender benefit, commission |
| `Assumptions.jl` | Mortality, lapse, expense, rates, taxes |
| `Projection.jl` | Per-policy projection + reserve / capital requirement inner projections |
| `Print.jl` | Output CSV writer |

## End-to-end execution flow

1. Load JSON configs and CSV tables.
2. Validate selected products; skip and log any with missing tables.
3. For each enabled Run:
   1. For each valid Product (in parallel Julia tasks when multithreading is enabled):
      1. Read `MP/mp_<PROD>.csv`.
      2. For each Model Point: project one policy and accumulate into the product result.
      3. Write `result_<PROD>.csv`.
   2. Combine successful products into `result_allproducts.csv`.

## Multithreading and error isolation

Runs are looped sequentially; products within a run execute in parallel Julia tasks when
multithreading is enabled and Julia is started with more than one thread. Log writes are
serialised through a lock. If a single product fails, its stack trace is captured in
`run_log.txt`, that product is excluded from the run's combined result, and all other
products and runs continue.

## User-defined formulas

Product features (premium, death benefit, surrender benefit, commission) can be specified
as a formula string over the columns of a user-defined table. Formulas are parsed once
into a Julia `Expr` and walked by a restricted evaluator that supports only
`+ − * / ^ %` plus `min` / `max`.

## Table discovery and validation

Each CSV in `Input/Tables/` starts with `#Table Type`, `#Table Category`,
`#Table Details` comment lines. On startup, these headers are scanned and validated
against `Input/table_type_defn.json`; unrecognised or malformed files are skipped with a
warning. Before any run starts, each selected product is checked for unresolved table
references — products with missing tables are excluded from the invocation and logged.
