process SALMON_METRICS {
    tag "${quant_dirs.size()} biological samples"
    publishDir "${params.outdir}/qc", mode: 'copy', overwrite: true

    cpus 1
    memory '1 GB'

    input:
    path quant_dirs
    path input_counts

    output:
    path "salmon_metrics.tsv", emit: metrics
    path "input_fragment_counts.tsv", emit: input_counts
    path "salmon2_qc_general_mqc.json", emit: multiqc_general
    path "salmon2_qc_details_mqc.json", emit: multiqc_details

    script:
    def quant_args = quant_dirs.collect { dir -> "'${dir.toString().replace("'", "'\\''")}'" }.join(' ')
    """
    python3 "${projectDir}/scripts/salmon_metrics.py" \\
      --input-counts ${input_counts.collect { path -> "'${path.toString().replace("'", "'\\''")}'" }.join(' ')} \\
      --quant-dirs ${quant_args} \\
      --quant-output-dir "${params.outdir}/salmon" \\
      --output salmon_metrics.tsv \\
      --counts-output input_fragment_counts.tsv \\
      --multiqc-general salmon2_qc_general_mqc.json \\
      --multiqc-details salmon2_qc_details_mqc.json
    """
}
