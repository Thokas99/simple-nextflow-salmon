process INPUT_FRAGMENT_COUNTS {
    tag "$sample"

    cpus 1
    memory '1 GB'

    input:
    tuple val(sample), path(r1), path(r2), val(lane_count)

    output:
    tuple val(sample), path("${sample}.input_fragment_counts.tsv"), emit: counts

    script:
    def r1_args = r1.collect { fastq -> "'${fastq.toString().replace("'", "'\\''")}'" }.join(' ')
    def r2_args = r2.collect { fastq -> "'${fastq.toString().replace("'", "'\\''")}'" }.join(' ')
    """
    python3 "${projectDir}/scripts/input_fragment_counts.py" \\
      --sample '${sample}' \\
      --r1 ${r1_args} \\
      --r2 ${r2_args} \\
      --output '${sample}.input_fragment_counts.tsv'
    """

    stub:
    """
    printf 'sample\tinput_fragments\tfastq_pairs\n%s\t1000\t%s\n' '${sample}' '${lane_count}' > '${sample}.input_fragment_counts.tsv'
    """
}
