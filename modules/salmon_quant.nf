process SALMON_QUANT {
    tag "$sample"
    publishDir "${params.outdir}/salmon", mode: 'copy'
    conda "${projectDir}/envs/salmon.yml"

    cpus { params.salmon_cpus ?: 4 }
    memory { params.salmon_memory ?: '8 GB' }

    input:
    tuple val(sample), path(r1), path(r2)
    tuple path(index_dir), path(index_meta)

    output:
    tuple val(sample), path("${sample}"), emit: quant_dirs

    script:
    """
    salmon quant \\
        -i ${index_dir} \\
        -l ${params.lib_type} \\
        -1 ${r1} \\
        -2 ${r2} \\
        --gcBias \\
        --seqBias \\
        --numBootstraps 0 \\
        -p ${task.cpus} \\
        -o ${sample}
    """

    stub:
    """
    mkdir -p ${sample}/aux_info ${sample}/logs
    printf 'Name\\tLength\\tEffectiveLength\\tTPM\\tNumReads\\nENST000001.1\\t1000\\t900\\t1\\t10\\n' > ${sample}/quant.sf
    touch ${sample}/cmd_info.json ${sample}/lib_format_counts.json ${sample}/aux_info/meta_info.json
    """
}
