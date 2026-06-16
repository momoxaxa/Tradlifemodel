# TradLifeModel


## 1. Running the Genie web UI to update settings and set up products

- From the project root, navigate to the `app` folder:
```bash
   cd app
```

- Start the web server:
```julia
   julia --project=.. app.jl
```

- Once running, open browser and go to:
```
   http://localhost:8888
```

## 2. Running the actuarial calculation

- From the project root, navigate to the `src` folder:
```bash
   cd src
```

- Run the actuarial calculation:
```julia
   julia --project=.. tradlifemodel.jl
```
