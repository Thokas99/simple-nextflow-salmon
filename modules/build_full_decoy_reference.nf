process BUILD_FULL_DECOY_REFERENCE {
    publishDir "${params.reference_dir}/../derived", mode: 'copy'
    conda "${projectDir}/envs/salmon.yml"

    cpus { params.reference_cpus ?: 4 }
    memory { params.reference_memory ?: '16 GB' }

    input:
    path multiqc_report
    tuple path(transcript_fasta), path(genome_fasta), path(gtf)

    output:
    tuple path("gentrome.fa"), path("decoys.txt"), emit: reference
    path "annotation.gtf.gz", emit: gtf
    path "reference_manifest.tsv", emit: manifest
    path "checksums.sha256", emit: checksums

    script:
    """
    set -euo pipefail

    pigz -dc ${transcript_fasta} > transcripts.fa
    pigz -dc ${genome_fasta} > genome.fa
    cp ${gtf} annotation.gtf.gz

    seqkit seq -n -i genome.fa > decoys.txt
    cat transcripts.fa genome.fa > gentrome.fa

    seqkit seq -n -i gentrome.fa | sort > gentrome.ids
    uniq -d gentrome.ids > duplicate_ids.txt
    if [[ -s duplicate_ids.txt ]]; then
        echo "Duplicate FASTA identifiers detected:" >&2
        head -50 duplicate_ids.txt >&2
        exit 1
    fi

    sort -u decoys.txt > decoys.sorted
    comm -23 decoys.sorted gentrome.ids > missing_decoys.txt
    if [[ -s missing_decoys.txt ]]; then
        echo "Decoy IDs missing from gentrome:" >&2
        head -50 missing_decoys.txt >&2
        exit 1
    fi

    {
        echo -e "field\\tvalue"
        echo -e "transcript_fasta\\t${transcript_fasta}"
        echo -e "genome_fasta\\t${genome_fasta}"
        echo -e "gtf\\t${gtf}"
        echo -e "decoy_source\\tgenome_fasta_headers_only"
        echo -e "gentrome_order\\ttranscripts_then_genome"
    } > reference_manifest.tsv

    sha256sum ${transcript_fasta} ${genome_fasta} ${gtf} gentrome.fa decoys.txt > checksums.sha256
    """

    stub:
    """
    touch gentrome.fa decoys.txt annotation.gtf.gz reference_manifest.tsv checksums.sha256
    """
}
