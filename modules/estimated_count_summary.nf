process ESTIMATED_COUNT_SUMMARY {
    publishDir "${params.outdir}/summary", mode: 'copy', overwrite: true

    cpus { params.summary_cpus }
    memory { params.summary_memory }

    input:
    path quant_dirs
    path gene_counts
    path samplesheet

    output:
    path "estimated_count_summary.tsv", emit: estimated_count_summary
    path "gene_count_summary.tsv", emit: gene_count_summary

    script:
    """
    Rscript ${projectDir}/scripts/estimated_count_summary.R \\
      --gene_counts ${gene_counts} \\
      --samplesheet ${samplesheet} \\
      --outdir .
    """

    stub:
    """
    cat > estimated_count_summary.tsv <<'EOF'
metric	value
genes	1
samples	2
EOF
    cat > gene_count_summary.tsv <<'EOF'
sample	total_estimated_fragments	genes_with_estimated_count_gt_0
UDB001	10.5	1
UDB003	20.25	1
EOF
    """
}
