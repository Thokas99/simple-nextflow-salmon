# HPC and Apptainer

Use the versioned OCI image through Apptainer after release:

```bash
nextflow run . -profile apptainer --samplesheet samplesheet.csv \
  --reference_dir /shared/reference/raw --reference_cache_dir /shared/reference/cache \
  --outdir results
```

Add site executor, queue, and resource settings in a separate launch config (`-c site.config`) rather than editing the repository defaults. Ensure work, output, FASTQ, raw-reference, and cache paths are visible on compute nodes. Cache entries are immutable, so simultaneous runs cannot delete one another's references.
