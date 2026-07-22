+++
title = "Runs"
+++

There are two ways to run the model: through the web UI, or from the command line.

## Web UI

```
cd app
julia --project=.. app.jl
```

Then open [http://localhost:8888](http://localhost:8888) and use the **Run Monitor** page to start a run and stream the live log.

## Command line

```
cd src
julia --threads auto --project=.. TradLifeModel.jl
```

`--threads auto` enables multithreading so `(run, product)` pairs can execute in parallel (see **General Settings** to toggle multithreading on/off, and **Multithreading** for details).

See **Outputs and Print Option** for where results are saved and what's in each file.

## Validating Formulas Separately

Formula variables are validated automatically as part of every run, so no separate step is required — but if you'd rather check User Defined Formulas across all selected products before committing to a full run, you can run that same check standalone:

```
cd src
julia --project=.. ValidateUDF.jl
```
