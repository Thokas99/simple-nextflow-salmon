# Input and samplesheet rules

Use exactly one of `--samplesheet samplesheet.csv` and `--fastq_dir /data/fastqs`. The CSV header is exactly `sample,fastq_1,fastq_2`. Quoted commas and spaces are parsed correctly. Blank values, unsafe sample IDs, unsupported extensions, unreadable files, identical mates, duplicate rows, repeated FASTQs, cross-sample assignment, and basename collisions fail validation with row numbers.

The generator recursively supports `.fastq`, `.fastq.gz`, `.fq`, and `.fq.gz`:

```bash
python3 scripts/make_samplesheet.py FASTQ_DIR --dry-run
python3 scripts/make_samplesheet.py FASTQ_DIR -o samplesheet.csv
```

Supported forms are simple `<sample>_R1.fastq.gz`, Illumina `<sample>_S1_L001_R1_001.fastq.gz`, and MGI `<run>_L01_<sample>_1.fq.gz`. Use `--fastq_naming auto|illumina|mgi|simple`; `auto` rejects ambiguous or mixed conventions. Lanes are sorted deterministically and emitted as repeated biological-sample rows. The workflow always writes `pipeline_info/resolved_samplesheet.csv`.
