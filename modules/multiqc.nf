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
    mkdir -p multiqc_inputs
    cp -r ${inputs.join(' ')} multiqc_inputs/
    cat > multiqc_config.yml <<'EOF'
title: "simple-nextflow-salmon report"
module_order:
  - fastqc
  - salmon
EOF
    multiqc multiqc_inputs --config multiqc_config.yml --outdir . --filename multiqc_report.html --force
    """

    stub:
    """
    mkdir -p multiqc_data
    echo '<html><body>stub MultiQC</body></html>' > multiqc_report.html
    echo '{}' > multiqc_data/multiqc_data.json
    """
}
