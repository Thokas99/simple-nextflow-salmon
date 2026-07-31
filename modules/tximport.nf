process TXIMPORT {
    tag "${quant_dirs.size()} biological samples"
    publishDir "${params.outdir}/tximport", mode: 'copy', overwrite: true

    cpus { params.tximport_cpus }
    memory { params.tximport_memory }

    input:
    path quant_dirs
    path gtf
    path samplesheet

    output:
    path "salmon_gene_estimated_counts.tsv", emit: gene_estimated_counts
    path "salmon_gene_tpm.tsv", emit: gene_tpm
    path "salmon_gene_average_effective_length.tsv", emit: gene_average_effective_length
    path "tx2gene.tsv", emit: tx2gene
    path "gene_annotation.tsv", emit: gene_annotation
    path "tximport_summary.tsv", emit: summary
    path "salmon_gene_tximport.rds", emit: gene_tximport
    path "sample_metadata.tsv", emit: sample_metadata

    script:
    def quant_args = quant_dirs.collect { dir -> "'${dir.toString().replace("'", "'\\''")}'" }.join(' ')
    """
    Rscript "${projectDir}/scripts/tximport_gene_summary.R" \\
      --quant_dirs ${quant_args} \\
      --gtf "${gtf}" \\
      --samplesheet "${samplesheet}" \\
      --outdir .
    """

    stub:
    """
    samples=\$(python3 -c 'import csv,sys; print("\\t".join(dict.fromkeys(r["sample"] for r in csv.DictReader(open(sys.argv[1], newline="")))))' "${samplesheet}")
    values=\$(python3 -c 'import sys; print("\\t".join("10.5" for _ in sys.argv[1].split("\\t")))' "\$samples")
    printf 'gene_id\tgene_name\t%s\nENSG000001.1\tTEST1\t%s\n' "\$samples" "\$values" > salmon_gene_estimated_counts.tsv
    printf 'gene_id\tgene_name\t%s\nENSG000001.1\tTEST1\t%s\n' "\$samples" "\$values" > salmon_gene_tpm.tsv
    printf 'gene_id\tgene_name\t%s\nENSG000001.1\tTEST1\t%s\n' "\$samples" "\$values" > salmon_gene_average_effective_length.tsv
    cat > tx2gene.tsv <<'EOF'
transcript_id	gene_id
ENST000001.1	ENSG000001.1
EOF
    cat > gene_annotation.tsv <<'EOF'
gene_id	gene_name	gene_type
ENSG000001.1	TEST1	protein_coding
EOF
    cat > tximport_summary.tsv <<'EOF'
    metric	value
    countsFromAbundance	no
EOF
    touch salmon_gene_tximport.rds
    python3 -c 'import csv,sys; w=csv.writer(open("sample_metadata.tsv","w",newline=""),delimiter="\\t",lineterminator="\\n"); w.writerows((["sample","fastq_1","fastq_2"], *([r[x] for x in ("sample","fastq_1","fastq_2")] for r in csv.DictReader(open(sys.argv[1],newline="")))))' "${samplesheet}"
    """
}
