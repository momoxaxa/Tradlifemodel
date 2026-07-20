@def title = "Web UI"

The web UI includes the following pages for working with the model:

1. **Table Setup** — load feature and assumption tables
2. **Product Setup** — configure per-product tables, PADs, and UDFs
3. **Model Point** — review model point CSVs
4. **Run Settings** — define sensitivity runs
5. **General Settings** — valuation date, multithreading, product selection
6. **Run Monitor** — execute the model and stream the live log
7. **Run Result** — browse output CSVs

## app/ file map

| File | Role |
|---|---|
| `app.jl` | Genie server on port 8888; includes and registers each page module |
| `pages/Index.jl` | Welcome page — workflow overview |
| `pages/TableSetup.jl` | Manage feature and assumption tables |
| `pages/ProductSetup.jl` | Per-product configuration (tables, PADs, UDFs) |
| `pages/ModelPoint.jl` | View model point CSVs |
| `pages/RunSettings.jl` | Define sensitivity runs |
| `pages/GeneralSettings.jl` | Valuation date, gross-up factor, product selection |
| `pages/RunMonitor.jl` | Execute the model (spawns `src/TradLifeModel.jl` as a Julia subprocess); stream live log |
| `pages/RunResult.jl` | Browse `Output/`, preview result CSVs |
| `public/css/` | `base.css` + one per page + jspreadsheet, jsuites |
| `public/js/` | jspreadsheet, jsuites |

Configuration (tables, products, runs, general settings) is done through the UI or by
editing JSON files under `Input/`.
