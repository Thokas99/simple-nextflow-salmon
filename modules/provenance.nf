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
    path 'software_versions.tsv', emit: software_versions

    script:
    def completed = provenance + [completed_at: java.time.Instant.now().toString()]
    def json = groovy.json.JsonOutput.prettyPrint(groovy.json.JsonOutput.toJson(completed))
    def tsv = completed.findAll { _key, value -> !(value instanceof Collection) && !(value instanceof Map) }
        .collect { key, value -> "${key}\t${value}" }.join('\n')
    def expected_salmon = provenance.salmon_version.toString()
    """
    set -euo pipefail
    salmon_version=\$(salmon --version 2>&1 | awk 'NF { print \$NF; exit }')
    test -n "\$salmon_version"
    if [ "\$salmon_version" != '${expected_salmon}' ]; then
        echo "Runtime Salmon version \$salmon_version does not match expected ${expected_salmon} from envs/salmon-rnaseq.yml/reference-cache identity" >&2
        exit 1
    fi
    python_version=\$(python3 --version 2>&1 | awk '{ print \$2 }')
    fastqc_version=\$(fastqc --version 2>&1 | awk 'NF { print \$NF; exit }')
    multiqc_version=\$(multiqc --version 2>&1 | awk 'NF { print \$NF; exit }')
    r_version=\$(R --version 2>&1 | awk 'NR == 1 { print \$3 }')
    tximport_version=\$(Rscript -e 'cat(as.character(packageVersion("tximport")))')
    cat > software_versions.tsv <<TSV
software\tversion
Nextflow\t${provenance.nextflow_version}
Salmon\t\${salmon_version}
FastQC\t\${fastqc_version}
MultiQC\t\${multiqc_version}
Python\t\${python_version}
R\t\${r_version}
tximport\t\${tximport_version}
TSV
    cat > run_provenance.json <<'JSON'
${json}
JSON
    cat > run_provenance.tsv <<'TSV'
field	value
${tsv}
TSV
    """
}
