FROM condaforge/miniforge3:26.5.3-0

LABEL org.opencontainers.image.source="https://github.com/Thokas99/simple-nextflow-salmon" \
      org.opencontainers.image.version="0.5.0" \
      org.opencontainers.image.description="Dependencies for simple-nextflow-salmon 0.5.0"

COPY envs/salmon-rnaseq.yml /tmp/environment.yml
RUN conda env create -p /opt/sns -f /tmp/environment.yml && conda clean --all --yes
ENV PATH="/opt/sns/bin:${PATH}"
