process FASTQC {
    tag "$sample"
    publishDir "${params.outdir}/qc/fastqc", mode: 'copy', overwrite: true

    cpus { params.fastqc_cpus }
    memory { params.fastqc_memory }

    input:
    tuple val(sample), path(r1), path(r2)

    output:
    path "*_fastqc.*", emit: reports

    script:
    """
    fastqc --threads ${task.cpus} --outdir . ${r1} ${r2}
    """

    stub:
    """
    touch ${sample}_R1_fastqc.html ${sample}_R1_fastqc.zip
    touch ${sample}_R2_fastqc.html ${sample}_R2_fastqc.zip
    """
}
