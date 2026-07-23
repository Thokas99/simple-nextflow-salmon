# Install

This repository is a Nextflow workflow. It is installed by cloning the repository or by running it directly from GitHub.

## Local Clone

```bash
git clone https://github.com/Thokas99/simple-nextflow-salmon.git
cd simple-nextflow-salmon
```

## Run From GitHub

After the v0.2.0 tag is created:

```bash
nextflow run Thokas99/simple-nextflow-salmon \
  -r v0.2.0 \
  --samplesheet /local/path/samplesheet.csv \
  --reference_dir /local/path/reference/GRCh38_GENCODE/raw \
  --outdir /local/path/results \
  -profile conda
```

The pipeline source comes from GitHub. Input FASTQs and references remain on the machine where Nextflow is launched.

## Execution Profiles

```bash
nextflow run . --samplesheet samplesheet.csv -profile conda
nextflow run . --samplesheet samplesheet.csv -profile docker
nextflow run . --samplesheet samplesheet.csv -profile apptainer
```

Conda is the primary portable profile for typical HPC systems. Docker and Apptainer use versioned BioContainers images configured in `nextflow.config`.

## Reference Setup

Default pinned reference:

```text
GENCODE release 50
GRCh38 patch 14
```

Place the matching `ALL` files in:

```text
reference/GRCh38_GENCODE/raw/
```

The derived full-decoy reference and Salmon index are cached under:

```text
reference/GRCh38_GENCODE/derived/
```

Cache reuse is controlled by `reference_manifest.json`. Use `--rebuild_reference true` only when intentionally rebuilding.
