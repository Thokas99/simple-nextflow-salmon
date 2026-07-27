# simple-nextflow-salmon

Small paired-end bulk RNA-seq workflow:

```text
FASTQ -> FastQC -> Salmon -> tximport -> concise QC summaries -> MultiQC
```

It builds or reuses a GENCODE full-decoy Salmon index, quantifies paired-end reads with Salmon, imports gene-level estimates with tximport, and writes small tabular summaries for quick QC.

It deliberately does not run alignment, BAM generation, trimming, cloud execution, containers, differential expression, integerized count matrices, or Salmon bootstraps/Gibbs sampling.

## Requirements

- Nextflow `>=24.10.0`
- Java 17 or newer
- Conda or Mamba/Micromamba

The workflow uses `envs/salmon-rnaseq.yml`, which pins Salmon `2.3.4` and provides FastQC, MultiQC, R, tximport, data.table, rtracklayer, and GenomicFeatures. edgeR is not part of the workflow environment because it is a downstream analysis dependency.

## Run

```bash
nextflow run . \
  -profile conda \
  --samplesheet /absolute/path/to/samplesheet.csv \
  --reference_dir /absolute/path/to/reference/GRCh38_GENCODE/raw \
  --outdir results
```

Use `-resume` to continue after an interrupted run:

```bash
nextflow run . -profile conda -resume \
  --samplesheet /absolute/path/to/samplesheet.csv \
  --reference_dir /absolute/path/to/reference/GRCh38_GENCODE/raw \
  --outdir results
```

For validation without running quantification:

```bash
nextflow run . -profile conda \
  --samplesheet /absolute/path/to/samplesheet.csv \
  --reference_dir /absolute/path/to/reference/GRCh38_GENCODE/raw \
  --validate_only true
```

## Samplesheet

CSV columns:

```csv
sample,fastq_1,fastq_2
UDB001,/data/UDB001_L001_R1.fastq.gz,/data/UDB001_L001_R2.fastq.gz
UDB001,/data/UDB001_L002_R1.fastq.gz,/data/UDB001_L002_R2.fastq.gz
UDB003,/data/UDB003_R1.fastq.gz,/data/UDB003_R2.fastq.gz
```

Rules:

- `sample` is the biological sample ID and may repeat for technical replicates.
- Repeated sample IDs are grouped into ordered R1/R2 lists for one Salmon task and one tximport column per biological sample.
- FastQC still runs per FASTQ pair, so lane-level QC is retained.
- FASTQ paths must exist, be readable, and use `.fastq.gz`, `.fq.gz`, `.fastq`, or `.fq`.
- Sample IDs may contain letters, numbers, `.`, `_`, and `-`, and must start with a letter or number.

You can generate a basic samplesheet from paired FASTQs:

```bash
python3 scripts/make_samplesheet.py /absolute/path/to/fastqs -o /absolute/path/to/samplesheet.csv
```

## Reference

Default reference inputs are GENCODE v50 on GRCh38.p14:

```text
reference/GRCh38_GENCODE/raw/
├── gencode.v50.transcripts.fa.gz
├── GRCh38.p14.genome.fa.gz
└── gencode.v50.chr_patch_hapl_scaff.annotation.gtf.gz
```

The workflow builds a full-decoy Salmon reference, writes `reference_manifest.tsv`, and validates cached index compatibility before reuse. Versioned GENCODE transcript and gene identifiers are preserved.

Use `--reference_cache_dir` to keep derived reference files outside the raw reference directory:

```bash
nextflow run . -profile conda \
  --samplesheet /absolute/path/to/samplesheet.csv \
  --reference_dir /nas/reference/GRCh38_GENCODE/raw \
  --reference_cache_dir /local/ssd/reference/GRCh38_GENCODE/derived \
  --outdir results
```

