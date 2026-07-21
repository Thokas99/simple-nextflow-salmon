# Simple Nextflow Salmon

Reproducible DSL2 workflow for paired-end RNA-seq quantification with FastQC, MultiQC, GENCODE full-decoy Salmon indexing, Salmon quantification, tximport gene-level summaries, and basic count/mapping QC tables.

## Table of Contents

- [What This Pipeline Does](#what-this-pipeline-does)
- [Workflow Overview](#workflow-overview)
- [Repository Layout](#repository-layout)
- [Requirements](#requirements)
- [Install Environments](#install-environments)
- [Reference Files](#reference-files)
- [Samplesheet](#samplesheet)
- [Run Locally](#run-locally)
- [Run From GitHub](#run-from-github)
- [Outputs](#outputs)
- [Reference Reuse](#reference-reuse)
- [Important Design Decisions](#important-design-decisions)
- [Troubleshooting](#troubleshooting)
- [Version](#version)

## What This Pipeline Does

This workflow takes paired-end FASTQ files and produces:

- FastQC reports for each FASTQ.
- A MultiQC report over FastQC outputs.
- A full-genome decoy-aware Salmon reference from GENCODE raw files.
- A Salmon index.
- Salmon quantification for each sample.
- tximport gene-level count, abundance, and length matrices.
- Simple Salmon mapping and raw-count summary tables.

It does **not** perform differential expression, biological interpretation, or filtering for downstream DE tools.

## Workflow Overview

The workflow order is explicit:

```text
FASTQC
  -> MULTIQC
  -> BUILD_FULL_DECOY_REFERENCE
  -> SALMON_INDEX
  -> SALMON_QUANT
  -> TXIMPORT
  -> RAW_COUNT_SUMMARY
```

Reference construction is technically independent of FastQC, but this pipeline intentionally waits for MultiQC before building references so the execution order is easy to follow.

## Repository Layout

```text
.
├── main.nf
├── nextflow.config
├── envs/
│   └── salmon-rnaseq.yml
├── modules/
│   ├── fastqc.nf
│   ├── multiqc.nf
│   ├── build_full_decoy_reference.nf
│   ├── salmon_index.nf
│   ├── salmon_quant.nf
│   ├── tximport.nf
│   └── raw_count_summary.nf
├── scripts/
│   ├── tximport_gene_summary.R
│   └── summary_stats.R
├── docs/
│   ├── install.md
│   └── run_local.md
└── reference/
    └── GRCh38_GENCODE/
        ├── raw/
        └── derived/
```

Large reference files, FASTQs, Nextflow work directories, and result folders are intentionally ignored by git.

## Requirements

Install these on the machine where you run the workflow:

- Nextflow
- Micromamba or Conda
- Git

Check:

```bash
nextflow -version
micromamba --version
git --version
```

## Install Environment

The workflow uses one Micromamba/Conda environment:

```text
envs/salmon-rnaseq.yml
```

Recommended usage: let Nextflow create and cache it automatically:

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  -profile conda
```

Manual environment creation is optional:

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

The environment YAML is:

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

## Reference Files

Default raw reference directory:

```text
reference/GRCh38_GENCODE/raw
```

Expected current GENCODE Human Release 50 / GRCh38.p14 files:

```text
gencode.v50.transcripts.fa.gz
GRCh38.p14.genome.fa.gz
gencode.v50.chr_patch_hapl_scaff.annotation.gtf.gz
```

Download source:

```text
https://www.gencodegenes.org/human/
```

Use the GENCODE Human `ALL` files:

- Transcript sequences `ALL`
- Genome sequence GRCh38.p14 `ALL`
- Comprehensive gene annotation `ALL`

The pipeline validates the local reference directory before launching workflow processes. It fails early if required files are missing, ambiguous, mismatched, or appear to mix sources.

## Samplesheet

Use CSV or TSV with unique sample IDs:

```csv
sample,fastq_1,fastq_2
UDB001,/path/to/UDB001_R1.fq.gz,/path/to/UDB001_R2.fq.gz
UDB003,/path/to/UDB003_R1.fq.gz,/path/to/UDB003_R2.fq.gz
```

Rules:

- `sample` must be non-empty and unique.
- `fastq_1` and `fastq_2` must both exist.
- The same FASTQ cannot be assigned twice.
- This version does not merge lanes automatically. Use one row per final sample.

## Run Locally

From the cloned repository:

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  -profile conda
```

Useful parameters:

```bash
--lib_type A
--salmon_k 31
--rebuild_reference true
--fastqc_cpus 2
--index_cpus 8
--salmon_cpus 4
```

## Run From GitHub

After the repository is pushed and tagged:

```bash
nextflow run Thokas99/simple-nextflow-salmon \
  -r v0.1.0 \
  --samplesheet /path/to/samplesheet.csv \
  --outdir /path/to/results \
  --reference_dir /path/to/reference/GRCh38_GENCODE/raw \
  -profile conda
```

## Outputs

```text
results/
├── qc/
│   ├── fastqc/
│   └── multiqc/
├── salmon/
│   └── <sample_id>/
├── tximport/
│   ├── tx2gene.tsv
│   ├── gene_counts.tsv
│   ├── gene_abundance.tsv
│   ├── gene_length.tsv
│   ├── tximport_object.rds
│   └── sample_metadata.tsv
└── summary/
    ├── salmon_mapping_summary.tsv
    ├── raw_count_summary.tsv
    └── gene_count_summary.tsv
```

Derived reference outputs:

```text
reference/GRCh38_GENCODE/derived/
├── gentrome.fa
├── decoys.txt
├── annotation.gtf.gz
├── reference_manifest.tsv
├── checksums.sha256
└── salmon_index/
```

`tximport/gene_counts.tsv` contains unrounded raw estimated counts from `txi$counts` with `countsFromAbundance = "no"`.

## Reference Reuse

By default, the workflow reuses an existing derived reference if all of these exist:

```text
reference/GRCh38_GENCODE/derived/gentrome.fa
reference/GRCh38_GENCODE/derived/decoys.txt
reference/GRCh38_GENCODE/derived/annotation.gtf.gz
reference/GRCh38_GENCODE/derived/salmon_index/info.json
```

To force rebuilding:

```bash
--rebuild_reference true
```

This is useful only when the raw GENCODE files change.

## Important Design Decisions

- CSV/TSV samplesheets are explicit and reproducible; no filename guessing.
- Sample IDs are unique; no hidden lane merging.
- GENCODE FASTA headers are handled with `salmon index --gencode`.
- tximport preserves versioned GENCODE identifiers and checks `quant.sf`/GTF overlap.
- Decoys are extracted only from genome FASTA headers.
- Transcript sequences are not treated as decoys.
- The pipeline is installable by cloning/running with Nextflow; no custom installer script is needed.

## Troubleshooting

### Missing Reference Files

If the workflow stops before running processes, check:

```text
reference/GRCh38_GENCODE/raw/
```

You need:

```text
gencode.v50.transcripts.fa.gz
GRCh38.p14.genome.fa.gz
gencode.v50.chr_patch_hapl_scaff.annotation.gtf.gz
```

### Rebuilding the Index

If the Salmon version changes, rebuild:

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  --rebuild_reference true \
  -profile conda
```

### Resume a Failed Run

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  -profile conda \
  -resume
```

## Version

Current version:

```text
0.1.0
```

Release tag:

```bash
git tag v0.1.0
git push origin main --tags
```
