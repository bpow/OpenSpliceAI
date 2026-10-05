# Copilot instructions

See `CLAUDE.md` for the full architecture overview and conventions.

## Docker
- `Dockerfile` uses micromamba with conda-forge/bioconda; the CUDA runtime comes from conda packages, so there is no nvidia base image. Build args: `TORCH_VARIANT=cuda|cpu`, `CUDA_VERSION` (driver major version), `KERAS=1` to add TensorFlow.
- KERAS is a build arg, not a stage: adding TensorFlow re-solves and downgrades pytorch, which would duplicate the torch layer.
- The package is installed editable at `/opt/openspliceai` because `variant`'s default Keras model path is resolved relative to the repo root.
- The conda dependency list mirrors `conda-recipe/meta.yaml`; `pip check` in the build catches drift from `setup.py`.
