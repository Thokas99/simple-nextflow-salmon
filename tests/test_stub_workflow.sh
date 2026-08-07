#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
trap 'status=$?; trap - ERR; echo "stub workflow test failed at line $LINENO" >&2; for log in "$tmp_dir"/*.log; do test -f "$log" && { echo "--- $log" >&2; cat "$log" >&2; }; done; find "$tmp_dir" -path "*/work-*/*/*/.command.err" -o -path "*/work-*/*/*/.command.out" -o -path "*/work-*/*/*/.command.log" | sort | while read -r log; do echo "--- $log" >&2; cat "$log" >&2; done; exit "$status"' ERR
cd "$repo_dir"

nextflow config -profile conda >/dev/null

mkdir -p "$tmp_dir/fastqs" "$tmp_dir/reference/raw"
cp tests/fixtures/reference/raw/* "$tmp_dir/reference/raw/"
for lane in 01 02; do
    cp tests/fixtures/fastqs/UDB001_R1.fastq "$tmp_dir/fastqs/V350387909_L${lane}_A_1.fastq"
    cp tests/fixtures/fastqs/UDB001_R2.fastq "$tmp_dir/fastqs/V350387909_L${lane}_A_2.fastq"
done
cp tests/fixtures/fastqs/UDB001_R1.fastq "$tmp_dir/fastqs/B_R1.fastq"
cp tests/fixtures/fastqs/UDB001_R2.fastq "$tmp_dir/fastqs/B_R2.fastq"
cp tests/fixtures/fastqs/UDB001_R1.fastq "$tmp_dir/fastqs/C_S1_L001_R1_001.fastq"
cp tests/fixtures/fastqs/UDB001_R2.fastq "$tmp_dir/fastqs/C_S1_L001_R2_001.fastq"

run_stub() {
    nextflow run . -profile conda,ci --fastq_dir "$tmp_dir/fastqs" \
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
test "$(awk -F '\t' 'NR == 1 { print $1 FS $2 FS $3 FS $4 FS $5 FS $6 FS $7 FS $8 FS $9 }' "$tmp_dir/results-fresh/qc/salmon_metrics.tsv")" = $'sample\tnum_processed\tnum_mapped\tpercent_mapped\tdetected_library_type\tfrag_length_mean\tfrag_length_sd\tsalmon_version\tfastq_pairs'
test -s "$tmp_dir/results-fresh/pipeline_info/resolved_samplesheet.csv"
grep -q '"A"' "$tmp_dir/results-fresh/pipeline_info/resolved_samplesheet.csv"
for matrix in salmon_gene_estimated_counts.tsv salmon_gene_tpm.tsv salmon_gene_average_effective_length.tsv; do
    header=$(awk -F '	' 'NR == 1 { print $1 "	" $2 "	" $3 "	" $4 "	" $5 }' "$tmp_dir/results-fresh/tximport/$matrix")
    test "$header" = $'gene_id	gene_name	A	B	C'
    test "$(awk -F '	' 'NR > 1 && $1 ~ /^ENSG/ && $2 != "" { count++ } END { print count+0 }' "$tmp_dir/results-fresh/tximport/$matrix")" -eq 1
done
test -s "$tmp_dir/results-fresh/qc/multiqc/multiqc_report.html"
test -s "$tmp_dir/results-fresh/qc/multiqc/multiqc_data/multiqc_data.json"
test -s "$tmp_dir/results-fresh/tximport/salmon_gene_estimated_counts.tsv"
test -s "$tmp_dir/results-fresh/tximport/salmon_gene_tpm.tsv"
test -s "$tmp_dir/results-fresh/tximport/salmon_gene_average_effective_length.tsv"
test -s "$tmp_dir/results-fresh/tximport/gene_annotation.tsv"
test "$(awk -F '	' 'NR == 1 { print $1 "	" $2 }' "$tmp_dir/results-fresh/tximport/gene_annotation.tsv")" = $'gene_id	gene_name'
test "$(awk -F '	' 'NR > 1 { seen[$1]++ } END { for (gene in seen) if (seen[gene] > 1) dup++; print dup+0 }' "$tmp_dir/results-fresh/tximport/gene_annotation.tsv")" -eq 0
test "$(awk -F '	' 'NR == 1 && ($1 != "transcript_id" || $2 != "gene_id" || NF != 2) { bad++ } NR > 1 && NF != 2 { bad++ } END { print bad+0 }' "$tmp_dir/results-fresh/tximport/tx2gene.tsv")" -eq 0
test -e "$tmp_dir/results-fresh/tximport/salmon_gene_tximport.rds"
grep -q 'compress = "xz"' scripts/tximport_gene_summary.R
test -s "$tmp_dir/results-fresh/qc/salmon_metrics.tsv"
test ! -e "$tmp_dir/results-fresh/summary/salmon_mapping_summary.tsv"
cache_dir=$(find "$tmp_dir/cache" -mindepth 1 -maxdepth 1 -type d | head -n 1)
test -n "$cache_dir"
test -s "$cache_dir/gentrome.fa"
test -s "$cache_dir/reference_manifest.json"
test -s "$cache_dir/salmon_index/info.json"
test ! -e "$tmp_dir/reference/derived/gentrome.fa"

run_stub reused
grep -q 'Reusing immutable reference cache' "$tmp_dir/reused.log"
trace="$tmp_dir/results-reused/pipeline_info/execution_trace.tsv"
test "$(awk -F '\t' '$3 == "SALMON_QUANT" { count++ } END { print count+0 }' "$trace")" -eq 3
test "$(awk -F '\t' '$3 == "SALMON_INDEX" { count++ } END { print count+0 }' "$trace")" -eq 0

cp "$cache_dir/salmon_index/info.json" "$tmp_dir/info.json.valid"
printf '{malformed\n' >"$cache_dir/salmon_index/info.json"
nextflow run . -profile conda,ci --fastq_dir "$tmp_dir/fastqs" --reference_dir "$tmp_dir/reference/raw" \
  --reference_cache_dir "$tmp_dir/cache" --outdir "$tmp_dir/validate-info" --validate_only true \
  >"$tmp_dir/malformed-info.log" 2>&1
grep -q 'Reference cache will be built' "$tmp_dir/malformed-info.log"
cp "$tmp_dir/info.json.valid" "$cache_dir/salmon_index/info.json"

cp "$cache_dir/reference_manifest.json" "$tmp_dir/manifest.valid"
printf 'not-a-valid-manifest\n' >"$cache_dir/reference_manifest.json"
nextflow run . -profile conda,ci --fastq_dir "$tmp_dir/fastqs" --reference_dir "$tmp_dir/reference/raw" \
  --reference_cache_dir "$tmp_dir/cache" --outdir "$tmp_dir/validate-manifest" --validate_only true \
  >"$tmp_dir/malformed-manifest.log" 2>&1
grep -q 'Reference cache will be built' "$tmp_dir/malformed-manifest.log"
cp "$tmp_dir/manifest.valid" "$cache_dir/reference_manifest.json"

mv "$cache_dir/salmon_index/index.ssi" "$tmp_dir/index.ssi"
nextflow run . -profile conda,ci --fastq_dir "$tmp_dir/fastqs" --reference_dir "$tmp_dir/reference/raw" \
  --reference_cache_dir "$tmp_dir/cache" --outdir "$tmp_dir/validate-missing" --validate_only true \
  >"$tmp_dir/missing-index.log" 2>&1
grep -q 'Reference cache will be built' "$tmp_dir/missing-index.log"
mv "$tmp_dir/index.ssi" "$cache_dir/salmon_index/index.ssi"

nextflow run . -profile conda,ci --fastq_dir "$tmp_dir/fastqs" --reference_dir "$tmp_dir/reference/raw" \
  --reference_cache_dir "$tmp_dir/cache" --outdir "$tmp_dir/validate-k" --salmon_k 29 --validate_only true \
  >"$tmp_dir/changed-k.log" 2>&1
grep -q 'Reference cache will be built' "$tmp_dir/changed-k.log"

cp "$tmp_dir/reference/raw/gencode.v50.transcripts.fa.gz" "$tmp_dir/transcripts.valid"
printf 'changed' >> "$tmp_dir/reference/raw/gencode.v50.transcripts.fa.gz"
nextflow run . -profile conda,ci --fastq_dir "$tmp_dir/fastqs" --reference_dir "$tmp_dir/reference/raw" \
  --reference_cache_dir "$tmp_dir/cache" --outdir "$tmp_dir/validate-source" --validate_only true \
  >"$tmp_dir/changed-source.log" 2>&1
grep -q 'Reference cache will be built' "$tmp_dir/changed-source.log"
mv "$tmp_dir/transcripts.valid" "$tmp_dir/reference/raw/gencode.v50.transcripts.fa.gz"

test "$(find "$tmp_dir/cache" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" -eq 1

for report in execution_report.html execution_timeline.html execution_trace.tsv pipeline_dag.html; do
    test -s "$tmp_dir/results-fresh/pipeline_info/$report"
done
test -s "$tmp_dir/results-fresh/pipeline_info/run_provenance.json"
test -s "$tmp_dir/results-fresh/summary/sample_count_summary.tsv"
! grep -R -q 'input_fragment_counts\|alignment_rate\|quantification_rate\|compatibility_rate' main.nf modules scripts README.md
! grep -q -E 'multiqc_inputs|cat > multiqc_config.yml' modules/multiqc.nf

echo 'stub workflow tests passed'
