process RAW_COUNT_SUMMARY {
    publishDir "${params.outdir}/summary", mode: 'copy'
    conda "${projectDir}/envs/r_tximport.yml"

    cpus { params.summary_cpus ?: 1 }
    memory { params.summary_memory ?: '4 GB' }

    input:
    path quant_dirs
    path gene_counts

    output:
    path "summary/salmon_mapping_summary.tsv", emit: salmon_mapping_summary
    path "summary/raw_count_summary.tsv", emit: raw_count_summary
    path "summary/gene_count_summary.tsv", emit: gene_count_summary

    script:
    """
    Rscript ${projectDir}/scripts/summary_stats.R \\
        --gene_counts ${gene_counts} \\
        --outdir summary
    """

    stub:
    """
    mkdir -p summary
    touch summary/salmon_mapping_summary.tsv summary/raw_count_summary.tsv summary/gene_count_summary.tsv
    """
}
