process SALMON_METRICS {
    tag "${quant_dirs.size()} biological samples"
    publishDir "${params.outdir}/qc", mode: 'copy', overwrite: true

    cpus 1
    memory '1 GB'

    input:
    path quant_dirs
    path samplesheet

    output:
    path "salmon_metrics.tsv", emit: metrics

    script:
    def quant_args = quant_dirs.collect { dir -> "'${dir.toString().replace("'", "'\\''")}'" }.join(' ')
    """
    python3 "${projectDir}/scripts/salmon_metrics.py" \\
      --samplesheet "${samplesheet}" \\
      --quant-dirs ${quant_args} \\
      --quant-output-dir "${params.outdir}/salmon" \\
      --output salmon_metrics.tsv
    """
}
