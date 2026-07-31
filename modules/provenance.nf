process PROVENANCE {
    tag 'run provenance'
    publishDir "${params.outdir}/pipeline_info", mode: 'copy', overwrite: true
    cpus 1
    memory '1 GB'

    input:
    val provenance
    path multiqc_report
    path sample_summary
    path salmon_metrics

    output:
    path 'run_provenance.json', emit: json
    path 'run_provenance.tsv', emit: tsv

    script:
    def completed = provenance + [completed_at: java.time.Instant.now().toString()]
    def json = groovy.json.JsonOutput.prettyPrint(groovy.json.JsonOutput.toJson(completed))
    def tsv = completed.findAll { _key, value -> !(value instanceof Collection) && !(value instanceof Map) }
        .collect { key, value -> "${key}\t${value}" }.join('\n')
    """
    cat > run_provenance.json <<'JSON'
${json}
JSON
    cat > run_provenance.tsv <<'TSV'
field	value
${tsv}
TSV
    """
}
