# Local execution

Validate before spending compute:

```bash
nextflow run . -profile conda --samplesheet samplesheet.csv \
  --reference_dir /data/reference/raw --outdir results --validate_only true
```

Remove `--validate_only true` for the run. Relative paths resolve from the launch directory. Resume interrupted work with `-resume`; choose a persistent cache root with `--reference_cache_dir`.
