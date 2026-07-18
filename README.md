# TradLifeModel

TradLifeModel is a Julia-based actuarial modelling tool for traditional life 
insurance products that ships with a Genie-based web UI for configuration 
and monitoring, and can also be run directly from the command line.


## Installation

Install Julia from <https://julialang.org/downloads/>, then from the project root:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```


## Running

**Web UI** — from the project root:

```bash
cd app
julia --project=.. app.jl
```

Then open <http://localhost:8888>.

**CLI** (equivalent to clicking **Run Model** on the Run Monitor page):

```bash
cd src
julia --threads auto --project=.. TradLifeModel.jl
```

Output lands in `Output/<yyyy-mm-dd_HHMMSS>/<Run>/`. Each timestamped folder is one
**invocation** — one press of Run Model or one CLI command — and contains one subfolder
per enabled run (`Run01/`, `Run02/`, ...), each holding the per-product result CSVs.

Configuration (tables, products, runs, general settings) is done through the UI or by
editing JSON files under `Input/`.


## Repository layout

```
TradLifeModel/
├── Input/
│   ├── Products/PROD*.json       Per-product feature and assumption config
│   ├── Tables/*.csv              Product feature / assumption tables (with metadata headers)
│   ├── general_settings.json     Global run parameters
│   ├── print_option.json         Selects which result columns are written
│   ├── run_settings.json         Named runs with assumption adjustments
│   └── table_type_defn.json      Table type schema
├── MP/mp_<PROD>.csv              Model point files (one per product)
├── Output/<timestamp>/           Timestamped run outputs (one folder per invocation)
├── app/                          Genie web UI
│   ├── app.jl                    Server entry (port 8888)
│   ├── pages/*.jl                One module per page
│   └── public/{css,js}/          Static assets
└── src/                          Julia model source
    ├── Assumptions.jl            Reads mortality, lapse, expense, rates, taxes
    ├── DataStruct.jl             Projection struct types
    ├── Print.jl                  Output CSV writer
    ├── ProductFeatures.jl        Premium, death benefit, surrender benefit, commission
    ├── Projection.jl             Per-policy projection + reserve/capreq inner projections
    ├── Settings.jl               Loads JSON configs and CSV tables
    ├── TableMeta.jl              CSV metadata headers and table discovery
    ├── TradLifeModel.jl          Runs × products loop (entry point)
    └── Utils.jl                  Table readers, PV utility, UDF evaluator
```


## Architecture


### File map

```mermaid
flowchart TD
    T["<b>TradLifeModel.jl</b><br/>Orchestrator<br/>runs × products loop"]
    S["<b>Settings.jl</b><br/>loads JSON configs<br/>& CSV tables"]
    TM["<b>TableMeta.jl</b><br/>CSV metadata headers<br/>+ table discovery"]
    D["<b>DataStruct.jl</b><br/>projection struct types"]
    U["<b>Utils.jl</b><br/>table readers, PV,<br/>UDF evaluator"]
    PF["<b>ProductFeatures.jl</b><br/>premium, DB, SB,<br/>commission"]
    A["<b>Assumptions.jl</b><br/>mortality, lapse,<br/>expense, rates, taxes"]
    P["<b>Projection.jl</b><br/>per-policy projection<br/>+ reserve/capreq<br/>inner projections"]
    PR["<b>Print.jl</b><br/>output CSV writer"]

    T --> P
    T --> S
    S --> TM
    P --> PF
    P --> A
    P --> D
    P --> U
    P --> PR
    PF --> U
    A --> U
```


### End-to-end execution flow

```mermaid
flowchart TD
    S[Load JSON configs & CSV tables] --> V{Validate selected products}
    V -->|missing table| X[Log & exclude]
    V -->|OK| L1
    X --> L1[For each enabled Run]
    L1 --> L2["For each valid Product<br/>(parallel if multithreading)"]
    L2 --> RP[run_product]
    RP --> LM["For each Model Point:<br/>project one policy"]
    LM --> AG[Accumulate → product result]
    AG --> LM
    LM --> W1["Write result_&lt;PROD&gt;.csv"]
    W1 --> L2
    L2 --> W2["Combine successful products<br/>→ result_allproducts.csv"]
    W2 --> L1
```


### How a policy is projected

Every month-indexed array is 0-based: index `0` = valuation date, index `t` = `t` months
into the projection. The horizon is fixed at 120 years.