## Main Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `--samplesheet` | required | CSV with `sample,fastq_1,fastq_2` |
| `--reference_dir` | required | Directory containing raw GENCODE FASTA/GTF files |
| `--reference_cache_dir` | `null` | Optional directory for derived reference and Salmon index |
| `--outdir` | `results` | Output directory |
| `--gencode_release` | `50` | GENCODE release expected in filenames |
| `--genome_patch` | `14` | GRCh38 patch expected in genome FASTA filename |
| `--salmon_version` | `2.3.4` | Salmon version expected in the cached index manifest |
| `--salmon_k` | `31` | Salmon index k-mer size |
| `--validate_only` | `false` | Validate inputs/reference/index, then stop |

## Outputs

| Output | Meaning |
|---|---|
| `results/qc/fastqc/` | FastQC reports per FASTQ pair |
| `results/salmon/<sample>/quant.sf` | Salmon transcript-level quantification per biological sample |
| `results/qc/salmon_metrics.tsv` | Concise Salmon mapping metrics |
| `results/tximport/salmon_gene_tximport.rds` | Complete gene-level tximport object; preferred downstream analysis input |
| `results/tximport/salmon_gene_estimated_counts.tsv` | Unrounded fractional estimated fragment counts from `txi$counts` |
| `results/tximport/salmon_gene_tpm.tsv` | Gene-level TPM values from `txi$abundance` |
| `results/tximport/salmon_gene_average_effective_length.tsv` | Gene-level average effective lengths from `txi$length` |
| `results/tximport/tx2gene.tsv` | Transcript-to-gene map used for import |
| `results/tximport/sample_metadata.tsv` | Samples included in tximport |
| `results/tximport/tximport_summary.tsv` | tximport sample/gene/transcript summary |
| `results/summary/estimated_count_summary.tsv` | Sample-level summary of estimated counts and Salmon mapping metrics |
| `results/summary/gene_count_summary.tsv` | Per-gene total estimated count summary |
| `results/qc/multiqc/multiqc_report.html` | MultiQC report |
| `results/pipeline_info/` | Nextflow report, timeline, trace, and DAG |

tximport is run with `countsFromAbundance = "no"`. Estimated counts are probabilistic fragment-allocation estimates from Salmon and may be fractional; they are not directly observed integer read totals. TPM is normalized relative expression and is not an input for count-based differential-expression testing. Average effective lengths are used by tximport-aware differential-expression interfaces.

## Downstream Analysis

The saved tximport object is the authoritative downstream input:

```r
library(edgeR)

txi <- readRDS(
  "results/tximport/salmon_gene_tximport.rds"
)

dge <- DGEListFromTximport(txi)
```

The resulting `DGEList` can proceed through a standard edgeR workflow, typically beginning with:

```r
dge <- filterByExpr(dge)
dge <- normLibSizes(dge)
```

`DGEListFromTximport()` requires edgeR 4.10.0 or newer. The official tximport vignette says, [“The object dge is ready for any of the edgeR analysis pipelines.”](https://bioconductor.org/packages/release/bioc/vignettes/tximport/inst/doc/tximport.html#edger) See the [tximport vignette](https://bioconductor.org/packages/release/bioc/vignettes/tximport/inst/doc/tximport.html) and the official [edgeR User's Guide](https://bioconductor.org/packages/release/bioc/vignettes/edgeR/inst/doc/edgeRUsersGuide.pdf) for analysis options.

## Troubleshooting

| Problem | Check |
|---|---|
| Missing reference file | Filenames must match the configured GENCODE release and GRCh38 patch under `--reference_dir` |
| Cached index rejected | The manifest must match Salmon version, GENCODE release, genome patch, k-mer size, and full-decoy settings |
| Conda solver error | Use Mamba/Micromamba or a clean Conda cache |
| Missing FASTQ | Use absolute paths or paths valid from the launch directory |
| Unexpected replicate behavior | Repeated `sample` rows are treated as technical replicates for one biological sample |

## Citation

Cite Nextflow, Salmon, tximport, FastQC, MultiQC, edgeR if used downstream, and the exact GENCODE reference used in the analysis. Repository citation metadata is in `CITATION.cff`.
