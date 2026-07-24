#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
cd "$repo_dir"

nextflow config -profile conda >/dev/null

mkdir -p "$tmp_dir/fastqs" "$tmp_dir/reference/raw"
cp tests/fixtures/reference/raw/* "$tmp_dir/reference/raw/"
for lane in A_L1 A_L2 B C; do
    cp tests/fixtures/fastqs/UDB001_R1.fastq "$tmp_dir/fastqs/${lane}_R1.fastq"
    cp tests/fixtures/fastqs/UDB001_R2.fastq "$tmp_dir/fastqs/${lane}_R2.fastq"
done
cat >"$tmp_dir/samples.csv" <<EOF
sample,fastq_1,fastq_2
A,$tmp_dir/fastqs/A_L1_R1.fastq,$tmp_dir/fastqs/A_L1_R2.fastq
A,$tmp_dir/fastqs/A_L2_R1.fastq,$tmp_dir/fastqs/A_L2_R2.fastq
B,$tmp_dir/fastqs/B_R1.fastq,$tmp_dir/fastqs/B_R2.fastq
C,$tmp_dir/fastqs/C_R1.fastq,$tmp_dir/fastqs/C_R2.fastq
EOF

run_stub() {
    nextflow run . --samplesheet "$tmp_dir/samples.csv" \
      --reference_dir "$tmp_dir/reference/raw" --reference_cache_dir "$tmp_dir/cache" \
      --outdir "$tmp_dir/results-$1" -work-dir "$tmp_dir/work-$1" -stub-run \
      >"$tmp_dir/$1.log" 2>&1
}

run_stub fresh
trace="$tmp_dir/results-fresh/pipeline_info/execution_trace.tsv"
test "$(awk -F '\t' '$3 == "SALMON_QUANT" { count++ } END { print count+0 }' "$trace")" -eq 3
test "$(awk -F '\t' '$3 == "FASTQC" { count++ } END { print count+0 }' "$trace")" -eq 4
test "$(awk -F '\t' 'NR > 1 { count++ } END { print count+0 }' "$tmp_dir/results-fresh/qc/salmon_metrics.tsv")" -eq 3
test "$(awk -F '\t' '$1 == "A" { print $9 }' "$tmp_dir/results-fresh/qc/salmon_metrics.tsv")" -eq 2
test "$(awk -F '\t' 'NR == 1 { print NF }' "$tmp_dir/results-fresh/tximport/gene_counts.tsv")" -eq 4
test -s "$tmp_dir/results-fresh/qc/multiqc/multiqc_report.html"
test -s "$tmp_dir/results-fresh/qc/multiqc/multiqc_data/multiqc_data.json"
test -s "$tmp_dir/results-fresh/tximport/gene_counts.tsv"
test -s "$tmp_dir/results-fresh/qc/salmon_metrics.tsv"
test ! -e "$tmp_dir/results-fresh/summary/salmon_mapping_summary.tsv"
test -s "$tmp_dir/cache/gentrome.fa"
test -s "$tmp_dir/cache/reference_manifest.tsv"
test -s "$tmp_dir/cache/salmon_index/info.json"
test ! -e "$tmp_dir/reference/derived/gentrome.fa"

run_stub reused
grep -q 'Reusing reference and Salmon index' "$tmp_dir/reused.log"
trace="$tmp_dir/results-reused/pipeline_info/execution_trace.tsv"
test "$(awk -F '\t' '$3 == "SALMON_QUANT" { count++ } END { print count+0 }' "$trace")" -eq 3
test "$(awk -F '\t' '$3 == "SALMON_INDEX" { count++ } END { print count+0 }' "$trace")" -eq 0

cp "$tmp_dir/cache/salmon_index/info.json" "$tmp_dir/info.json.valid"
printf '{malformed\n' >"$tmp_dir/cache/salmon_index/info.json"
nextflow run . --samplesheet "$tmp_dir/samples.csv" --reference_dir "$tmp_dir/reference/raw" \
  --reference_cache_dir "$tmp_dir/cache" --outdir "$tmp_dir/validate-info" --validate_only true \
  >"$tmp_dir/malformed-info.log" 2>&1
grep -q 'incompatible and will be rebuilt' "$tmp_dir/malformed-info.log"
cp "$tmp_dir/info.json.valid" "$tmp_dir/cache/salmon_index/info.json"

cp "$tmp_dir/cache/reference_manifest.tsv" "$tmp_dir/manifest.valid"
printf 'not-a-valid-manifest\n' >"$tmp_dir/cache/reference_manifest.tsv"
nextflow run . --samplesheet "$tmp_dir/samples.csv" --reference_dir "$tmp_dir/reference/raw" \
  --reference_cache_dir "$tmp_dir/cache" --outdir "$tmp_dir/validate-manifest" --validate_only true \
  >"$tmp_dir/malformed-manifest.log" 2>&1
grep -q 'incompatible and will be rebuilt' "$tmp_dir/malformed-manifest.log"
cp "$tmp_dir/manifest.valid" "$tmp_dir/cache/reference_manifest.tsv"

for report in execution_report.html execution_timeline.html execution_trace.tsv pipeline_dag.html; do
    test -s "$tmp_dir/results-fresh/pipeline_info/$report"
done
! grep -R -q 'salmon_mapping_summary' README.md main.nf modules scripts
! grep -q -E 'multiqc_inputs|cp -r' modules/multiqc.nf

echo 'stub workflow tests passed'
