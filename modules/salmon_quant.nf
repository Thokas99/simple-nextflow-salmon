process SALMON_QUANT {
    tag "$sample"
    publishDir "${params.outdir}/salmon", mode: 'copy', overwrite: true

    cpus { params.salmon_cpus }
    memory { params.salmon_memory }

    input:
    tuple val(sample), path(r1), path(r2), val(lane_count)
    tuple path(index), path(reference_manifest)

    output:
    tuple val(sample), val(lane_count), path("${sample}"), emit: quant_dirs

    script:
    """
    salmon quant \\
      -i ${index} \\
      -l ${params.lib_type} \\
      -1 ${r1.join(' ')} \\
      -2 ${r2.join(' ')} \\
      -p ${task.cpus} \\
      -o ${sample}
    """

    stub:
    """
    mkdir -p ${sample}/aux_info
    cat > ${sample}/quant.sf <<'EOF'
Name	Length	EffectiveLength	TPM	NumReads
ENST000001.1	1000	900	5.0	10.5
ENST000002.1	800	700	0.0	0.0
EOF
    cat > ${sample}/aux_info/meta_info.json <<'EOF'
{"num_processed":1000,"num_mapped":800,"percent_mapped":80.0,"detected_library_type":"ISR","frag_length_mean":250.0,"frag_length_sd":40.0,"salmon_version":"2.3.4"}
EOF
    """
}
