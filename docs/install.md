# Install and Run

This workflow is a Nextflow pipeline. It does not need installation in the Python/R package sense.

## Requirements

Install:

```text
Nextflow
Micromamba or Conda
Git
```

## Clone Locally

```bash
git clone https://github.com/Thokas99/simple-nextflow-salmon.git
cd simple-nextflow-salmon
```

## Environment

The workflow ships one Micromamba/Conda-compatible YAML file:

```text
envs/salmon-rnaseq.yml
```

With:

```bash
-profile conda
```

Nextflow creates and caches this environment automatically. You do not need to activate it manually.

Manual creation is also possible:

```bash
micromamba env create -f envs/salmon-rnaseq.yml
micromamba activate salmon-rnaseq
```

Equivalent one-line creation:

```bash
micromamba create -n salmon-rnaseq \
  -c conda-forge \
  -c bioconda \
  --strict-channel-priority \
  salmon fastqc multiqc seqkit pigz samtools \
  r-base r-tidyverse r-data.table r-readr r-jsonlite \
  bioconductor-tximport bioconductor-rhdf5 bioconductor-biocparallel \
  -y
```

The YAML content is:

```yaml
name: salmon-rnaseq
channels:
  - conda-forge
  - bioconda
channel_priority: strict
dependencies:
  - salmon
  - fastqc
  - multiqc
  - seqkit
  - pigz
  - samtools
  - r-base
  - r-tidyverse
  - r-data.table
  - r-readr
  - r-jsonlite
  - bioconductor-tximport
  - bioconductor-rhdf5
  - bioconductor-biocparallel
```

## Run from GitHub

After pushing and tagging the repo, run it from any machine with:

```bash
nextflow run Thokas99/simple-nextflow-salmon \
  -r v0.1.0 \
  --samplesheet /path/to/samplesheet.csv \
  --outdir /path/to/results \
  --reference_dir /path/to/reference/GRCh38_GENCODE/raw \
  -profile conda
```

## Reference Files

Put the raw GENCODE Human files here:

```text
reference/GRCh38_GENCODE/raw/
```

Expected files:

```text
gencode.v50.transcripts.fa.gz
GRCh38.p14.genome.fa.gz
gencode.v50.chr_patch_hapl_scaff.annotation.gtf.gz
```

Download from:

```text
https://www.gencodegenes.org/human/
```

The first run creates:

```text
reference/GRCh38_GENCODE/derived/
```

Later runs reuse the derived reference automatically unless:

```bash
--rebuild_reference true
```

## Local Development Run

From a cloned repo:

```bash
python3 scripts/make_samplesheet.py ../data/fastqs -o ../data/samplesheet.csv
```

Inspect `../data/samplesheet.csv`, then validate inputs:

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --reference_dir reference/GRCh38_GENCODE/raw \
  --validate_only true \
  -profile conda
```

Launch the full run:

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  -profile conda
```

## Release

After committing changes:

```bash
git tag v0.1.0
git push origin main --tags
```
