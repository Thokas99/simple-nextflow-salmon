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
    cat > estimated_count_summary.tsv <<'EOF'
metric	value
genes	1
samples	2
EOF
    cat > sample_count_summary.tsv <<'EOF'
sample	total_estimated_fragments	genes_with_estimated_count_gt_0
UDB001	10.5	1
UDB003	20.25	1
EOF
    cp sample_count_summary.tsv gene_count_summary.tsv
    """
}
