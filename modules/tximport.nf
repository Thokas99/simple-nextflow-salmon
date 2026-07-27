process TXIMPORT {
    publishDir "${params.outdir}/tximport", mode: 'copy', overwrite: true

    cpus { params.tximport_cpus }
    memory { params.tximport_memory }

    input:
    path quant_dirs
    path gtf
    path samplesheet

    output:
    path "salmon_gene_estimated_counts.tsv", emit: gene_estimated_counts
    path "salmon_gene_tpm.tsv", emit: gene_tpm
    path "salmon_gene_average_effective_length.tsv", emit: gene_average_effective_length
    path "tx2gene.tsv", emit: tx2gene
    path "tximport_summary.tsv", emit: summary
    path "salmon_gene_tximport.rds", emit: gene_tximport
    path "sample_metadata.tsv", emit: sample_metadata

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
    samples=\$(awk -F, 'NR > 1 && !seen[\$1]++ { printf "%s%s", sep, \$1; sep="\\t" }' ${samplesheet})
    values=\$(awk -F, 'NR > 1 && !seen[\$1]++ { printf "%s10.5", sep; sep="\\t" }' ${samplesheet})
    printf 'gene_id\t%s\nENSG000001.1\t%s\n' "\$samples" "\$values" > salmon_gene_estimated_counts.tsv
    printf 'gene_id\t%s\nENSG000001.1\t%s\n' "\$samples" "\$values" > salmon_gene_tpm.tsv
    printf 'gene_id\t%s\nENSG000001.1\t%s\n' "\$samples" "\$values" > salmon_gene_average_effective_length.tsv
    cat > tx2gene.tsv <<'EOF'
transcript_id	gene_id
ENST000001.1	ENSG000001.1
EOF
    cat > tximport_summary.tsv <<'EOF'
    metric	value
    countsFromAbundance	no
EOF
    touch salmon_gene_tximport.rds
    awk -F, 'BEGIN { OFS="\\t" } { print \$1, \$2, \$3 }' ${samplesheet} > sample_metadata.tsv
    """
}
