# Run Locally

## 1. Prepare the Folder

Clone the repo, then put the current GENCODE Human raw files here:

```bash
git clone https://github.com/Thokas99/simple-nextflow-salmon.git
cd simple-nextflow-salmon
```

```text
reference/GRCh38_GENCODE/raw/
```

Expected current files:

```text
gencode.v50.transcripts.fa.gz
GRCh38.p14.genome.fa.gz
gencode.v50.chr_patch_hapl_scaff.annotation.gtf.gz
```

Authoritative source:

```text
https://www.gencodegenes.org/human/
```

Use the GENCODE Human Release 50 / GRCh38.p14 `ALL` files:

```text
Transcript sequences ALL
Genome sequence (GRCh38.p14) ALL
Comprehensive gene annotation ALL
```

The pipeline checks these before launching workflow processes. If a file is missing or mismatched, it stops early and tells you what to download.

## 2. Prepare a Samplesheet

Create one automatically from paired FASTQ filenames:

```bash
python3 scripts/make_samplesheet.py ../data/fastqs -o ../data/samplesheet.csv
```

Example:

```csv
sample,fastq_1,fastq_2
UDB001,/path/to/UDB001_R1.fq.gz,/path/to/UDB001_R2.fq.gz
UDB003,/path/to/UDB003_R1.fq.gz,/path/to/UDB003_R2.fq.gz
```

Sample IDs must be unique.

Inspect `../data/samplesheet.csv` before launching the full workflow.

## 3. Validate

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --reference_dir reference/GRCh38_GENCODE/raw \
  --validate_only true \
  -profile conda
```

## 4. Run

```bash
nextflow run . \
  --samplesheet ../data/samplesheet.csv \
  --outdir ../data/results \
  --reference_dir reference/GRCh38_GENCODE/raw \
  -profile conda
```

## 5. Reuse the Reference

After the first successful run, the pipeline reuses these files automatically:

```text
reference/GRCh38_GENCODE/derived/gentrome.fa
reference/GRCh38_GENCODE/derived/decoys.txt
reference/GRCh38_GENCODE/derived/annotation.gtf.gz
reference/GRCh38_GENCODE/derived/salmon_index/info.json
```

For new samples with the same GENCODE reference, just provide a new samplesheet and outdir.

Force a rebuild only when the raw reference changes:

```bash
--rebuild_reference true
```
