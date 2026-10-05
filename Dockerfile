# OpenSpliceAI container images.
#
#   podman build -t openspliceai:pytorch .                          # PyTorch only
#   podman build --build-arg KERAS=1 -t openspliceai:keras .        # + TensorFlow for --model-type keras
#   podman build --build-arg TORCH_VARIANT=cpu ...                  # CPU-only (much smaller)
#
# KERAS is a build arg rather than a separate stage because adding TensorFlow re-solves
# (and downgrades) pytorch, so a stacked stage would duplicate the multi-GB torch layer.
#
# The package is always installed from the build context (the current checkout), so a
# dev build is just `podman build .`; check out a release tag first for a release image.
# conda-recipe/meta.yaml is not used directly: it builds a pinned PyPI sdist, which lacks
# models/ and data/.
#
# conda-forge CUDA builds ship the CUDA runtime as packages, so no nvidia/cuda base is
# needed — only the NVIDIA container toolkit on the host (run with --gpus all, or
# --device nvidia.com/gpu=all under podman/CDI).

ARG MICROMAMBA_TAG=2-debian12-slim

FROM docker.io/mambaorg/micromamba:${MICROMAMBA_TAG}

ARG PYTHON_VERSION=3.12
ARG TORCH_VARIANT=cuda
# No GPU at build time, so tell the solver the hosts' driver CUDA major version
# (conda-forge then picks the newest compatible 12.x runtime).
ARG CUDA_VERSION=12
ARG KERAS=0
# Podman's default OCI format ignores micromamba's activating SHELL, so put the env on PATH.
ENV PATH=/opt/conda/bin:$PATH

# Mirrors the run: requirements in conda-recipe/meta.yaml. `pip check` below fails the
# build if setup.py's install_requires drift from this list.
# TF >= 2.16 defaults to Keras 3; tf-keras + TF_USE_LEGACY_KERAS keeps
# `from tensorflow import keras` on Keras 2 for the legacy SpliceAI .h5 files.
RUN if [ "$KERAS" = 1 ]; then set -- "tensorflow[build='${TORCH_VARIANT}*']" tf-keras; fi \
    && CONDA_OVERRIDE_CUDA=${CUDA_VERSION} micromamba install -y -n base \
        -c conda-forge -c bioconda \
        "python=${PYTHON_VERSION}" \
        "pytorch[version='>=2.3.0',build='${TORCH_VARIANT}*']" \
        "numpy>=2.0.0" \
        "pandas>=2.2.2" \
        "h5py>=3.9.0" \
        "tqdm>=4.65.2" \
        "scikit-learn>=1.4.1" \
        "biopython>=1.83" \
        "matplotlib-base>=3.8.3" \
        "psutil>=5.9.2" \
        "pysam>=0.22.0" \
        "pyfaidx>=0.8.1.1" \
        "gffutils>=0.12" \
        "mappy>=2.28" \
        pip setuptools wheel \
        "$@" \
    && micromamba clean -a -f -y
ENV TF_USE_LEGACY_KERAS=1

WORKDIR /opt/openspliceai
COPY --chown=$MAMBA_USER:$MAMBA_USER setup.py README.md MANIFEST.in LICENSE ./
COPY --chown=$MAMBA_USER:$MAMBA_USER openspliceai/ openspliceai/
COPY --chown=$MAMBA_USER:$MAMBA_USER models/ models/
COPY --chown=$MAMBA_USER:$MAMBA_USER data/ data/

# Editable so the package's repo_root is /opt/openspliceai: variant's default Keras model
# path (_resolve_default_spliceai_models) is resolved relative to it.
# With KERAS=1, the original SpliceAI weights (CC BY-NC 4.0) come from Illumina's package
# and are linked to where that function looks for them.
RUN pip install --no-deps --no-build-isolation --no-cache-dir -e . \
    && if [ "$KERAS" = 1 ]; then \
        pip install --no-deps --no-cache-dir spliceai \
        && ln -s "$(python -c 'import importlib.util as u; print(u.find_spec("spliceai").submodule_search_locations[0])')/models" \
            models/spliceai/SpliceAI_models_release; \
    fi \
    && pip check

ENV OPENSPLICEAI_MODELS=/opt/openspliceai/models \
    MPLBACKEND=Agg
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/_entrypoint.sh", "openspliceai"]
CMD ["--help"]
