process SALMON_INDEX {
    tag "k=${params.salmon_k}"
    publishDir "${params.reference_dir}/../derived", mode: 'copy', overwrite: true

    cpus { params.index_cpus }
    memory { params.index_memory }

    input:
    tuple path(gentrome), path(decoys), path(gtf), path(reference_checksums)

    output:
    tuple path("salmon_index"), path("reference_manifest.json"), emit: index
    path "annotation.gtf.gz", emit: reference_gtf

    script:
    """
    rm -rf salmon_index
    salmon index \\
      -t ${gentrome} \\
      -d ${decoys} \\
      -i salmon_index \\
      -k ${params.salmon_k} \\
      ${params.salmon_index_options}

    salmon --version | awk '{print \$NF}' > salmon.version

    python3 ${projectDir}/scripts/write_reference_manifest.py \\
      --checksums ${reference_checksums} \\
      --out reference_manifest.json \\
      --pipeline_version ${params.pipeline_version} \\
      --gencode_release ${params.gencode_release} \\
      --genome_patch ${params.genome_patch} \\
      --salmon_version "\$(cat salmon.version)" \\
      --salmon_k ${params.salmon_k} \\
      --salmon_index_options='${params.salmon_index_options}' \\
      --decoy_generation_method genome_fasta_headers_only
    """

    stub:
    """
    mkdir -p salmon_index
    echo '{}' > salmon_index/info.json
    python3 ${projectDir}/scripts/write_reference_manifest.py \\
      --checksums ${reference_checksums} \\
      --out reference_manifest.json \\
      --pipeline_version ${params.pipeline_version} \\
      --gencode_release ${params.gencode_release} \\
      --genome_patch ${params.genome_patch} \\
      --salmon_version ${params.salmon_version} \\
      --salmon_k ${params.salmon_k} \\
      --salmon_index_options='${params.salmon_index_options}' \\
      --decoy_generation_method genome_fasta_headers_only
    """
}
