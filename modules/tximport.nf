process TXIMPORT {
    publishDir "${params.outdir}/tximport", mode: 'copy', overwrite: true

    cpus { params.tximport_cpus }
    memory { params.tximport_memory }

    input:
    path quant_dirs
    path gtf
    path samplesheet

    output:
    path "gene_counts.tsv", emit: gene_counts
    path "gene_abundance.tsv", emit: gene_abundance
    path "tx2gene.tsv", emit: tx2gene
    path "tximport_summary.tsv", emit: summary
    path "tximport_object.rds", emit: tximport_object

    script:
    """
    Rscript ${projectDir}/scripts/tximport_gene_summary.R \\
      --quant_dirs ${quant_dirs.join(' ')} \\
      --gtf ${gtf} \\
      --samplesheet ${samplesheet} \\
      --outdir .
    """

    stub:
    """
    cat > gene_counts.tsv <<'EOF'
gene_id	UDB001	UDB003
ENSG000001.1	10.5	20.25
EOF
    cat > gene_abundance.tsv <<'EOF'
gene_id	UDB001	UDB003
ENSG000001.1	5.0	9.0
EOF
    cat > tx2gene.tsv <<'EOF'
transcript_id	gene_id
ENST000001.1	ENSG000001.1
EOF
    cat > tximport_summary.tsv <<'EOF'
metric	value
countsFromAbundance	no
EOF
    touch tximport_object.rds
    """
}