```mermaid
flowchart TD
    S1["<b>1. Policy timeline</b><br/>date, duration, pol year,<br/>att age, modal indicator"]
    S2["<b>2. Read assumptions</b><br/>mort, lapse, expense, disc rate,<br/>invt return, prem tax, tax<br/><i>apply Mult × run adj × PAD</i><br/><i>annual → monthly</i>"]
    S3["<b>3. Per-policy cash flows</b><br/>premium (modal), commission,<br/>expenses, death & surrender benefit"]
    S4["<b>4. Survivorship</b><br/>decrement by mortality → lapse<br/>+ maturity at end of term"]
    S5["<b>5. In-force cash flows</b><br/>scale per-policy by survivorship"]
    S6["<b>6. Present values</b><br/>discount BOP items and EOP items<br/>with correct timing"]
    S7["<b>7. Reserve inner projection</b><br/>Valuation assumptions<br/>max(lapse-up PV, lapse-down PV)"]
    S8["<b>8. Capital requirement</b><br/>Capital Requirement assumptions<br/>max(lapse-up, lapse-down) × (1 + gross-up)"]
    S9["<b>9. Post-reserve cash flows & PVs</b><br/>+ invt return on reserves & capital,<br/>tax, profit metrics"]
    S10["<b>10. Aggregate</b><br/>add to product result DataFrame"]

    S1 --> S2 --> S3 --> S4 --> S5 --> S6 --> S7 --> S8 --> S9 --> S10
```

For the first model point in each product, `Print.jl` also writes
`firstmpresult_<PROD>.csv` + `firstmpresult_innerproj_*.csv` (4 scenarios, for reconciliation).


### Three assumption sets per product

Every product configuration carries three assumption sets that reference shared tables. 
Base Projection drives the primary cash flow; Valuation and Capital Requirement drive
inner projections.

```mermaid
flowchart LR
    PROD["Product JSON"] --> B["<b>Base Projection</b>"]
    PROD --> V["<b>Valuation</b>"]
    PROD --> C["<b>Capital Requirement</b>"]
    B --> B1["mortality, lapse, expense<br/>disc rate, invt return<br/>prem tax, tax"]
    V --> V1["mortality, lapse, expense<br/>disc rate, prem tax<br/><b>+ PAD per assumption</b>"]
    C --> C1["mortality, lapse, expense<br/>disc rate, prem tax<br/><b>+ PAD per assumption</b>"]
```

PAD is multiplicative for mortality / lapse / expense and additive for discount rate.


### Multiplicative vs additive run adjustments

Run Settings adjustments overlay on top of the product-level configuration:

- **Mortality, lapse, expense** — multiplicative (base = `1`; `1.1` = +10% stress)
- **Discount rate, investment return** — additive shifts in decimal units
  (base = `0`; `-0.01` = −100 bps)

Effective rate =  `table × product_mult × run_adjustment` (multiplicative) or
`table × product_mult + run_adjustment` (additive).


### User-defined formulas

Product features (premium, death benefit, surrender benefit, commission) can be specified
as a formula string over the columns of a user-defined table. Formulas are parsed once to
a Julia `Expr` and walked by a restricted evaluator that supports only
`+  −  *  /  ^  %` plus `min` / `max`.


### Table discovery and validation

Each CSV in `Input/Tables/` starts with `#Table Type`, `#Table Category`,
`#Table Details` comment lines. On startup, these headers are scanned and validated
against `Input/table_type_defn.json`; unrecognised or malformed files are skipped with a
warning. Before any run starts, each selected product is checked for unresolved table
references — products with missing tables are excluded from the invocation and logged.


### Multithreading and error isolation

Runs are looped sequentially; products within a run execute in parallel Julia tasks when
multithreading is enabled and Julia is started with more than one thread. Log writes are
serialised through a lock. If a single product fails, its stack trace is captured in
`run_log.txt`, that product is excluded from the run's combined result, and all other
products and runs continue.


## Output files (per run)

| File | Contents |
|---|---|
| `result_<PROD>.csv` | Portfolio aggregates by month for one product |
| `result_allproducts.csv` | Sum across successful products in the run |
| `firstmpresult_<PROD>.csv` | Full per-column detail for the first model point |
| `firstmpresult_innerproj_<scenario>_<PROD>.csv` | Inner projection detail (lapse-up / lapse-down for reserve & capreq) |
| `run_log.txt` | Invocation-level log (validation, per-product failures, timings) |

Column selection is controlled by `Input/print_option.json` — variables can be toggled on
and off without changing code.