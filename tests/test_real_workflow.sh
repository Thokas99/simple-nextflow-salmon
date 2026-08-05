#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
cd "$repo_dir"
python3 tests/create_real_fixture.py "$tmp_dir"

run_real() {
  nextflow run . -profile conda,ci --samplesheet "$tmp_dir/samplesheet.csv" \
    --reference_dir "$tmp_dir/reference/raw" --reference_cache_dir "$tmp_dir/cache" \
    --outdir "$tmp_dir/results-$1" -work-dir "$tmp_dir/work-$1" >"$tmp_dir/$1.log" 2>&1
}

run_real fresh
trace="$tmp_dir/results-fresh/pipeline_info/execution_trace.tsv"
test "$(awk -F '\t' '$3 == "SALMON_QUANT" {n++} END {print n+0}' "$trace")" -eq 1
test "$(awk -F '\t' '$3 == "FASTQC" {n++} END {print n+0}' "$trace")" -eq 2
test -s "$tmp_dir/results-fresh/salmon/Synthetic/quant.sf"
awk -F '\t' 'NR > 1 && $5 > 0 {mapped=1} END {exit !mapped}' "$tmp_dir/results-fresh/salmon/Synthetic/quant.sf"
awk -F '\t' 'NR > 1 && $4 > 0 && $6 > 0 && $7 > 0 {valid=1} END {exit !valid}' "$tmp_dir/results-fresh/qc/salmon_metrics.tsv"
test "$(awk -F '\t' '$1 == "Synthetic" {print $2}' "$tmp_dir/results-fresh/qc/input_fragment_counts.tsv")" -eq 40
test -s "$tmp_dir/results-fresh/tximport/salmon_gene_estimated_counts.tsv"
test -s "$tmp_dir/results-fresh/tximport/salmon_gene_tximport.rds"
test -s "$tmp_dir/results-fresh/pipeline_info/run_provenance.json"
grep -q '"state": "completed"' "$tmp_dir/results-fresh/pipeline_info/run_provenance.json"
grep -q '"fastq_pairs": 2' "$tmp_dir/results-fresh/pipeline_info/run_provenance.json"
test -s "$tmp_dir/results-fresh/qc/multiqc/multiqc_report.html"
grep -q 'Align %' "$tmp_dir/results-fresh/qc/multiqc/multiqc_report.html"
grep -q 'Quant %' "$tmp_dir/results-fresh/qc/multiqc/multiqc_report.html"
grep -q 'Compat %' "$tmp_dir/results-fresh/qc/multiqc/multiqc_report.html"
! grep -q 'Percent Mapped' "$tmp_dir/results-fresh/qc/multiqc/multiqc_report.html"
! grep -q '% Aligned' "$tmp_dir/results-fresh/qc/multiqc/multiqc_report.html"

run_real reused
grep -q 'Reusing immutable reference cache' "$tmp_dir/reused.log"
test "$(awk -F '\t' '$3 == "SALMON_INDEX" {n++} END {print n+0}' "$tmp_dir/results-reused/pipeline_info/execution_trace.tsv")" -eq 0

echo 'real workflow tests passed'
