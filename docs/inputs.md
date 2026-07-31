# Input and samplesheet rules

The CSV header is exactly `sample,fastq_1,fastq_2`. Quoted commas and spaces are parsed correctly. Blank values, unsafe sample IDs, unsupported extensions, unreadable files, identical mates, duplicate rows, repeated FASTQs, cross-sample assignment, and basename collisions fail validation with row numbers.

The generator recursively supports `.fastq`, `.fastq.gz`, `.fq`, and `.fq.gz`:

```bash
python3 scripts/make_samplesheet.py FASTQ_DIR --dry-run
python3 scripts/make_samplesheet.py FASTQ_DIR -o samplesheet.csv
```

Supported filename forms are `<sample>_R1.fastq.gz` and the complete Illumina `<sample>_S1_L001_R1_001.fastq.gz`. Incomplete S/L patterns are ambiguous and rejected. Standard lanes are sorted numerically and emitted as repeated biological-sample rows. `--lanes-as-samples` emits `<sample>_L001` instead. Existing output requires `--overwrite`.
