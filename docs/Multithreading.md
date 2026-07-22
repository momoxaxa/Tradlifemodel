+++
title = "Multithreading"
+++

Multithreading lets `(run, product)` pairs execute in parallel, rather than one at a time.

## Enabling it

 **General Settings** allows the multithreading to be turned on and off. 

To enable Multithreading, Julia needs to be started with more than one thread:

```
julia --threads auto --project=.. TradLifeModel.jl
```

## How it works

- **Multithreading on**: every selected `(run, product)` pair becomes its own task, and all of them — across every run, not just within one — are dynamically scheduled across the available threads at once. Runs don't wait for each other to finish; a task from a later run can complete before an earlier run's tasks do.
- **Multithreading off**: runs and products execute strictly sequentially, in a fixed, deterministic order — useful for debugging.
- Log writes are serialised through a lock, so concurrent tasks don't interleave or corrupt `run_log.txt`.

