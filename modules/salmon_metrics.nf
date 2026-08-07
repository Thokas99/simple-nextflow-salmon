process SALMON_METRICS {
    tag "${quant_dirs.size()} biological samples"
    publishDir "${params.outdir}/qc", mode: 'copy', overwrite: true

    cpus 1
    memory '1 GB'

    input:
    path quant_dirs
    path samplesheet
    path sample_count_summary

    output:
    path "salmon_metrics.tsv", emit: metrics
    path "pipeline_rna_qc_mqc.json", emit: multiqc_general

    script:
    def quant_args = quant_dirs.collect { dir -> "'${dir.toString().replace("'", "'\\''")}'" }.join(' ')
    """
    python3 "${projectDir}/scripts/salmon_metrics.py" \\
      --quant-dirs ${quant_args} \\
      --samplesheet "${samplesheet}" \\
      --sample-count-summary "${sample_count_summary}" \\
      --output salmon_metrics.tsv \\
      --multiqc-general pipeline_rna_qc_mqc.json
    """
}
