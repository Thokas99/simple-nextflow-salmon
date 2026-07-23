process SALMON_INDEX {
    tag "k=${params.salmon_k}"
    publishDir "${params.reference_dir}/../derived", mode: 'copy', overwrite: true
    cpus { params.index_cpus }
    memory { params.index_memory }

    input:
    tuple path(gentrome), path(decoys), path(gtf)

    output:
    tuple path('salmon_index'), path('reference_manifest.tsv'), emit: index
    path 'annotation.gtf.gz', emit: reference_gtf

    script:
    """
    salmon index -t ${gentrome} -d ${decoys} -i salmon_index \
      -k ${params.salmon_k} --gencode --threads ${task.cpus}
    salmon_version=\$(salmon --version | awk '{print \$NF}')
    printf 'field\tvalue\n' > reference_manifest.tsv
    printf 'gencode_release\t%s\n' '${params.gencode_release}' >> reference_manifest.tsv
    printf 'genome_patch\t%s\n' '${params.genome_patch}' >> reference_manifest.tsv
    printf 'transcript_fasta\tgencode.v${params.gencode_release}.transcripts.fa.gz\n' >> reference_manifest.tsv
    printf 'genome_fasta\tGRCh38.p${params.genome_patch}.genome.fa.gz\n' >> reference_manifest.tsv
    printf 'gtf\tgencode.v${params.gencode_release}.chr_patch_hapl_scaff.annotation.gtf.gz\n' >> reference_manifest.tsv
    printf 'salmon_version\t%s\n' "\$salmon_version" >> reference_manifest.tsv
    printf 'salmon_k\t%s\n' '${params.salmon_k}' >> reference_manifest.tsv
    printf 'index_options\t--gencode\n' >> reference_manifest.tsv
    """

    stub:
    """
    mkdir -p salmon_index
    echo '{}' > salmon_index/info.json
    printf 'field\tvalue\n' > reference_manifest.tsv
    printf 'gencode_release\t%s\n' '${params.gencode_release}' >> reference_manifest.tsv
    printf 'genome_patch\t%s\n' '${params.genome_patch}' >> reference_manifest.tsv
    printf 'transcript_fasta\tgencode.v${params.gencode_release}.transcripts.fa.gz\n' >> reference_manifest.tsv
    printf 'genome_fasta\tGRCh38.p${params.genome_patch}.genome.fa.gz\n' >> reference_manifest.tsv
    printf 'gtf\tgencode.v${params.gencode_release}.chr_patch_hapl_scaff.annotation.gtf.gz\n' >> reference_manifest.tsv
    printf 'salmon_version\t%s\n' '${params.salmon_version}' >> reference_manifest.tsv
    printf 'salmon_k\t%s\n' '${params.salmon_k}' >> reference_manifest.tsv
    printf 'index_options\t--gencode\n' >> reference_manifest.tsv
    touch annotation.gtf.gz
    """
}
