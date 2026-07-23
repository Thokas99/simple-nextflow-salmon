# Run Locally

```bash
python3 scripts/make_samplesheet.py \
  /absolute/path/to/fastqs \
  -o /absolute/path/to/samplesheet.csv

nextflow run . \
  --samplesheet /absolute/path/to/samplesheet.csv \
  --reference_dir /absolute/path/to/reference/GRCh38_GENCODE/raw \
  --outdir /absolute/path/to/results \
  --validate_only true \
  -profile conda

nextflow run . \
  --samplesheet /absolute/path/to/samplesheet.csv \
  --reference_dir /absolute/path/to/reference/GRCh38_GENCODE/raw \
  --outdir /absolute/path/to/results \
  -profile conda \
  -resume
```

Remove `--validate_only true` only after inspecting the samplesheet. Add `--rebuild_reference true` when the workflow reports an incompatible derived reference.
