process BUILD_FULL_DECOY_REFERENCE {
    tag "GENCODE v${params.gencode_release} GRCh38.p${params.genome_patch}"
    publishDir "${params.reference_dir}/../derived", mode: 'copy', overwrite: true

    cpus { params.reference_cpus }
    memory { params.reference_memory }

    input:
    tuple path(tx_fasta), path(genome_fasta), path(gtf)

    output:
    tuple path("gentrome.fa"), path("decoys.txt"), path("annotation.gtf.gz"), path("reference_inputs.sha256"), emit: reference_files

    script:
    """
    seqkit seq --name --only-id ${genome_fasta} > genome_ids.txt
    awk '{print \$1}' genome_ids.txt > decoys.txt
    cat ${tx_fasta} ${genome_fasta} > gentrome.fa
    cp ${gtf} annotation.gtf.gz
    sha256sum ${tx_fasta} ${genome_fasta} ${gtf} > reference_inputs.sha256
    """

    stub:
    """
    touch gentrome.fa decoys.txt annotation.gtf.gz
    sha256sum ${tx_fasta} ${genome_fasta} ${gtf} > reference_inputs.sha256
    """
}
