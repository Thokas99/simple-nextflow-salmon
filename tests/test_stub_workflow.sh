#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
cd "$repo_dir"

mkdir -p "$tmp_dir/reference/raw"
cp tests/fixtures/reference/raw/* "$tmp_dir/reference/raw/"

nextflow run . --samplesheet tests/fixtures/samplesheet_technical_replicates.csv \
  --reference_dir "$tmp_dir/reference/raw" --outdir "$tmp_dir/results" \
  -work-dir "$tmp_dir/work" -stub-run

test "$(awk -F '\t' '$3 == "SALMON_QUANT" { count++ } END { print count+0 }' "$tmp_dir/results/pipeline_info/execution_trace.tsv")" -eq 1
test "$(awk -F '\t' 'NR == 2 { print $9 }' "$tmp_dir/results/qc/salmon_metrics.tsv")" -eq 2
test "$(awk -F '\t' 'NR == 1 { print NF }' "$tmp_dir/results/tximport/gene_counts.tsv")" -eq 2
grep -q $'gene_id\tUDB001' "$tmp_dir/results/tximport/gene_counts.tsv"
for report in execution_report.html execution_timeline.html execution_trace.tsv pipeline_dag.html; do
    test -s "$tmp_dir/results/pipeline_info/$report"
done

echo 'stub workflow tests passed'
