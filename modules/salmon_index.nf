process SALMON_INDEX {
    tag "k=${params.salmon_k}"
    cpus { params.index_cpus }
    memory { params.index_memory }

    input:
    tuple path(gentrome), path(decoys), path(gtf)
    val identity

    output:
    tuple path('salmon_index'), path('reference_manifest.json'), emit: index
    path 'annotation.gtf.gz', emit: reference_gtf

    script:
    def manifest = groovy.json.JsonOutput.prettyPrint(groovy.json.JsonOutput.toJson(identity))
    """
    salmon index -t "${gentrome}" -d "${decoys}" -i salmon_index \\
      -k ${params.salmon_k} --gencode --threads ${task.cpus}
    cat > reference_manifest.json <<'MANIFEST'
${manifest}
MANIFEST
    """

    stub:
    def manifest = groovy.json.JsonOutput.prettyPrint(groovy.json.JsonOutput.toJson(identity))
    """
    mkdir -p salmon_index
    for name in index.ctab index.ectab index.refinfo index.ssi refseq.bin refseq_offsets.json; do echo stub > "salmon_index/\$name"; done
    echo '{"salmon_version":"${params.salmon_version}","k":${params.salmon_k},"has_ec_table":true,"num_refs":1,"num_decoys":1}' > salmon_index/info.json
    cat > reference_manifest.json <<'MANIFEST'
${manifest}
MANIFEST
    """
}
