process BUILD_FULL_DECOY_REFERENCE {
    tag "GENCODE v${params.gencode_release} / GRCh38.p${params.genome_patch}"
    publishDir { cache_dir }, mode: 'copy', overwrite: true
    cpus { params.reference_cpus }
    memory { params.reference_memory }

    input:
    tuple path(tx_fasta), path(genome_fasta), path(gtf), val(cache_dir)

    output:
    tuple path('gentrome.fa'), path('decoys.txt'), path('annotation.gtf.gz'), val(cache_dir), emit: reference_files

    script:
    """
    gzip -cd ${tx_fasta} > transcripts.fa
    gzip -cd ${genome_fasta} > genome.fa
    seqkit seq --name --only-id transcripts.fa > transcript_ids.txt
    seqkit seq --name --only-id genome.fa > decoys.txt
    cat transcripts.fa genome.fa > gentrome.fa
    cat transcript_ids.txt decoys.txt > gentrome_ids.txt
    awk 'seen[\$1]++ { print "Duplicate FASTA identifier: " \$1 > "/dev/stderr"; bad=1 } END { exit bad }' gentrome_ids.txt
    awk 'NR==FNR { ids[\$1]=1; next } !(\$1 in ids) { print "Missing decoy in gentrome: " \$1 > "/dev/stderr"; bad=1 } END { exit bad }' gentrome_ids.txt decoys.txt
    cp ${gtf} annotation.gtf.gz
    """

    stub:
    """
    echo '>stub' > gentrome.fa
    echo 'stub' > decoys.txt
    echo 'stub' > annotation.gtf.gz
    """
}
