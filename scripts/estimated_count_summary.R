#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(data.table)
})

args <- commandArgs(trailingOnly = TRUE)

value_after <- function(flag) {
  idx <- match(flag, args)
  if (is.na(idx) || idx == length(args)) stop("Missing required argument: ", flag, call. = FALSE)
  args[[idx + 1]]
}

read_samplesheet <- function(path) {
  sep <- if (grepl("\\.tsv$", path, ignore.case = TRUE)) "\t" else ","
  fread(path, sep = sep, na.strings = character(), showProgress = FALSE)
}

gene_counts <- value_after("--gene_counts")
samplesheet <- value_after("--samplesheet")
outdir <- value_after("--outdir")

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
samples <- read_samplesheet(samplesheet)
expected <- unique(as.character(samples$sample))

counts <- fread(gene_counts, showProgress = FALSE)
if (!"gene_id" %in% names(counts)) stop("gene_counts.tsv is missing gene_id", call. = FALSE)
missing_cols <- setdiff(expected, names(counts))
if (length(missing_cols)) stop("gene_counts.tsv missing sample column(s): ", paste(missing_cols, collapse = ", "), call. = FALSE)

mat <- as.matrix(counts[, ..expected])
mode(mat) <- "numeric"
if (any(!is.finite(mat))) stop("Estimated-count matrix contains non-finite values", call. = FALSE)

summary <- data.table(
  metric = c(
    "genes",
    "samples",
    "total_estimated_fragments",
    "median_estimated_fragments_per_gene",
    "genes_with_estimated_count_gt_0",
    "genes_with_estimated_count_ge_10"
  ),
  value = c(
    nrow(counts),
    length(expected),
    sum(mat),
    if (length(mat)) median(rowSums(mat)) else 0,
    sum(rowSums(mat) > 0),
    sum(rowSums(mat) >= 10)
  )
)
fwrite(summary, file.path(outdir, "estimated_count_summary.tsv"), sep = "\t")

gene_summary <- data.table(
  sample = expected,
  total_estimated_fragments = colSums(mat),
  genes_with_estimated_count_gt_0 = colSums(mat > 0)
)
fwrite(gene_summary, file.path(outdir, "gene_count_summary.tsv"), sep = "\t")
