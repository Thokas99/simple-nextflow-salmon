# Run Locally

## 1. Validate

```bash
nextflow run . \
  --fastq_dir ../data/fastqs \
  --samplesheet ../data/samplesheet.csv \
  --reference_dir reference/GRCh38_GENCODE/raw \
  --validate_only true \
  -profile conda
```

Inspect `../data/samplesheet.csv`.

## 2. Run

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  -profile conda
```

## 3. Resume

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  -profile conda \
  -resume
```

## 4. Rebuild Reference

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  --rebuild_reference true \
  -profile conda
```
