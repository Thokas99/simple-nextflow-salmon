# Local execution

Run the current local checkout with automatic FASTQ discovery:

```bash
NXF_ANSI_LOG=0 nextflow run . -profile conda \
  --fastq_dir /data/fastqs --reference_dir /data/reference/raw --outdir results
```

The explicit equivalent is `--samplesheet samplesheet.csv`; exactly one input is required. Add `--validate_only true` to validate input and cache identity before spending compute. `NXF_ANSI_LOG=0` (or `-ansi-log false`) disables Nextflow's animated ANSI interface for conventional line-oriented logs, nohup, and HPC jobs. Relative paths resolve from the launch directory. Resume interrupted work with `-resume`; choose a persistent cache root with `--reference_cache_dir`.
