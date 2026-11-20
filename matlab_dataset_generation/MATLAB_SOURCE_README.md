# MATLAB dataset-generation source

These are the **original, unmodified** MATLAB source files extracted from the supplied research archive.
They cover the synthetic DC dataset generation for IEEE-14, IEEE-118 and IEEE-300,
including matched Normal, FDIA, TLO, CCPA-Full and CCPA-Partial trajectories,
RTU/PMU measurement imperfections, state-estimation evidence and source exports.

## Prerequisites
- MATLAB (the manuscript reports R2025b)
- MATPOWER (the manuscript reports version 8.0), installed and on the MATLAB path

## Entry points
- `MATLAB/ieee14/generate_ieee14_dataset.m`
- `MATLAB/ieee118/generate_ieee118_dataset.m`
- `MATLAB/ieee300/generate_ieee300_dataset.m`

Keep the `MATLAB/` hierarchy intact when extracting the archive; each script
adds the neighboring `shared_functions/` directory to its MATLAB path.
Run one generator from a writable working directory with MATPOWER already on
MATLAB's path. The generators output files and may require substantial disk
space and compute for their full 300-base-state configurations.

**Important:** `T_WIN = 20` appears in the generator as a legacy window-export
setting, but `EXPORT_WINDOWS = false`; final T=30 causal windows were generated
in the separate Python preprocessing/training pipeline, which is **not**
part of this limited repository. MATLAB output files, trained model weights,
train/validation/test split and evaluation implementations, and exact
end-to-end experiment reproduction are not included. No MATLAB runtime
execution was performed during preparation of this package.
