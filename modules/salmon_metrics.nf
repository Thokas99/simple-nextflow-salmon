process SALMON_METRICS {
    publishDir "${params.outdir}/qc", mode: 'copy', overwrite: true

    cpus 1
    memory '1 GB'

    input:
    path quant_dirs
    path samplesheet

    output:
    path "salmon_metrics.tsv", emit: metrics

    script:
    """
    python3 ${projectDir}/scripts/salmon_metrics.py \\
      --samplesheet ${samplesheet} \\
      --quant-dirs ${quant_dirs.join(' ')} \\
      --quant-output-dir ${params.outdir}/salmon \\
      --output salmon_metrics.tsv
    """
}
