process NORMALIZE_INPUT {
    tag "${input_kind} input"
    publishDir "${params.outdir}/pipeline_info", mode: 'copy', overwrite: true

    cpus 1
    memory '1 GB'

    input:
    tuple val(source_arg), path(input_source)
    val fastq_naming
    val input_kind

    output:
    path 'resolved_samplesheet.csv', emit: samplesheet
    path 'resolved_samplesheet.json', emit: metadata

    script:
    def source_arg_quoted = source_arg.toString().replace("'", "'\\''")
    def input_source_quoted = input_source.toString().replace("'", "'\\''")
    """
    python3 "${projectDir}/scripts/validate_samplesheet.py" '${input_source_quoted}' \\
      --input-kind ${input_kind} \\
      --fastq-naming ${fastq_naming} \\
      --launch-dir '${launchDir}' \\
      --source-root '${source_arg_quoted}' \\
      --output resolved_samplesheet.csv \\
      --metadata resolved_samplesheet.json
    """

    stub:
    def source_arg_quoted = source_arg.toString().replace("'", "'\\''")
    def input_source_quoted = input_source.toString().replace("'", "'\\''")
    """
    python3 "${projectDir}/scripts/validate_samplesheet.py" '${input_source_quoted}' \\
      --input-kind ${input_kind} \\
      --fastq-naming ${fastq_naming} \\
      --launch-dir '${launchDir}' \\
      --source-root '${source_arg_quoted}' \\
      --output resolved_samplesheet.csv \\
      --metadata resolved_samplesheet.json
    """
}
