# Outputs and downstream analysis

`quant.sf` is Salmon's transcript-level result. `NumReads` is a fractional estimated fragment count; `TPM` is within-sample abundance; `EffectiveLength` reflects fragment-length correction.

tximport aggregates versioned transcripts to versioned gene IDs with `countsFromAbundance = "no"`. The complete `salmon_gene_tximport.rds` is authoritative because it retains counts, abundance, effective lengths, and tximport metadata. TSV matrices are convenient views. `gene_annotation.tsv` separates gene symbols/types from the primary gene ID, while `tx2gene.tsv` stays exactly two columns.

For edgeR:

```r
txi <- readRDS("results/tximport/salmon_gene_tximport.rds")
y <- edgeR::DGEListFromTximport(txi)
y <- edgeR::calcNormFactors(y)
```

`sample_count_summary.tsv` is the canonical per-sample summary. The misleading legacy `gene_count_summary.tsv` is an identical deprecated copy in 0.3.0 and will be removed before 1.0.0.

`qc/input_fragment_counts.tsv` counts R1 records once per paired FASTQ and sums technical lanes per biological sample. `qc/salmon_metrics.tsv` interprets Salmon 2.3.4 `num_processed` as aligned fragments and `num_mapped` as quantified strand-compatible fragments, matching the Salmon 2 log stages. SnS derives alignment, quantification, and compatibility rates with explicit denominators; zero denominators yield zero rates. This interpretation is specific to Salmon 2.3.4 and does not reuse legacy mapping terminology.
