process ESTIMATED_COUNT_SUMMARY {
    tag "${quant_dirs.size()} biological samples"
    publishDir "${params.outdir}/summary", mode: 'copy', overwrite: true

    cpus { params.summary_cpus }
    memory { params.summary_memory }

    input:
    path quant_dirs
    path gene_estimated_counts
    path samplesheet

    output:
    path "estimated_count_summary.tsv", emit: estimated_count_summary
    path "sample_count_summary.tsv", emit: sample_count_summary
    path "gene_count_summary.tsv", emit: deprecated_gene_count_summary

    script:
    """
    Rscript "${projectDir}/scripts/estimated_count_summary.R" \\
      --gene_estimated_counts "${gene_estimated_counts}" \\
      --samplesheet "${samplesheet}" \\
      --outdir .
    """

    stub:
    """
    samples=\$(python3 -c 'import csv,sys; print("\\n".join(dict.fromkeys(r["sample"] for r in csv.DictReader(open(sys.argv[1], newline="")))))' "${samplesheet}")
    cat > estimated_count_summary.tsv <<'EOF'
metric	value
genes	1
samples	2
EOF
    printf 'sample\ttotal_estimated_fragments\tgenes_with_estimated_count_gt_0\n' > sample_count_summary.tsv
    while read -r sample; do printf '%s\t10.5\t1\n' "\$sample" >> sample_count_summary.tsv; done <<< "\$samples"
    cp sample_count_summary.tsv gene_count_summary.tsv
    """
}
