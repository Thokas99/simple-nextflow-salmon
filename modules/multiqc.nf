process MULTIQC {
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
    cat > multiqc_config.yml <<'EOF'
title: "simple-nextflow-salmon report"
module_order:
  - fastqc
  - salmon
data_dir_name: multiqc_data
EOF
    multiqc . --config multiqc_config.yml --outdir . --filename multiqc_report.html --force
    """

    stub:
    """
    mkdir -p multiqc_data
    echo '<html><body>stub MultiQC</body></html>' > multiqc_report.html
    echo '{}' > multiqc_data/multiqc_data.json
    """
}
