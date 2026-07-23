process TXIMPORT {
    publishDir "${params.outdir}/tximport", mode: 'copy'
    cpus { params.tximport_cpus ?: 2 }
    memory { params.tximport_memory ?: '16 GB' }

    input:
    path quant_dirs
    path gtf
    path samplesheet

    output:
    path "tximport/tx2gene.tsv", emit: tx2gene
    path "tximport/gene_counts.tsv", emit: gene_counts
    path "tximport/gene_abundance.tsv", emit: gene_abundance
    path "tximport/gene_length.tsv", emit: gene_length
    path "tximport/tximport_object.rds", emit: tximport_object
    path "tximport/sample_metadata.tsv", emit: sample_metadata

    script:
    """
    Rscript ${projectDir}/scripts/tximport_gene_summary.R \\
        --gtf ${gtf} \\
        --samplesheet ${samplesheet} \\
        --outdir tximport
    """

    stub:
    """
    mkdir -p tximport
    touch tximport/tx2gene.tsv tximport/gene_abundance.tsv tximport/gene_length.tsv tximport/tximport_object.rds tximport/sample_metadata.tsv
    printf 'gene_id\\tUDB001\\tUDB003\\nGENE1.1\\t10\\t20\\n' > tximport/gene_counts.tsv
    """
}
