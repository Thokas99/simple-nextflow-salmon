# Install and Run

This workflow is a Nextflow pipeline. It does not need installation in the Python/R package sense.

## Requirements

Install:

```text
Nextflow
Micromamba or Conda
Git
```

## Environments

The workflow ships three Micromamba/Conda-compatible YAML files:

```text
envs/qc.yml
envs/salmon.yml
envs/r_tximport.yml
```

With:

```bash
-profile conda
```

Nextflow creates and caches these environments automatically. You do not need to activate them manually.

Manual creation is also possible:

```bash
micromamba env create -f envs/qc.yml
micromamba env create -f envs/salmon.yml
micromamba env create -f envs/r_tximport.yml
```

The YAML contents are intentionally small:

```yaml
# envs/qc.yml
name: salmon-rnaseq-qc
channels:
  - conda-forge
  - bioconda
dependencies:
  - fastqc=0.12.1
  - multiqc=1.30
```

```yaml
# envs/salmon.yml
name: salmon-rnaseq-salmon
channels:
  - conda-forge
  - bioconda
dependencies:
  - salmon=2.3.4
  - pigz=2.8
  - seqkit=2.10.0
```

```yaml
# envs/r_tximport.yml
name: salmon-rnaseq-r
channels:
  - conda-forge
  - bioconda
dependencies:
  - r-base=4.4
  - r-data.table=1.15
  - r-readr=2.1
  - r-jsonlite=1.8
  - bioconductor-tximport=1.34
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
