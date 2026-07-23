process SALMON_INDEX {
    publishDir "${params.reference_dir}/../derived", mode: 'copy'
    cpus { params.index_cpus ?: 8 }
    memory { params.index_memory ?: '32 GB' }

    input:
    tuple path(gentrome), path(decoys)

    output:
    tuple path("salmon_index"), path("salmon_index/info.json"), emit: index
    path "salmon_index.log", emit: log

    script:
    """
    salmon index \\
        -t ${gentrome} \\
        -d ${decoys} \\
        -i salmon_index \\
        -k ${params.salmon_k} \\
        -p ${task.cpus} \\
        --gencode \\
        > salmon_index.log 2>&1
    """

    stub:
    """
    mkdir -p salmon_index
    touch salmon_index/info.json salmon_index.log
    """
}
