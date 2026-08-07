process MULTIQC {
    tag "${inputs.size()} inputs"
    publishDir "${params.outdir}/qc/multiqc", mode: 'copy', overwrite: true

    cpus { params.multiqc_cpus }
    memory { params.multiqc_memory }

    input:
    path inputs

    output:
    path "multiqc_report.html", emit: report
    path "multiqc_data", emit: data

    script:
    """
    cp "${projectDir}/conf/multiqc_config.yml" multiqc_config.yml
    multiqc . --config multiqc_config.yml --outdir . --filename multiqc_report.html --force
    """

    stub:
    """
    mkdir -p multiqc_data
    echo '<html><body>stub MultiQC</body></html>' > multiqc_report.html
    echo '{}' > multiqc_data/multiqc_data.json
    """
}
