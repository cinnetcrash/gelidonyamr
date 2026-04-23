FROM mambaorg/micromamba:1.5.8

LABEL maintainer="Gültekin Ünal"
LABEL description="GelidonyAMR — Salmonella Infantis genomic epidemiology pipeline"

USER root

# System dependencies needed by some bioinformatics tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        wget \
        procps \
        git \
    && rm -rf /var/lib/apt/lists/*

USER $MAMBA_USER

WORKDIR /app

# Copy the main conda environment spec
COPY --chown=$MAMBA_USER:$MAMBA_USER environment.yaml ./environment.yaml

# Install all packages from environment.yaml into the base micromamba env
# (excludes chewBBACA, clair3, poppunk which are in separate images)
RUN micromamba install -y -n base -f environment.yaml \
    && micromamba clean --all --yes

ENV PATH="/opt/conda/bin:${PATH}"

# Copy pipeline files
COPY --chown=$MAMBA_USER:$MAMBA_USER main.nf        ./main.nf
COPY --chown=$MAMBA_USER:$MAMBA_USER modules/       ./modules/
COPY --chown=$MAMBA_USER:$MAMBA_USER config/        ./config/
COPY --chown=$MAMBA_USER:$MAMBA_USER data/          ./data/
