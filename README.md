# simple-nextflow-salmon

[![CI](https://github.com/Thokas99/simple-nextflow-salmon/actions/workflows/ci.yml/badge.svg)](https://github.com/Thokas99/simple-nextflow-salmon/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/Thokas99/simple-nextflow-salmon)](https://github.com/Thokas99/simple-nextflow-salmon/releases)
[![license](https://img.shields.io/github/license/Thokas99/simple-nextflow-salmon)](LICENSE)

A small paired-end bulk RNA-seq workflow for FastQC, MultiQC, GENCODE full-decoy Salmon quantification, and tximport gene-level summarization.

It does not trim, align, filter, normalize, test differential expression, or interpret biology.

## Quick Start

Local clone:

```bash
python3 scripts/make_samplesheet.py \
  /absolute/path/to/fastqs \
  -o /absolute/path/to/samplesheet.csv

nextflow run . \
  --samplesheet /absolute/path/to/samplesheet.csv \
  --reference_dir /absolute/path/to/reference/GRCh38_GENCODE/raw \
  --outdir /absolute/path/to/results \
  -profile conda \
  -resume
```

GitHub release:

```bash
nextflow run Thokas99/simple-nextflow-salmon \
  -r <RELEASE_TAG> \
  --samplesheet /absolute/path/to/samplesheet.csv \
  --reference_dir /absolute/path/to/reference/GRCh38_GENCODE/raw \
  --outdir /absolute/path/to/results \
  -profile conda \
  -resume
```

Nextflow downloads the workflow code from GitHub, while the FASTQs, reference files and results remain on the machine where the command is launched. Create a release tag only after the simplified workflow is merged and validated.

## Workflow

```mermaid
flowchart LR
  S[Samplesheet] --> F[FastQC]
  S --> Q[Salmon quantification]
  R[GENCODE FASTA and GTF] --> D[Full-decoy reference]
  D --> I[Salmon index]
  I --> Q
  Q --> T[tximport]
  Q --> C[Mapping and estimated-count QC]
  T --> C
  F --> M[MultiQC]
  Q --> M
```

FastQC and reference preparation can start independently. MultiQC runs after FastQC and Salmon so its report includes both.

## Requirements

- Nextflow `>=24.10.0`
- Java 17+
- Conda, Mamba, or Micromamba available to Nextflow

Conda is the only supported execution backend. Nextflow creates and caches the pinned environment from `envs/salmon-rnaseq.yml`; users do not activate it manually.

## Samplesheet

The workflow accepts one explicit CSV input:

```csv
sample,fastq_1,fastq_2
UDB001,/absolute/path/UDB001_R1.fastq.gz,/absolute/path/UDB001_R2.fastq.gz
```

The three columns are required exactly. Sample IDs must contain only letters, numbers, `.`, `_`, or `-`; IDs and FASTQ paths must be unique; R1 and R2 must exist and differ. Relative paths are resolved from the directory where Nextflow was launched.

The optional helper scans paired filenames before the workflow is launched:

```bash
python3 scripts/make_samplesheet.py /absolute/path/to/fastqs -o /absolute/path/to/samplesheet.csv
```

One detected pair becomes one sample row. Lane tokens remain in sample IDs, and lanes are never silently merged.

## Reference

The default reference inputs are:

```text
GRCh38_GENCODE/
└── raw/
    ├── gencode.v50.transcripts.fa.gz
    ├── GRCh38.p14.genome.fa.gz
    └── gencode.v50.chr_patch_hapl_scaff.annotation.gtf.gz
```

They produce:

```text
GRCh38_GENCODE/
└── derived/
    ├── gentrome.fa
    ├── decoys.txt
    ├── annotation.gtf.gz
    ├── salmon_index/
    └── reference_manifest.tsv
```

The transcript and genome FASTAs are decompressed, checked for duplicate identifiers, and concatenated in that order. Genome identifiers become decoys, every decoy is checked against the gentrome, and Salmon builds the index with `--gencode`.

The small manifest is written only when the index is built. Reuse requires the derived files plus matching GENCODE release, genome patch, filenames, Salmon version, k-mer size, and `--gencode` option. A mismatch stops with:

```bash
--rebuild_reference true
```

That option removes only the known files under the selected `derived/` directory. It does not checksum multi-gigabyte references on every launch.

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `--samplesheet` | required | CSV with `sample,fastq_1,fastq_2` |
| `--reference_dir` | `reference/GRCh38_GENCODE/raw` | Raw GENCODE reference directory |
| `--outdir` | `results` | Results directory |
| `--gencode_release` | `50` | GENCODE release |
| `--genome_patch` | `14` | GRCh38 patch |
| `--salmon_k` | `31` | Salmon index k-mer size |
| `--lib_type` | `A` | Salmon library type |
| `--rebuild_reference` | `false` | Rebuild known derived artifacts |
| `--validate_only` | `false` | Validate inputs without running processes |

User inputs and outputs may be absolute or relative to the launch directory. `projectDir` is used only for workflow modules, scripts, and the Conda YAML bundled with the repository.

## Outputs

| Output | Path |
| --- | --- |
| FastQC | `results/qc/fastqc/` |
| MultiQC | `results/qc/multiqc/multiqc_report.html` |
| Salmon quantifications | `results/salmon/<sample>/` |
| Transcript-to-gene map | `results/tximport/tx2gene.tsv` |
| Estimated gene counts | `results/tximport/gene_counts.tsv` |
| Gene abundance | `results/tximport/gene_abundance.tsv` |
| Gene effective length | `results/tximport/gene_length.tsv` |
| tximport object | `results/tximport/tximport_object.rds` |
| Sample metadata | `results/tximport/sample_metadata.tsv` |
| Mapping QC | `results/summary/salmon_mapping_summary.tsv` |
| Estimated-count QC | `results/summary/estimated_count_summary.tsv` |
| Per-sample gene-count QC | `results/summary/gene_count_summary.tsv` |

`gene_counts.tsv` contains unrounded tximport estimated fragment counts with `countsFromAbundance = "no"`. These are estimated counts, not raw integer read counts. Versioned GENCODE transcript and gene identifiers are retained.

## Resume

Use the same command and add `-resume`. Nextflow reuses completed tasks from its work directory; the reference manifest separately controls reuse of the published Salmon index.

## Troubleshooting

| Problem | Resolution |
| --- | --- |
| Missing reference file | Check the exact GENCODE release and GRCh38 patch filenames under `--reference_dir` |
| Incompatible derived reference | Review the selected raw files, then use `--rebuild_reference true` |
| FASTQ not found | Use an absolute path or a path relative to the launch directory |
| Unsafe or duplicate sample | Correct the samplesheet; lanes must have distinct sample IDs |
| Conda solve fails | Confirm Conda/Mamba is available and retry after clearing only the failed cached environment |

## License and Citation

MIT licensed. Cite Nextflow, Salmon, tximport, FastQC, MultiQC, and the GENCODE reference used in the analysis. Repository metadata is in `CITATION.cff`.
