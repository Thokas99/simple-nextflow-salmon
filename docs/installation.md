# Installation

Install Java 17+, Nextflow `>=24.10.0`, and one supported runtime.

## Conda/Micromamba

The `conda` profile asks Nextflow to create the pinned environment in `envs/salmon-rnaseq.yml`. Micromamba is enabled by default.

```bash
nextflow run . -profile conda --samplesheet samplesheet.csv --reference_dir /data/reference/raw
```

## Docker

After the matching release workflow publishes the image:

```bash
nextflow run . -profile docker --samplesheet samplesheet.csv --reference_dir /data/reference/raw
```

The transparent [`Containerfile`](../Containerfile) builds the same Conda environment.

## Dependency policy

Dependencies are pinned intentionally. Salmon remains 2.3.4 for 0.3.1 to avoid an unreviewed quantification change. Upgrades require compatibility review, the real miniature workflow, documentation, and a release note; mutable `latest` tags are not used.
