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
    path "gene_length.tsv", emit: gene_length
    path "tx2gene.tsv", emit: tx2gene
    path "tximport_summary.tsv", emit: summary
    path "tximport_object.rds", emit: tximport_object
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
    printf 'gene_id\t%s\nENSG000001.1\t%s\n' "\$samples" "\$values" > gene_counts.tsv
    printf 'gene_id\t%s\nENSG000001.1\t%s\n' "\$samples" "\$values" > gene_abundance.tsv
    printf 'gene_id\t%s\nENSG000001.1\t%s\n' "\$samples" "\$values" > gene_length.tsv
    cat > tx2gene.tsv <<'EOF'
transcript_id	gene_id
ENST000001.1	ENSG000001.1
EOF
    cat > tximport_summary.tsv <<'EOF'
    metric	value
    countsFromAbundance	no
EOF
    touch tximport_object.rds
    awk -F, 'BEGIN { OFS="\\t" } { print \$1, \$2, \$3 }' ${samplesheet} > sample_metadata.tsv
    """
}
