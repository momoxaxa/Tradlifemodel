# TradLifeModel

## 0. Installing Julia

## 1. Running the Genie web UI to update settings and set up products
- Download and install Julia from the official website:
```
  https://julialang.org/downloads/
```

## 1. Installing project packages

- From the project root, run:
```bash
  julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

  This reads the `Project.toml` and `Manifest.toml` at the project root and installs all required packages into the shared environment. You only need to do this once, or again after the manifest is updated.

## 2. Opening Genie web UI to set up tables, products, update settings, run the model and monitor the progress

- From the project root, navigate to the `app` folder:
```bash
@ -18,14 +33,14 @@
   http://localhost:8888
```

## 2. Running the actuarial calculation
## 3. Alternatively, running the actuarial model at terminal

- From the project root, navigate to the `src` folder:
```bash
   cd src
```

- Run the actuarial calculation:
- Run the actuarial model:
```julia
   julia --project=.. tradlifemodel.jl
```
