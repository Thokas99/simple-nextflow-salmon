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
    touch ${r1.name}_fastqc.html ${r1.name}_fastqc.zip
    touch ${r2.name}_fastqc.html ${r2.name}_fastqc.zip
    """
}
