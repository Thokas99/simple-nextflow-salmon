#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
cd "$repo_dir"

reference=tests/fixtures/reference/raw
validate() {
    nextflow run . -profile conda,ci --samplesheet "$1" --reference_dir "$reference" \
      --outdir "$tmp_dir/results-$2" --validate_only true >"$tmp_dir/$2.log" 2>&1
}
reject() {
    if validate "$1" "$2"; then
        echo "Expected validation failure: $2" >&2
        exit 1
    fi
}

validate tests/fixtures/samplesheet_single.csv single
validate tests/fixtures/samplesheet.csv standard
validate tests/fixtures/samplesheet_technical_replicates.csv technical
grep -q '"biological_samples": 1' "$tmp_dir/results-technical/pipeline_info/resolved_samplesheet.json"
grep -q '"fastq_pairs": 2' "$tmp_dir/results-technical/pipeline_info/resolved_samplesheet.json"

reject_both() {
    if nextflow run . -profile conda,ci --samplesheet tests/fixtures/samplesheet_single.csv \
        --fastq_dir tests/fixtures/fastqs --reference_dir "$reference" --outdir "$tmp_dir/results-both" \
        --validate_only true >"$tmp_dir/both.log" 2>&1; then
        echo 'Expected exactly-one input validation failure' >&2
        exit 1
    fi
}
reject_both

cat >"$tmp_dir/missing.csv" <<EOF
sample,fastq_1,fastq_2
BAD,$tmp_dir/missing_R1.fastq.gz,$tmp_dir/missing_R2.fastq.gz
EOF
reject "$tmp_dir/missing.csv" missing
grep -q 'file not found' "$tmp_dir/missing.log"

cp tests/fixtures/samplesheet_single.csv "$tmp_dir/duplicate.csv"
tail -n 1 tests/fixtures/samplesheet_single.csv >>"$tmp_dir/duplicate.csv"
reject "$tmp_dir/duplicate.csv" duplicate
grep -q 'duplicate samplesheet row\|repeated within sample' "$tmp_dir/duplicate.log"

cat >"$tmp_dir/reassigned.csv" <<EOF
sample,fastq_1,fastq_2
A,$repo_dir/tests/fixtures/fastqs/UDB001_R1.fastq,$repo_dir/tests/fixtures/fastqs/UDB001_R2.fastq
B,$repo_dir/tests/fixtures/fastqs/UDB001_R1.fastq,$repo_dir/tests/fixtures/fastqs/UDB003_R2.fastq
EOF
reject "$tmp_dir/reassigned.csv" reassigned
grep -q "across samples 'A' and 'B'" "$tmp_dir/reassigned.log"

cat >"$tmp_dir/mismatched.csv" <<EOF
sample,fastq_1,fastq_2
BAD,$repo_dir/tests/fixtures/fastqs/UDB001_R1.fastq,
EOF
reject "$tmp_dir/mismatched.csv" mismatched
grep -q 'fastq_2: value is empty' "$tmp_dir/mismatched.log"

echo 'validation tests passed'
