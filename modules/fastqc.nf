process FASTQC {
    tag "$sample"
    publishDir "${params.outdir}/qc/fastqc", mode: 'copy'
    cpus { params.fastqc_cpus ?: 2 }
    memory { params.fastqc_memory ?: '2 GB' }

    input:
    tuple val(sample), path(r1), path(r2)

    output:
    path "fastqc/*", emit: reports

    script:
    """
    mkdir -p fastqc
    fastqc -t ${task.cpus} -o fastqc ${r1} ${r2}
    """

    stub:
    """
    mkdir -p fastqc
    touch fastqc/${sample}_R1_fastqc.html fastqc/${sample}_R1_fastqc.zip
    touch fastqc/${sample}_R2_fastqc.html fastqc/${sample}_R2_fastqc.zip
    """
}
