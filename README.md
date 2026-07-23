# Simple Nextflow Salmon

Reproducible paired-end RNA-seq quantification with Nextflow, FastQC, MultiQC, Salmon, and tximport.

```text
FASTQ pairs -> FastQC -> Salmon quant -> tximport gene counts -> summary tables
```

## What You Get

| Output | Location |
| --- | --- |
| FastQC reports | `results/qc/fastqc/` |
| MultiQC report | `results/qc/multiqc/` |
| Salmon quant folders | `results/salmon/` |
| Gene counts | `results/tximport/gene_counts.tsv` |
| Mapping summary | `results/summary/salmon_mapping_summary.tsv` |

## Requirements

Install these first:

```bash
nextflow -version
micromamba --version
git --version
```

Nextflow creates the Conda environment from:

```text
envs/salmon-rnaseq.yml
```

## Install

```bash
git clone https://github.com/Thokas99/simple-nextflow-salmon.git
cd simple-nextflow-salmon
```

## Reference Files

Put the GENCODE Human Release 50 / GRCh38.p14 `ALL` files here:

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

The first successful run creates and later reuses:

```text
reference/GRCh38_GENCODE/derived/
```

## Quick Start

Generate a samplesheet from FASTQs, validate the samplesheet and reference, then stop:

```bash
nextflow run . \
  --fastq_dir ../data/fastqs \
  --samplesheet ../data/samplesheet.csv \
  --reference_dir reference/GRCh38_GENCODE/raw \
  --validate_only true \
  -profile conda
```

Inspect `../data/samplesheet.csv`. If it looks right, launch the full run:

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  -profile conda
```

You can also generate and run in one command by removing `--validate_only true`:

```bash
nextflow run . \
  --fastq_dir ../data/fastqs \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  -profile conda
```

## FASTQ Naming

Automatic detection supports paired names like:

```text
UDB001_R1.fastq.gz
UDB001_R2.fastq.gz
UDB001_L001_R1.fq.gz
UDB001_L001_R2.fq.gz
```

The generated samplesheet has this shape:

```csv
sample,fastq_1,fastq_2
UDB001,/abs/path/UDB001_R1.fastq.gz,/abs/path/UDB001_R2.fastq.gz
```

Rules:

- `sample` must be unique.
- `fastq_1` and `fastq_2` must both exist.
- The same FASTQ cannot be assigned twice.
- This workflow does not merge lanes automatically; each detected pair becomes one sample row.

## Manual Samplesheet

If you prefer to create the file yourself:

```csv
sample,fastq_1,fastq_2
UDB001,/path/to/UDB001_R1.fq.gz,/path/to/UDB001_R2.fq.gz
UDB003,/path/to/UDB003_R1.fq.gz,/path/to/UDB003_R2.fq.gz
```

Or use the standalone helper:

```bash
python3 scripts/make_samplesheet.py ../data/fastqs -o ../data/samplesheet.csv
```

## Parameters

| Parameter | Default | Use |
| --- | --- | --- |
| `--fastq_dir` | none | Scan paired FASTQs and write a samplesheet |
| `--samplesheet` | none | Use or create this CSV/TSV |
| `--generated_samplesheet` | none | Output path used when `--fastq_dir` is set without `--samplesheet` |
| `--outdir` | `results` | Pipeline outputs |
| `--reference_dir` | `reference/GRCh38_GENCODE/raw` | Raw GENCODE files |
| `--validate_only` | `false` | Validate inputs and stop before workflow processes |
| `--rebuild_reference` | `false` | Rebuild derived reference and Salmon index |

Resource knobs:

```bash
--fastqc_cpus 2
--salmon_cpus 4
--index_cpus 8
```

## Resume Or Rebuild

Resume a failed run:

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  -profile conda \
  -resume
```

Force reference rebuild only when the raw GENCODE files or Salmon version change:

```bash
--rebuild_reference true
```

## Repository Layout

```text
main.nf
nextflow.config
modules/
scripts/make_samplesheet.py
envs/salmon-rnaseq.yml
docs/
reference/GRCh38_GENCODE/
```

## Version

```text
0.1.0
```
