@def title = "TradLifeModel"

Actuarial Modelling Tool for Traditional Life Insurance Products — a Julia-based tool that
projects monthly cash flows and computes liabilities (Gross Premium Reserves and Risk-Based
Capital) on portfolios of traditional life insurance policies. Ships with a Genie-based
web UI for configuration and monitoring, and can also be run directly from the command
line.

## Quick start

Install Julia from [julialang.org/downloads](https://julialang.org/downloads/), then from
the project root:

```
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Start the web UI:

```
cd app
julia --project=.. app.jl
```

Then open [http://localhost:8888](http://localhost:8888).

For a headless run (equivalent to clicking **Run Model** on the Run Monitor page):

```
cd src
julia --threads auto --project=.. TradLifeModel.jl
```

Output lands in `Output/<yyyy-mm-dd_HHMMSS>/<Run>/`. Each timestamped folder is one
**invocation** — one press of Run Model or one CLI command — and contains one subfolder
per enabled run (`Run01/`, `Run02/`, ...), each holding the per-product result CSVs.
