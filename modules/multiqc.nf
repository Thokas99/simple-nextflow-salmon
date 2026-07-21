process MULTIQC {
    publishDir "${params.outdir}/qc/multiqc", mode: 'copy'
    conda "${projectDir}/envs/qc.yml"

    cpus { params.multiqc_cpus ?: 1 }
    memory { params.multiqc_memory ?: '2 GB' }

    input:
    path fastqc_reports

    output:
    path "multiqc/multiqc_report.html", emit: report
    path "multiqc/multiqc_data", emit: data

    script:
    """
    multiqc . -o multiqc
    """

    stub:
    """
    mkdir -p multiqc/multiqc_data
    touch multiqc/multiqc_report.html multiqc/multiqc_data/multiqc_general_stats.txt
    """
}
