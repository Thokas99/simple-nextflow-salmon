# Outputs and downstream analysis

`quant.sf` is Salmon's transcript-level result. `NumReads` is a fractional estimated fragment count; `TPM` is within-sample abundance; `EffectiveLength` reflects fragment-length correction.

tximport aggregates versioned transcripts to versioned gene IDs with `countsFromAbundance = "no"`. The complete `salmon_gene_tximport.rds` is authoritative because it retains counts, abundance, effective lengths, and tximport metadata. TSV matrices are convenient views. `gene_annotation.tsv` separates gene symbols/types from the primary gene ID, while `tx2gene.tsv` stays exactly two columns.

For edgeR:

```r
txi <- readRDS("results/tximport/salmon_gene_tximport.rds")
y <- edgeR::DGEListFromTximport(txi)
y <- edgeR::calcNormFactors(y)
```

`sample_count_summary.tsv` is the canonical per-sample summary. `qc/salmon_metrics.tsv` copies native Salmon `aux_info/meta_info.json` fields and adds the number of normalized FASTQ pairs; it does not reinterpret Salmon counts or calculate custom mapping rates. MultiQC combines FastQC, native Salmon, and the two post-tximport RNA metrics.
