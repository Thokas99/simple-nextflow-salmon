# Simple Nextflow Salmon

DSL2 paired-end RNA-seq workflow:

```text
FASTQC
  -> MULTIQC
  -> BUILD_FULL_DECOY_REFERENCE
  -> SALMON_INDEX
  -> SALMON_QUANT
  -> TXIMPORT
  -> RAW_COUNT_SUMMARY
```

The reference stage is intentionally ordered after MultiQC by passing the MultiQC report into `BUILD_FULL_DECOY_REFERENCE` as a completion signal.

## Reference Files

Default raw reference directory:

```text
reference/GRCh38_GENCODE/raw
```

Expected current GENCODE Human release 50 / GRCh38.p14 files:

```text
gencode.v50.transcripts.fa.gz
GRCh38.p14.genome.fa.gz
gencode.v50.chr_patch_hapl_scaff.annotation.gtf.gz
```

These are the GENCODE `ALL` transcript FASTA, `ALL` genome FASTA, and `ALL` comprehensive GTF. The pipeline fails early if the release, assembly, file count, or source naming does not match.

## Samplesheet

CSV or TSV with unique sample IDs:

```csv
sample,fastq_1,fastq_2
UDB001,/path/to/UDB001_R1.fq.gz,/path/to/UDB001_R2.fq.gz
UDB003,/path/to/UDB003_R1.fq.gz,/path/to/UDB003_R2.fq.gz
```

This refactor keeps sample IDs unique. Lane merging can be added later, but hiding it now makes the learning path less clear.

## Run

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  -profile conda
```

For a fresh local setup, see `docs/run_local.md`.
For running from GitHub on another machine, see `docs/install.md`.
The Micromamba/Conda YAMLs are documented in `docs/install.md` and stored under `envs/`.

Useful params:

```bash
--lib_type A
--salmon_k 31
--rebuild_reference true
--fastqc_cpus 2
--index_cpus 8
--salmon_cpus 4
```

By default the pipeline reuses an existing derived reference if all of these exist:

```text
reference/GRCh38_GENCODE/derived/gentrome.fa
reference/GRCh38_GENCODE/derived/decoys.txt
reference/GRCh38_GENCODE/derived/annotation.gtf.gz
reference/GRCh38_GENCODE/derived/salmon_index/info.json
```

Use `--rebuild_reference true` to force rebuilding the decoys, gentrome, and Salmon index.

## Outputs

```text
../data/results/
  qc/fastqc/
  qc/multiqc/
  salmon/
  tximport/
  summary/

reference/GRCh38_GENCODE/derived/
  gentrome.fa
  decoys.txt
  reference_manifest.tsv
  checksums.sha256
  salmon_index/
```

`tximport/gene_counts.tsv` contains unrounded raw estimated counts from `txi$counts` with `countsFromAbundance = "no"`.

## GENCODE ID Handling

GENCODE transcript FASTA headers contain extra fields separated by `|`. `salmon index --gencode` trims those headers to transcript IDs that match the GTF `transcript_id` values.

The tximport step preserves versioned GENCODE identifiers and fails if the first `quant.sf` does not substantially overlap the GTF-derived `tx2gene.tsv`.
