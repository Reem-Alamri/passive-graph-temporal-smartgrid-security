# Passive Graph–Temporal Multi-Task Detection and Localization of Coordinated Cyber–Physical Attacks in Smart Grids

**Authors:** Reem Alamri, Ohoud AlZamzami, Kawthar Moria  
**Manuscript:** Submitted to *Sensors* (MDPI), 2026; not yet published.  
**Repository scope:** Core PyTorch model source and MATLAB dataset-generation source (partial release).

## Manuscript reference

Alamri, R.; AlZamzami, O.; Moria, K. *Passive Graph–Temporal Multi-Task Detection and Localization of Coordinated Cyber–Physical Attacks in Smart Grids.* Manuscript submitted to *Sensors*, 2026.

> This is a **pre-publication manuscript reference**, not a citation to a published article. No journal volume, pages, or DOI have been assigned in this repository. Please update this reference if the paper is published.

### BibTeX (pre-publication)

```bibtex
@unpublished{Alamri2026PassiveGraphTemporal,
  author = {Alamri, Reem and AlZamzami, Ohoud and Moria, Kawthar},
  title  = {Passive Graph--Temporal Multi-Task Detection and Localization of Coordinated Cyber--Physical Attacks in Smart Grids},
  year   = {2026},
  note   = {Manuscript submitted to Sensors (MDPI)}
}
```

## About this repository

This repository contains a **limited release of the core neural-network source and MATLAB dataset-generation scripts** associated with the above manuscript.

The study considers five-class Attack-Type Detection and multi-label Cyber Bus
and Physical Line Localization for the synthetic DC IEEE-14, IEEE-118 and
IEEE-300 smart-grid benchmark systems.

## Included files

| File | Content |
|---|---|
| `core_model.py` | Source-derived PyTorch graph–temporal neural architecture and the three-task loss objective (Eq. 18). |
| `matlab_dataset_generation.zip` | **Original MATLAB generation source**, with three case-specific dataset-generation scripts and their 38 supporting MATLAB functions. It contains **no generated datasets**. |
| `README.md` | Scope, dependencies and limitations. |
| `.gitignore` | Excludes local datasets, generated outputs, weights and temporary files. |

### PyTorch core

The Python file was **refactored from the supplied research source modules** to
make the architecture self-contained, without altering the reported
parameter-bearing structure. It represents the topology-aware bus/line
encoders, temporal GRUs, endpoint fusion, local line attention, global context,
physics-consistency line correction and three prediction heads. The source
includes the three-task loss expression with the 0.10 false-alarm and 0.18
ranking regularization weights. The module retains the original
parameter-bearing auxiliary components so the standard IEEE-14/IEEE-118 model
still has **341,142 trainable parameters**.

Dependencies: Python 3.11, PyTorch (original experiments: 2.5.1), NumPy.
Inputs must be preprocessed in the format described in the manuscript. In the
final experiment the causal window is T=30; input feature dimensions are
(24 node, 35 branch) for IEEE-14 and IEEE-118, and (27 node, 36 branch)
for IEEE-300. The preprocessor is not included.

### MATLAB generation source

The bundled MATLAB files are the **unmodified original source** from the
provided research archive, including their required helper functions. They
cover matched five-scenario power-system trajectories, RTU/PMU measurements,
synthetic attack construction and measurement imperfections, state estimation,
and data export. The three generation entry points are:

- `MATLAB/ieee14/generate_ieee14_dataset.m`
- `MATLAB/ieee118/generate_ieee118_dataset.m`
- `MATLAB/ieee300/generate_ieee300_dataset.m`

Download and extract `matlab_dataset_generation.zip` to inspect the individual
`.m` files and preserve their original subdirectory structure. For use,
MATLAB (manuscript: R2025b) and MATPOWER (manuscript: 8.0) must be installed,
with MATPOWER on the MATLAB path. Further notes appear in the README inside
the MATLAB archive.

The MATLAB generators export raw trajectories; **the final T=30 model inputs
were prepared through a separate Python preprocessing pipeline, not included
here.** Some generation files retain a legacy `T_WIN=20` setting for a disabled
window-export path (`EXPORT_WINDOWS=false`); this setting does not describe
the final model's window length.

## Scope and reproducibility limitations

This is a **partial source release, not a complete end-to-end reproduction
package**. It does not include the generated raw/processed datasets, the
training/validation/test split and preprocessing implementation, experiment-
specific training/evaluation entry points, baseline experiments, checkpoint
weights, or frozen prediction artifacts. It therefore **does not claim** to
regenerate all reported manuscript results by itself.

The underlying research materials remain available from the corresponding
author upon reasonable request, as described in the manuscript's Data
Availability Statement.

The repository is intended to remain **private until author approval for
release**. A public license has not been assigned.
